import 'dart:async';

import 'package:flutter/material.dart';

import 'model_retry.dart';

/// 重试等待倒计时与请求中的状态共用同一条提示。
class ModelRetryStatus extends StatefulWidget {
  const ModelRetryStatus({required this.retry, super.key});

  final ModelRetryState retry;

  @override
  State<ModelRetryStatus> createState() => _ModelRetryStatusState();
}

class _ModelRetryStatusState extends State<ModelRetryStatus> {
  Timer? _timer;
  late DateTime _retryAt;
  int _seconds = 0;

  @override
  void initState() {
    super.initState();
    _syncRetry();
  }

  @override
  void didUpdateWidget(covariant ModelRetryStatus oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.retry, widget.retry)) _syncRetry();
  }

  int _remainingSeconds() {
    final milliseconds = _retryAt.difference(DateTime.now()).inMilliseconds;
    return milliseconds <= 0 ? 0 : (milliseconds + 999) ~/ 1000;
  }

  void _syncRetry() {
    _timer?.cancel();
    _timer = null;
    final retry = widget.retry;
    _retryAt = retry.retryAt ?? DateTime.now().add(retry.delay);
    _seconds = _remainingSeconds();
    if (retry.phase != ModelRetryPhase.waiting || _seconds == 0) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      final seconds = _remainingSeconds();
      if (_seconds != seconds) setState(() => _seconds = seconds);
      if (seconds == 0) {
        timer.cancel();
        _timer = null;
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final retry = widget.retry;
    final count = '${retry.attempt}/${retry.maxRetries}';
    final requesting = retry.phase == ModelRetryPhase.requesting;
    final text = requesting
        ? '正在重试 $count'
        : _seconds == 0
        ? '即将重试 $count'
        : '自动重试 $count · $_seconds 秒后重试';
    return Semantics(
      liveRegion: true,
      label: requesting
          ? '正在重试 $count'
          : '自动重试 $count，等待 ${retry.delay.inSeconds} 秒',
      child: ExcludeSemantics(
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}
