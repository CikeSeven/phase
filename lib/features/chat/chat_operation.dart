import 'dart:async';

import '../../../core/error/failure.dart';
import '../../../core/utils/logger.dart';
import '../tools/tool.dart';

/// 一次发送、恢复或手动整理的生命周期；完整收尾后才解除操作互斥。
final class ChatOperation {
  final _settled = Completer<void>();
  RunCancellation? _cancellation;
  String? _runId;
  String? _conversationId;
  bool _runFinished = false;
  bool _cancelRequested = false;
  bool? _wasCancelledBeforeClose;
  Failure? _cleanupFailure;

  String? get runId => _runId;
  String? get conversationId => _conversationId;
  RunCancellation? get cancellation => _cancellation;
  bool get runFinished => _runFinished;
  bool get isCancelled =>
      _cancelRequested || _cancellation?.isCancelled == true;
  bool get wasCancelled => _wasCancelledBeforeClose ?? isCancelled;
  Future<void> get whenSettled => _settled.future;

  void bindRun(String runId) {
    if (_runId != null && _runId != runId) {
      throw StateError('Chat operation already owns another run');
    }
    _runId = runId;
  }

  void bindConversation(String conversationId) {
    if (_conversationId != null && _conversationId != conversationId) {
      throw StateError('Chat operation already owns another conversation');
    }
    _conversationId = conversationId;
  }

  RunCancellation beginCancellation() {
    final cancellation = _cancellation ??= RunCancellation();
    if (_cancelRequested) cancellation.cancel();
    return cancellation;
  }

  void markRunFinished() => _runFinished = true;

  void cancel() {
    _cancelRequested = true;
    _cancellation?.cancel();
  }

  // Cleanup closes the token too; preserve whether cancellation preceded it.
  void closeCancellation() {
    _wasCancelledBeforeClose ??= isCancelled;
    _cancellation?.cancel();
  }

  /// 清理彼此独立；保留失败供宿主展示，不让首个异常跳过后续资源。
  Future<void> cleanup(
    FutureOr<void> Function() action, {
    required String failureMessage,
  }) async {
    try {
      await action();
    } on Failure catch (error) {
      if (_cleanupFailure == null || error is StorageFailure) {
        _cleanupFailure = error;
      }
      AppLogger.warning(failureMessage);
    } catch (error, stackTrace) {
      _cleanupFailure ??= const OperationFailure('任务已结束，但部分资源未能完整清理，请稍后重试');
      AppLogger.error('$failureMessage：${error.runtimeType}', null, stackTrace);
    }
  }

  void throwIfCleanupFailed() {
    if (_cleanupFailure case final error?) throw error;
  }

  void settle() {
    cancel();
    if (!_settled.isCompleted) _settled.complete();
  }
}
