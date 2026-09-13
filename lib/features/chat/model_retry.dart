import 'dart:async';

import '../../../core/error/provider_error.dart';
import '../tools/tool.dart';

/// 当前模型轮的有限重试，不重放此前的工具动作。
class ModelRetryPolicy {
  const ModelRetryPolicy({
    this.maxRetries = 2,
    this.baseDelay = const Duration(seconds: 2),
    this.maxDelay = const Duration(seconds: 60),
  });

  final int maxRetries;
  final Duration baseDelay;
  final Duration maxDelay;

  /// retry 从 1 开始；过长的服务端等待不截短后提前发送。
  Duration? delayFor(ProviderError error, int retry) {
    if (!error.retryable || retry < 1 || retry > maxRetries) return null;
    final serverDelay = error.retryAfter;
    if (serverDelay != null && serverDelay > maxDelay) return null;
    var delay = baseDelay;
    for (var index = 1; index < retry && delay < maxDelay; index++) {
      delay *= 2;
    }
    if (delay > maxDelay) delay = maxDelay;
    if (serverDelay != null && serverDelay > delay) delay = serverDelay;
    return delay;
  }
}

class ModelRetryState {
  const ModelRetryState({
    required this.attempt,
    required this.maxRetries,
    required this.delay,
  });

  final int attempt;
  final int maxRetries;
  final Duration delay;
}

/// 停止时销毁退避定时器，不等到下一次请求才检查取消。
Future<void> waitForModelRetry(
  Duration delay,
  RunCancellation cancellation,
) async {
  if (cancellation.isCancelled) return;
  final done = Completer<void>();
  final timer = Timer(delay, done.complete);
  try {
    await Future.any([done.future, cancellation.whenCancelled]);
  } finally {
    timer.cancel();
  }
}
