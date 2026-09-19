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
  static const timeoutMs = 60000;
  static const maxTimeoutMs = 300000;
  static const previewBytes = 64 * 1024;
  static const outputBytes = 8 * 1024 * 1024;
}

class ShellTool extends Tool {
  const ShellTool({this.workspace, this.driver, this.files});
  final WorkspaceSnapshot? workspace;
  final ProcessDriver? driver;
  final WorkspaceFiles? files;
  @override
  String get name => 'shell';
  @override
  String get description =>
      '在本会话独立的 Ubuntu 工作区执行一次非交互 shell 命令。每次进程独立，文件保留；结果返回 stdout/stderr、退出码与产物。需返回的文件写入 /workspace/output。';
  @override
  Map<String, dynamic> get inputSchema => const {
    'type': 'object',
    'properties': {
      'command': {'type': 'string', 'description': '完整 shell 命令'},
      'cwd': {'type': 'string', 'description': 'guest 工作目录，默认 /workspace'},
      'timeoutMs': {
        'type': 'integer',
        'minimum': 1,
        'maximum': ShellLimits.maxTimeoutMs,
      },
    },
    'required': ['command'],
    'additionalProperties': false,
  };
  @override
  Set<String> get requiredCapabilities => const {'linux_process'};
  @override
  ToolPolicy get defaultPolicy => ToolPolicy.ask;
  @override
  String describeAction(Map<String, dynamic> arguments) =>
      'Ubuntu ${workspace?.environmentRevision ?? "24.04 ARM64"} · ${workspace?.name ?? "会话工作区"}\n目录：${arguments['cwd'] ?? '/workspace'}\n超时：${arguments['timeoutMs'] ?? ShellLimits.timeoutMs} ms\n${arguments['command']}';
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

  @override
  Future<ToolOutcome> execute(
    Map<String, dynamic> arguments,
    ToolContext context,
    RunCancellation cancellation, {
    ToolProgress? onProgress,
  }) async {
    final binding = workspace;
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
    final handles = <RandomAccessFile>[];
    final artifacts = <String>[];
    LinuxProcessEvent? exit;
    LinuxProcess? process;
    final imported = <String>[];
    String? fileError;
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
      final before = await files!.outputs(binding);
      await outputFiles.first.parent.create(recursive: true);
      for (final file in outputFiles) {
        handles.add(await file.open(mode: FileMode.write));
      }
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
          timeoutMs: arguments['timeoutMs'] as int? ?? ShellLimits.timeoutMs,
          outputLimitBytes: ShellLimits.outputBytes,
        ),
        (stderr, bytes) async {
          final index = stderr ? 1 : 0;
          sizes[index] += bytes.length;
          final remaining = ShellLimits.previewBytes - previews[index].length;
          if (remaining > 0) {
            previews[index].add(
              bytes.sublist(0, bytes.length.clamp(0, remaining)),
            );
          }
          try {
            await handles[index].writeFrom(bytes);
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
      for (final handle in handles) {
        await handle.close();
      }
      handles.clear();
      // Output/known file effects survive a stop. This does not rerun the command.
      for (var i = 0; i < 2; i++) {
        if (sizes[i] == 0) continue;
        final attachment = await context.storage.registerArtifact(
          conversationId: context.conversationId,
          path: outputFiles[i].path,
          name: p.basename(outputFiles[i].path),
        );
        artifacts.add(attachment.id);
      }
      final after = await files!.outputs(binding);
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
        await handle.close();
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
