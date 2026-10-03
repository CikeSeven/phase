import '../commands/command_channel_driver.dart';
import '../commands/system_channel_tools.dart';
import '../commands/command_output_collector.dart';
import '../../../data/models/tool_call_record.dart';

import 'dart:convert';
import 'dart:io';

import '../../../core/error/failure.dart';
import '../../../data/models/tool_policy.dart';
import '../../../data/models/workspace.dart';
import '../tools/tool.dart';
import '../tools/tool_output_limits.dart';
import 'process_api.g.dart';
import 'process_driver.dart';
import 'workspace_files.dart';

abstract final class ShellLimits {
  static const previewBytes = ToolOutputLimits.maxBytes;
  static const outputBytes = 8 * 1024 * 1024;
}

class ShellTool extends Tool {
  const ShellTool({
    this.workspace,
    this.driver,
    this.files,
    this.commandDriver,
  });
  final CommandChannelDriver? commandDriver;
  @override
  ExecutionChannel get channel =>
      workspace?.primaryEnvironment == PrimaryEnvironment.termux
      ? ExecutionChannel.termux
      : ExecutionChannel.app;
  @override
  bool usesPlatform(Map<String, dynamic> arguments) => false;
  final WorkspaceSnapshot? workspace;
  final ProcessDriver? driver;
  final WorkspaceFiles? files;
  @override
  String get name => 'shell';
  @override
  String get policyKey => commandExecutionPolicyKey;
  @override
  String get description =>
      '在 ${workspace?.primaryEnvironment.label ?? 'Ubuntu'} 中执行 shell 命令，返回 stdout、stderr、退出码和产物。'
      '支持当前环境中的绝对文件路径和绝对 cwd；默认目录：${workspace?.executionRoot ?? '当前会话目录'}。'
      '输出预览保留最后 2000 行或 50 KiB，以先达到的上限为准；截断时已收完整输出保存为附件。'
      'timeout 可指定秒级超时，默认没有命令总时限。';
  @override
  String get promptSnippet => '在当前环境执行 shell 命令';
  @override
  List<String> get promptGuidelines => const [
    '文件查看、搜索、定位和局部修改优先使用 read_file、grep、find、list_files、edit_file；shell 用于执行程序或组合操作。',
    'shell 支持当前环境绝对路径，cwd 仅影响本次命令；默认无超时，需要时设置 timeout（秒）。',
    '命令预览保留尾部，完整输出附件使用 read_file 的 attachment:<ID> 按页读取。',
    '模型结果带 sourceId 的进一步裁剪可用 read_history 续读原始记录，不重跑有副作用命令来取日志。',
  ];
  @override
  Map<String, dynamic> get inputSchema => const {
    'type': 'object',
    'properties': {
      'command': {'type': 'string', 'description': '完整 shell 命令'},
      'cwd': {'type': 'string', 'description': '所选环境中的绝对工作目录，默认当前会话工作区'},
      'timeout': {
        'type': 'number',
        'exclusiveMinimum': 0,
        'description': '超时秒数，可选；默认不设总时限',
      },
    },
    'required': ['command'],
    'additionalProperties': false,
  };
  @override
  Set<String> get requiredCapabilities => {
    workspace?.primaryEnvironment == PrimaryEnvironment.termux
        ? 'termux_command'
        : 'linux_process',
  };
  @override
  ToolPolicy get defaultPolicy => ToolPolicy.ask;
  @override
  String describeAction(Map<String, dynamic> arguments) =>
      '${workspace?.primaryEnvironment.label ?? 'Ubuntu'} · ${workspace?.name ?? "会话工作区"}\n目录：${arguments['cwd'] ?? workspace?.executionRoot ?? '所属会话目录'}\n${arguments['command']}';
  @override
  String? validateArguments(Map<String, dynamic> arguments) {
    final timeout = arguments['timeout'];
    if (timeout != null &&
        (timeout is! num ||
            !timeout.isFinite ||
            timeout <= 0 ||
            timeout * 1000 > 2147483647)) {
      return 'timeout 必须是有限的正数秒，最多 2147483.647 秒';
    }
    final command = arguments['command'] as String? ?? '';
    final cwd = arguments['cwd'] as String?;
    return command.contains('\u0000') ||
            utf8.encode(command).length > 120 * 1024 ||
            (cwd != null &&
                (!cwd.startsWith('/') ||
                    cwd.contains('\u0000') ||
                    utf8.encode(cwd).length > 4096))
        ? '命令或 guest 工作目录无效'
        : null;
  }

  Future<ToolOutcome> _termux(
    Map<String, dynamic> arguments,
    ToolContext context,
    RunCancellation cancellation,
    WorkspaceSnapshot binding,
  ) async {
    if (binding.termux == null || commandDriver == null || files == null) {
      return const ToolOutcome.failure(
        'Termux 未授权或尚未就绪',
        errorCode: 'environmentMissing',
      );
    }
    final access = files!.repository.files(binding, ownerId: context.runId);
    final artifacts = <String>[];
    Map<String, String>? before;
    String? warning;
    Future<Map<String, String>?> outputs() async {
      try {
        return await files!.outputs(
          binding,
          ownerId: context.runId,
          cancellation: cancellation,
        );
      } on WorkspaceFailure catch (error) {
        warning = error.userMessage;
        return null;
      }
    }

    try {
      await access.ensure(cancellation);
      for (final attachment in context.attachments.where(
        (a) => a.kind.name != 'artifact',
      )) {
        await files!.importAttachment(
          Workspace(
            id: binding.id,
            name: binding.name,
            rootPath: binding.rootPath,
            createdAt: DateTime.now(),
          ),
          attachment,
          cancellation,
          binding: binding,
          ownerId: context.runId,
        );
      }
      before = await outputs();
      cancellation.throwIfCancelled();
      final outcome = await ExternalShellTool(binding.termux!, commandDriver!)
          .execute(
            {...arguments, 'cwd': arguments['cwd'] ?? binding.executionRoot},
            context,
            cancellation,
          );
      artifacts.addAll(outcome.artifacts);
      if (before != null && !cancellation.isCancelled && !outcome.cancelled) {
        try {
          final after = await outputs();
          if (after != null) {
            for (final entry in after.entries) {
              if (before[entry.key] == entry.value) continue;
              try {
                artifacts.add(
                  (await files!.artifact(
                    binding,
                    entry.key,
                    context,
                    cancellation,
                  )).id,
                );
              } on WorkspaceFailure catch (error) {
                warning = error.userMessage;
              }
            }
          }
        } on ToolCancelled {
          warning = '产物收集已停止，远端文件保留';
        }
      }
      Map<String, dynamic> result;
      try {
        result = (jsonDecode(outcome.content) as Map).cast<String, dynamic>();
      } on FormatException {
        result = {'message': outcome.content};
      }
      return ToolOutcome(
        ok: outcome.ok && !cancellation.isCancelled,
        cancelled: outcome.cancelled || cancellation.isCancelled,
        errorCode: outcome.errorCode,
        artifacts: artifacts,
        content: jsonEncode({
          ...result,
          'environment': 'termux',
          'workspace': binding.name,
          'artifactIds': artifacts,
          'artifactWarning': ?warning,
        }),
      );
    } on StorageFailure {
      rethrow;
    } on ToolCancelled {
      return const ToolOutcome.cancelled('命令准备已停止，已复制的文件保留');
    } on Failure catch (error) {
      return ToolOutcome.failure(
        error.userMessage,
        errorCode: 'workspaceFailed',
      );
    } on FileSystemException {
      return const ToolOutcome.failure(
        '命令文件处理失败，请检查可用空间',
        errorCode: 'fileOperationFailed',
      );
    }
  }

  @override
  Future<ToolOutcome> execute(
    Map<String, dynamic> arguments,
    ToolContext context,
    RunCancellation cancellation, {
    ToolProgress? onProgress,
  }) async {
    final binding = workspace;
    if (binding?.primaryEnvironment == PrimaryEnvironment.termux) {
      return _termux(arguments, context, cancellation, binding!);
    }
    if (binding == null ||
        !binding.linuxAvailable ||
        driver == null ||
        files == null) {
      return const ToolOutcome.failure(
        '请先在设置中安装 Ubuntu 环境',
        errorCode: 'environmentMissing',
      );
    }
    final output = CommandOutputCollector(context);
    final artifacts = <String>[];
    LinuxProcessEvent? exit;
    LinuxProcess? process;
    final imported = <String>[];
    String? fileError;
    String? artifactWarning;
    Future<Map<String, String>?> collectOutputs() async {
      try {
        return await files!.outputs(binding);
      } on WorkspaceFailure catch (error) {
        if (error.code != 'artifactLimit') rethrow;
        artifactWarning = error.userMessage;
        return null;
      }
    }

    try {
      cancellation.throwIfCancelled();
      for (final attachment in context.attachments.where(
        (a) => a.kind.name != 'artifact',
      )) {
        imported.add(
          await files!.importAttachment(
            Workspace(
              id: binding.id,
              name: binding.name,
              rootPath: binding.rootPath,
              createdAt: DateTime.now(),
            ),
            attachment,
            cancellation,
          ),
        );
      }
      // 工作区文件过多只影响自动附加产物，不能阻止命令继续处理这些文件。
      final before = await collectOutputs();
      cancellation.throwIfCancelled();
      process = await driver!.start(
        LinuxProcessSpec(
          ownerId: context.runId,
          processId: context.toolCallId,
          rootfs: binding.environmentRoot!,
          executable: '/bin/sh',
          argv: ['-c', arguments['command'] as String],
          cwd: arguments['cwd'] as String? ?? binding.executionRoot,
          environment: {},
          timeoutMs: arguments['timeout'] == null
              ? null
              : ((arguments['timeout'] as num) * 1000).ceil(),
          outputLimitBytes: ShellLimits.outputBytes,
        ),
        output.add,
      );
      try {
        await process.closeInput();
      } catch (_) {
        if (cancellation.isCancelled) {
          await process.cancel();
        } else {
          rethrow;
        }
      }
      exit = await waitForProcess(process, cancellation);
      await output.finish();
      artifacts.addAll(output.artifacts);
      if (before != null) {
        final after = await collectOutputs();
        if (after != null) {
          for (final entry in after.entries) {
            if (before[entry.key] == entry.value) continue;
            final attachment = await files!.artifact(
              binding,
              entry.key,
              context,
              RunCancellation(),
            );
            artifacts.add(attachment.id);
          }
        }
      }
    } on StorageFailure {
      rethrow;
    } on ToolCancelled {
      return const ToolOutcome.cancelled('命令启动前已停止');
    } on Failure catch (error) {
      fileError = error.userMessage;
    } on FileSystemException {
      fileError = '命令输出或产物文件保存失败，请检查可用空间';
    } finally {
      if (process != null && exit == null) {
        try {
          await process.cancel();
        } on Failure {
          fileError ??= '命令停止未收到完整回执，已有输出保留';
        }
      }
      try {
        await output.close();
      } on CommandChannelFailure catch (error) {
        fileError ??= error.userMessage;
      }
    }
    final stopped = exit?.cancelled == true || cancellation.isCancelled;
    final ok =
        exit?.exitCode == 0 &&
        exit?.signal == null &&
        exit?.error == null &&
        fileError == null &&
        !stopped &&
        exit?.timedOut != true &&
        exit?.outputLimitExceeded != true;
    final result = jsonEncode({
      'environment': binding.environmentRevision,
      'workspace': binding.name,
      'cwd': arguments['cwd'] ?? binding.executionRoot,
      'exitCode': exit?.exitCode,
      'signal': exit?.signal,
      'cancelled': stopped,
      'timedOut': exit?.timedOut ?? false,
      'outputLimitExceeded': exit?.outputLimitExceeded ?? false,
      ...output.result,
      'artifactIds': artifacts,
      'importedFiles': imported,
      'warning': ?artifactWarning,
      if (fileError != null || exit?.error != null)
        'error': fileError ?? '命令进程未返回完整结果',
      'knownEffects': '已收集当前会话产物；会话及 Ubuntu 全局文件的变化保留，失败或停止不代表撤销',
    });
    return ToolOutcome(
      ok: ok,
      content: result,
      artifacts: artifacts,
      cancelled: stopped,
      errorCode: ok
          ? null
          : stopped
          ? 'cancelled'
          : exit?.timedOut == true
          ? 'timeout'
          : exit?.outputLimitExceeded == true
          ? 'outputLimit'
          : 'commandFailed',
    );
  }
}
