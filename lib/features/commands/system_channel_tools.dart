import 'dart:io';
import 'dart:convert';

import 'package:path/path.dart' as p;

import '../../../core/error/failure.dart';
import '../../../data/models/command_channel.dart';
import '../../../data/models/tool_call_record.dart';
import '../../../data/models/tool_policy.dart';
import '../../../data/models/workspace.dart';
import '../../../data/repositories/workspace_repository.dart';
import '../tools/tool.dart';
import '../workspace/shell_tool.dart';
import '../workspace/workspace_files.dart';
import 'command_api.g.dart';
import 'command_channel_driver.dart';
import 'command_output_collector.dart';

const externalShellNames = {'shizuku_shell', 'termux_shell'};
const externalTransferNames = {'shizuku_transfer', 'termux_transfer'};
bool isCommandToolName(String name) =>
    name == 'shell' || externalShellNames.contains(name);

abstract class SystemChannelTool extends Tool {
  const SystemChannelTool(this.binding, this.driver);
  final CommandChannelSnapshot binding;
  final CommandChannelDriver driver;
  @override
  ExecutionChannel get channel => binding.channel;
  String get channelName =>
      channel == ExecutionChannel.shizuku ? 'Shizuku' : 'Termux';
  @override
  String get policyKey => commandExecutionPolicyKey;
  @override
  ToolPolicy get defaultPolicy => ToolPolicy.ask;
  @override
  Set<String> get requiredCapabilities => {'${channel.name}_command'};
  // The command service owns lifecycle; this must not prepare the accessibility host.
  @override
  bool usesPlatform(Map<String, dynamic> arguments) => false;
}

class ExternalShellTool extends SystemChannelTool {
  const ExternalShellTool(super.binding, super.driver);
  @override
  String get name => '${channel.name}_shell';
  @override
  String get description =>
      '以 $channelName 身份（UID ${binding.uid}）执行独立非交互命令，返回分离的 stdout/stderr 与真实退出结果。'
      '默认目录 ${binding.home}，不是 Ubuntu /workspace；cd 和变量不跨调用保留，不加载启动脚本，不设命令总时限。'
      '文件通过 ${channel.name}_transfer 显式传输。失败或停止不撤销已发生的效果，不要直接重发已派发动作。';
  @override
  Map<String, dynamic> get inputSchema => const {
    'type': 'object',
    'properties': {
      'command': {'type': 'string', 'description': '完整命令'},
      'cwd': {'type': 'string', 'description': '此通道内的绝对工作目录'},
    },
    'required': ['command'],
    'additionalProperties': false,
  };
  @override
  String describeAction(Map<String, dynamic> arguments) =>
      '$channelName · UID ${binding.uid}\n目录：${arguments['cwd'] ?? binding.home}\n${arguments['command']}';
  @override
  String? validateArguments(Map<String, dynamic> arguments) {
    final command = arguments['command'] as String? ?? '';
    final cwd = arguments['cwd'] as String? ?? binding.home;
    return command.contains('\u0000') ||
            utf8.encode(command).length > 120 * 1024 ||
            !cwd.startsWith('/') ||
            cwd.contains('\u0000')
        ? '命令或工作目录无效'
        : null;
  }

  @override
  Future<ToolOutcome> execute(
    Map<String, dynamic> arguments,
    ToolContext context,
    RunCancellation cancellation, {
    ToolProgress? onProgress,
  }) async {
    final output = CommandOutputCollector(context);
    CommandOperation? operation;
    ExternalCommandEvent? exit;
    String? error;
    try {
      cancellation.throwIfCancelled();
      operation = await driver.start(
        ExternalCommandSpec(
          ownerId: context.runId,
          callId: context.toolCallId,
          channel: channel.name,
          revision: binding.revision,
          uid: binding.uid,
          command: arguments['command'] as String,
          cwd: arguments['cwd'] as String? ?? binding.home,
          outputLimitBytes: ShellLimits.outputBytes,
        ),
        output.add,
      );
      exit = await operation.wait(cancellation);
      await output.finish();
    } on StorageFailure {
      rethrow;
    } on ToolCancelled {
      return const ToolOutcome.cancelled('命令启动前已停止');
    } on Failure catch (failure) {
      error = failure.userMessage;
    } finally {
      if (operation != null && exit == null) {
        await driver.cancel(context.runId, context.toolCallId);
      }
      try {
        await output.close();
      } on Failure catch (failure) {
        error ??= failure.userMessage;
      }
    }
    final cancelled = cancellation.isCancelled || exit?.cancelled == true;
    final successful =
        exit?.terminationAcknowledged == true &&
        exit?.exitCode == 0 &&
        exit?.signal == null &&
        exit?.error == null &&
        exit?.outputLimitExceeded != true &&
        error == null &&
        !cancelled;
    return ToolOutcome(
      ok: successful,
      cancelled: cancelled,
      artifacts: output.artifacts,
      errorCode: successful
          ? null
          : cancelled
          ? 'cancelled'
          : 'commandFailed',
      content: jsonEncode({
        'channel': channel.name,
        'uid': binding.uid,
        'cwd': arguments['cwd'] ?? binding.home,
        ...output.result,
        'exitCode': exit?.exitCode,
        'signal': exit?.signal,
        'cancelled': cancelled,
        'terminationAcknowledged': exit?.terminationAcknowledged ?? false,
        'outputLimitExceeded': exit?.outputLimitExceeded ?? false,
        'outputIncomplete': exit?.error == 'outputStopped',
        if (error != null || exit?.error != null)
          'error': error ?? commandErrorText(exit!.error!),
        'knownEffects': '已收输出保留；失败或停止不代表外部操作已撤销',
      }),
    );
  }
}

class ChannelTransferTool extends SystemChannelTool {
  const ChannelTransferTool(
    super.binding,
    super.driver,
    this.workspace,
    this.repository,
  );
  final WorkspaceSnapshot workspace;
  final WorkspaceRepository repository;
  @override
  String get name => '${channel.name}_transfer';
  @override
  String get description =>
      '在本会话工作区与 $channelName 之间显式传输文件或递归目录。'
      'path 是工作区相对路径，remotePath 是 $channelName 内的绝对路径；to_channel 导出，from_channel 导入。'
      '保留名称、隐藏文件与空目录；覆盖同名文件，不删除目标额外文件，不跟随符号链接。'
      '单文件最多 64 MiB，合计 256 MiB、1000 项。失败可能已经提交部分文件，结果如实返回。'
      '会话附件可用 attachment:<ID> 作为导出源，先复制到本会话工作区。';
  @override
  Map<String, dynamic> get inputSchema => const {
    'type': 'object',
    'properties': {
      'path': {
        'type': 'string',
        'description': '会话工作区相对路径；导出附件可用 attachment:<ID>',
      },
      'remotePath': {
        'type': 'string',
        'description': '此通道的完整绝对源/目标路径，文件名不自动追加',
      },
      'direction': {
        'type': 'string',
        'enum': ['to_channel', 'from_channel'],
      },
    },
    'required': ['path', 'remotePath', 'direction'],
    'additionalProperties': false,
  };
  @override
  String? validateArguments(Map<String, dynamic> arguments) {
    final local = arguments['path'] as String? ?? '';
    final remote = arguments['remotePath'] as String? ?? '';
    return local.isEmpty ||
            local.contains('\u0000') ||
            local.contains('\\') ||
            p.posix.isAbsolute(local) ||
            p.posix.split(local).contains('..') ||
            !remote.startsWith('/') ||
            remote.contains('\u0000') ||
            remote.split('/').contains('..') ||
            (local.startsWith('attachment:') &&
                arguments['direction'] != 'to_channel')
        ? '请指定有效的工作区路径与通道绝对路径'
        : null;
  }

  @override
  String describeAction(Map<String, dynamic> arguments) =>
      '$channelName · UID ${binding.uid}\n${arguments['direction'] == 'to_channel' ? '导出' : '导入'}：${arguments['path']} ↔ ${arguments['remotePath']}\n目录递归传输；同名文件覆盖，目标额外文件保留';
  @override
  Future<ToolOutcome> execute(
    Map<String, dynamic> arguments,
    ToolContext context,
    RunCancellation cancellation, {
    ToolProgress? onProgress,
  }) async {
    final toChannel = arguments['direction'] == 'to_channel';
    var local = arguments['path'] as String;
    final files = WorkspaceFiles(repository);
    CommandOperation? operation;
    ExternalCommandEvent? exit;
    final artifacts = <String>[];
    String? error;
    try {
      cancellation.throwIfCancelled();
      if (local.startsWith('attachment:')) {
        final attachment = context.attachmentBy(
          local.substring('attachment:'.length),
        );
        if (attachment == null) {
          return const ToolOutcome.failure(
            '此会话中没有对应附件',
            errorCode: 'fileMissing',
          );
        }
        final guest = await files.importAttachment(
          Workspace(
            id: workspace.id,
            name: workspace.name,
            rootPath: workspace.rootPath,
            createdAt: DateTime.now(),
          ),
          attachment,
          cancellation,
        );
        local = guest.substring('/workspace/'.length);
      }
      await workspacePath(workspace.rootPath, local, mustExist: toChannel);
      cancellation.throwIfCancelled();
      operation = await driver.transfer(
        ChannelTransferSpec(
          ownerId: context.runId,
          callId: context.toolCallId,
          channel: channel.name,
          revision: binding.revision,
          uid: binding.uid,
          localRoot: workspace.rootPath,
          path: local,
          remotePath: arguments['remotePath'] as String,
          toChannel: toChannel,
          fileLimitBytes: WorkspaceFiles.maxCopyBytes,
          totalLimitBytes: 256 * 1024 * 1024,
          entryLimit: 1000,
        ),
        (bytes) =>
            onProgress?.call('已传输 ${(bytes / 1048576).toStringAsFixed(1)} MiB'),
      );
      exit = await operation.wait(cancellation);
      // Actual imported files survive cancellation and are recorded as independent artifacts.
      if (!toChannel) {
        for (final relative in exit.completedPaths) {
          final path = relative.isEmpty ? local : p.posix.join(local, relative);
          final absolute = await workspacePath(workspace.rootPath, path);
          if (await FileSystemEntity.isDirectory(absolute)) continue;
          await repository.recordCopy(workspace.id, path, {
            'kind': 'commandChannel',
            'channel': channel.name,
            'remotePath': relative.isEmpty
                ? arguments['remotePath']
                : p.posix.join(arguments['remotePath'] as String, relative),
            'runId': context.runId,
            'toolCallId': context.toolCallId,
          });
          final artifact = await files.artifact(
            workspace,
            path,
            context,
            RunCancellation(),
          );
          artifacts.add(artifact.id);
        }
      }
    } on StorageFailure {
      rethrow;
    } on ToolCancelled {
      return const ToolOutcome.cancelled('文件传输启动前已停止');
    } on Failure catch (failure) {
      error = failure.userMessage;
    } on FileSystemException {
      error = '传输文件或产物保存失败，请检查路径与可用空间';
    } finally {
      if (operation != null && exit == null) {
        await driver.cancel(context.runId, context.toolCallId);
      }
    }
    final cancelled = cancellation.isCancelled || exit?.cancelled == true;
    final ok =
        exit?.terminationAcknowledged == true &&
        exit?.error == null &&
        error == null &&
        !cancelled;
    return ToolOutcome(
      ok: ok,
      cancelled: cancelled,
      artifacts: artifacts,
      errorCode: ok
          ? null
          : cancelled
          ? 'cancelled'
          : 'transferFailed',
      content: jsonEncode({
        'channel': channel.name,
        'direction': arguments['direction'],
        'path': local,
        'remotePath': arguments['remotePath'],
        'transferredBytes': exit?.transferredBytes ?? 0,
        'completedPaths': exit?.completedPaths ?? [],
        'artifactIds': artifacts,
        'cancelled': cancelled,
        'terminationAcknowledged': exit?.terminationAcknowledged ?? false,
        if (error != null || exit?.error != null)
          'error': error ?? commandErrorText(exit!.error!),
        'knownEffects': '已提交的文件保留；停止或失败不代表整批回滚，未删除目标额外文件',
      }),
    );
  }
}
