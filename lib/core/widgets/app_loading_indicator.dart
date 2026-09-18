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
