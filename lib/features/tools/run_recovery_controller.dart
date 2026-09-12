import 'dart:async';
import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:path/path.dart' as p;
import 'package:mime/mime.dart';

import '../../../core/error/failure.dart';
import '../../../data/repositories/agent_run_repository.dart';
import '../../../data/datasources/local/attachment_storage.dart';
import '../../../data/models/attachment.dart';
import '../../../data/models/tool_call_record.dart';

part 'run_recovery_controller.g.dart';

/// 启动核对只执行一次；读取失败保持错误状态，不能伪装成没有中断任务。
@Riverpod(keepAlive: true)
class RunRecoveryController extends _$RunRecoveryController {
  Future<void>? _initialization;
  String? _activeRunId;
  Timer? _expiry;
  int _revision = 0;

  @override
  FutureOr<List<RecoveredRun>> build() {
    ref.onDispose(() => _expiry?.cancel());
    return const [];
  }

  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    try {
      state = const AsyncLoading();
      final repository = await ref.read(agentRunRepositoryProvider.future);
      final entries = await repository.recover(afterRestart: true);
      if (!ref.mounted) return;
      state = AsyncData(entries);
      _scheduleExpiry(entries);
    } catch (error, stack) {
      if (ref.mounted) state = AsyncError(error, stack);
      _initialization = null;
      rethrow;
    }
  }

  void runStarted(String id) {
    _activeRunId = id;
    _revision++;
    state = AsyncData([
      for (final entry in state.value ?? <RecoveredRun>[])
        if (entry.run.id != id) entry,
    ]);
  }

  Future<void> runFinished() async {
    _activeRunId = null;
    await refresh();
  }

  Future<void> refresh() async {
    await initialize();
    final revision = ++_revision;
    try {
      final repository = await ref.read(agentRunRepositoryProvider.future);
      final entries = await repository.recover(activeRunId: _activeRunId);
      if (!ref.mounted || revision != _revision) return;
      state = AsyncData(entries);
      _scheduleExpiry(entries);
    } catch (error, stack) {
      if (ref.mounted && revision == _revision) {
        state = AsyncError(error, stack);
      }
      rethrow;
    }
  }

  Future<void> stop(String runId) async {
    if (runId == _activeRunId) throw const OperationFailure('请使用运行中的停止入口');
    final repository = await ref.read(agentRunRepositoryProvider.future);
    await repository.stopRecovered(runId);
    await refresh();
  }

  Future<void> verify(
    String callId, {
    required bool succeeded,
    required String result,
  }) async {
    final repository = await ref.read(agentRunRepositoryProvider.future);
    await repository.verifyResult(callId, succeeded: succeeded, result: result);
    await refresh();
  }

  /// 只读核验本会话的写入目标；不登记成功、不重放写入。
  Future<Attachment> inspectWrite(String callId) async {
    final entries = state.value ?? const <RecoveredRun>[];
    final entry = entries
        .where((entry) => entry.calls.any((c) => c.id == callId))
        .firstOrNull;
    final call = entry?.calls.where((c) => c.id == callId).firstOrNull;
    if (entry == null ||
        call?.toolName != 'write_file' ||
        call?.status != ToolCallStatus.unknown) {
      throw const OperationFailure('此动作没有可核验的写入目标');
    }
    final path = call!.arguments['path'];
    if (path is! String || p.isAbsolute(path)) {
      throw const OperationFailure('写入目标无效');
    }
    try {
      final storage = await ref.read(attachmentStorageProvider.future);
      final directory = p.normalize(
        p.join(storage.root.path, 'artifacts', entry.run.conversationId),
      );
      final target = p.normalize(p.join(directory, path));
      if (!p.isWithin(directory, target)) {
        throw const OperationFailure('写入目标超出会话范围');
      }
      final file = File(target);
      if (!await file.exists()) {
        throw const OperationFailure('目标文件不存在，请如实记录核验结果');
      }
      return Attachment(
        id: 'verification-$callId',
        conversationId: entry.run.conversationId,
        kind: AttachmentKind.artifact,
        name: p.basename(target),
        localPath: target,
        mimeType: lookupMimeType(target) ?? 'application/octet-stream',
        size: await file.length(),
        createdAt: call.createdAt,
      );
    } on FileSystemException {
      throw const OperationFailure('读取写入目标失败，请重试');
    }
  }

  void _scheduleExpiry(List<RecoveredRun> entries) {
    _expiry?.cancel();
    final dates = [
      for (final entry in entries)
        for (final call in entry.calls)
          if (call.confirmationExpiresAt != null &&
              call.status == ToolCallStatus.awaitingConfirmation)
            call.confirmationExpiresAt!,
    ]..sort();
    if (dates.isEmpty) return;
    final remaining = dates.first.difference(DateTime.now());
    _expiry = Timer(remaining.isNegative ? Duration.zero : remaining, () {
      // refresh 自身保留 AsyncError，页面会显示重试入口。
      unawaited(refresh().catchError((Object _) {}));
    });
  }
}
