import 'dart:ui';

import 'package:flutter/material.dart';

import 'app_radius.dart';

/// 带轻微背景模糊的半透明表面。
///
/// 只用于页面级面板、输入栏和抽屉等真正需要层次感的区域，避免把整页
/// 变成高对比度的玻璃效果，保证文字可读性和滚动性能。
class FrostedSurface extends StatelessWidget {
  const FrostedSurface({
    required this.child,
    super.key,
    this.borderRadius = AppRadius.largeAll,
    this.color,
    this.borderColor,
    this.blur = 18,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final Color? color;
  final Color? borderColor;
  final double blur;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final surfaceColor =
        color ?? colorScheme.surfaceContainerHigh.withValues(alpha: 0.76);
    final outlineColor =
        borderColor ?? colorScheme.outlineVariant.withValues(alpha: 0.34);

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: borderRadius,
            border: Border.all(color: outlineColor),
          ),
          child: child,
        ),
      ),
    );
  }
}
