import 'dart:async';

import '../../../core/error/failure.dart';
import '../../../core/utils/logger.dart';
import '../tools/tool.dart';

/// 一次发送、恢复或手动整理的生命周期；完整收尾后才解除操作互斥。
final class ChatOperation {
  final _settled = Completer<void>();
  RunCancellation? _cancellation;
  String? _runId;
  bool _runFinished = false;
  Failure? _cleanupFailure;

  String? get runId => _runId;
  RunCancellation? get cancellation => _cancellation;
  bool get runFinished => _runFinished;
  Future<void> get whenSettled => _settled.future;

  void bindRun(String runId) {
    if (_runId != null && _runId != runId) {
      throw StateError('Chat operation already owns another run');
    }
    _runId = runId;
  }

  RunCancellation beginCancellation() => _cancellation ??= RunCancellation();

  void markRunFinished() => _runFinished = true;

  void cancel() => _cancellation?.cancel();

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
