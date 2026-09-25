import '../commands/command_channel_driver.dart';
import '../commands/system_channel_tools.dart';
import '../../../data/models/tool_call_record.dart';

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../../../core/error/failure.dart';
import '../../../data/models/tool_policy.dart';
import '../../../data/models/workspace.dart';
import '../tools/tool.dart';
import 'process_api.g.dart';
import 'process_driver.dart';
import 'workspace_files.dart';

abstract final class ShellLimits {
  static const previewBytes = 64 * 1024;
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
      workspace?.primaryEnvironment == PrimaryEnvironment.termux
      ? '在 Termux 会话工作区执行独立非交互 Bash 命令。默认目录 ${workspace!.executionRoot}；变量与 cd 不跨调用保留。依赖由用户管理，不自动安装。返回 stdout/stderr、退出结果与产物。'
      : '在 Ubuntu 工作区执行非交互 shell 命令，返回 stdout/stderr、退出码与产物。'
            '每次调用的环境变量与 cd 不保留。环境为最小安装：安装软件用 '
            'apt update && apt install -y，已安装内容跨会话持久保留；apt 被中断后'
            '先运行 dpkg --configure -a 恢复再重试。命令不设超时。';
  @override
  Map<String, dynamic> get inputSchema => const {
    'type': 'object',
    'properties': {
      'command': {'type': 'string', 'description': '完整 shell 命令'},
      'cwd': {'type': 'string', 'description': '所选环境中的绝对工作目录，默认当前会话工作区'},
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
      '${workspace?.primaryEnvironment.label ?? 'Ubuntu'} · ${workspace?.name ?? "会话工作区"}\n目录：${arguments['cwd'] ?? workspace?.executionRoot ?? '/workspace'}\n${arguments['command']}';
  @override
  String? validateArguments(Map<String, dynamic> arguments) {
    final command = arguments['command'] as String? ?? '';
    final cwd = arguments['cwd'] as String? ?? '/workspace';
    return command.contains('\u0000') ||
            utf8.encode(command).length > 120 * 1024 ||
            !cwd.startsWith('/') ||
            cwd.contains('\u0000')
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
    final previews = [BytesBuilder(copy: false), BytesBuilder(copy: false)];
    final sizes = [0, 0];
    final outputFiles = [
      for (final stream in ['stdout', 'stderr'])
        File(
          p.join(
            context.artifactsDirectory,
            '${context.toolCallId}-$stream.txt',
          ),
        ),
    ];
    final handles = List<RandomAccessFile?>.filled(2, null);
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
          workspace: binding.rootPath,
          executable: '/bin/sh',
          argv: ['-c', arguments['command'] as String],
          cwd: arguments['cwd'] as String? ?? '/workspace',
          environment: {},
          outputLimitBytes: ShellLimits.outputBytes,
        ),
        (stderr, bytes) async {
          final index = stderr ? 1 : 0;
          final previousPreviewLength = previews[index].length;
          final previewRemaining =
              ShellLimits.previewBytes - previousPreviewLength;
          sizes[index] += bytes.length;
          if (previewRemaining > 0) {
            previews[index].add(
              bytes.sublist(0, bytes.length.clamp(0, previewRemaining)),
            );
          }
          try {
            // 普通输出只保留在结果里；超过预览上限才保存完整日志。
            if (sizes[index] > ShellLimits.previewBytes) {
              var handle = handles[index];
              if (handle == null) {
                await outputFiles[index].parent.create(recursive: true);
                handle = await outputFiles[index].open(mode: FileMode.write);
                handles[index] = handle;
                await handle.writeFrom(previews[index].toBytes());
                final overflowStart = previewRemaining.clamp(0, bytes.length);
                if (overflowStart < bytes.length) {
                  await handle.writeFrom(bytes.sublist(overflowStart));
                }
              } else {
                await handle.writeFrom(bytes);
              }
            }
          } on FileSystemException {
            fileError = '命令输出文件保存失败';
            rethrow;
          }
        },
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
      for (var i = 0; i < handles.length; i++) {
        await handles[i]?.close();
        handles[i] = null;
      }
      // Output/known file effects survive a stop. This does not rerun the command.
      for (var i = 0; i < 2; i++) {
        if (sizes[i] <= ShellLimits.previewBytes) continue;
        final attachment = await context.storage.registerArtifact(
          conversationId: context.conversationId,
          path: outputFiles[i].path,
          name: p.basename(outputFiles[i].path),
        );
        artifacts.add(attachment.id);
      }
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
      for (final handle in handles) {
        await handle?.close();
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
      'cwd': arguments['cwd'] ?? '/workspace',
      'exitCode': exit?.exitCode,
      'signal': exit?.signal,
      'cancelled': stopped,
      'timedOut': exit?.timedOut ?? false,
      'outputLimitExceeded': exit?.outputLimitExceeded ?? false,
      'stdout': utf8.decode(previews[0].takeBytes(), allowMalformed: true),
      'stderr': utf8.decode(previews[1].takeBytes(), allowMalformed: true),
      'stdoutBytes': sizes[0],
      'stderrBytes': sizes[1],
      'previewTruncated': sizes.any((s) => s > ShellLimits.previewBytes),
      'artifactIds': artifacts,
      'importedFiles': imported,
      'warning': ?artifactWarning,
      if (fileError != null || exit?.error != null)
        'error': fileError ?? '命令进程未返回完整结果',
      'knownEffects': '已收集输出；工作区中的文件变化保留，失败或停止不代表撤销',
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
