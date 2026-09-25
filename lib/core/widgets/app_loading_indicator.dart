import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_loading_indicator/loading_indicator.dart';

import '../theme/app_motion.dart';

/// 未知进度使用 Expressive 形变指示；减少动画或离屏时保留静态形状。
class AppLoadingIndicator extends StatelessWidget {
  const AppLoadingIndicator({
    super.key,
    this.size = 48,
    this.color,
    this.semanticsLabel = '正在加载',
  }) : _inheritColor = false;

  const AppLoadingIndicator.small({
    super.key,
    this.size = 24,
    this.color,
    this.semanticsLabel = '正在加载',
  }) : _inheritColor = true;

  final double size;
  final Color? color;
  final String semanticsLabel;
  final bool _inheritColor;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: RepaintBoundary(
      child: TickerMode(
        enabled: !AppMotion.reduce(context),
        child: LoadingIndicator(
          activeIndicatorColor:
              color ??
              (_inheritColor
                  ? IconTheme.of(context).color
                  : Theme.of(context).colorScheme.primary),
          semanticsLabel: semanticsLabel,
        ),
      ),
    ),
  );
}

/// 固定反馈槽位；短操作不闪现图形，慢操作仍显示真实加载状态。
class AppDelayedLoadingIndicator extends StatefulWidget {
  const AppDelayedLoadingIndicator({
    required this.loading,
    required this.semanticsLabel,
    super.key,
    this.placeholder,
  });

  final bool loading;
  final String semanticsLabel;
  final Widget? placeholder;

  @override
  State<AppDelayedLoadingIndicator> createState() =>
      _AppDelayedLoadingIndicatorState();
}

class _AppDelayedLoadingIndicatorState
    extends State<AppDelayedLoadingIndicator> {
  Timer? _delay;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _update();
  }

  @override
  void didUpdateWidget(AppDelayedLoadingIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.loading != widget.loading) _update();
  }

  void _update() {
    _delay?.cancel();
    _visible = false;
    if (widget.loading) {
      _delay = Timer(const Duration(milliseconds: 200), () {
        if (mounted) setState(() => _visible = true);
      });
    }
  }

  @override
  void dispose() {
    _delay?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 24,
    child: _visible
        ? AppLoadingIndicator.small(semanticsLabel: widget.semanticsLabel)
        : widget.placeholder,
  );
}
