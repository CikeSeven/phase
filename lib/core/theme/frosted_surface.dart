import 'dart:ui';

import 'package:flutter/material.dart';

import 'app_radius.dart';

/// 单一 Material 表面的局部玻璃层；静态卡片应使用 blur: 0。
class FrostedSurface extends StatelessWidget {
  const FrostedSurface({
    required this.child,
    super.key,
    this.borderRadius = AppRadius.largeAll,
    this.color,
    this.borderColor,
    this.blur = 12,
    this.revealAnimation,
    this.padding = EdgeInsets.zero,
  }) : assert(blur >= 0),
       assert(revealAnimation == null || blur == 0);

  final Widget child;
  final BorderRadius borderRadius;
  final Color? color;
  final Color? borderColor;
  final double blur;

  /// 无背景采样的表面可直接整体淡入。
  final Animation<double>? revealAnimation;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    // 辅助服务读取控件也会开启无障碍导航，不等于用户要求减少动态效果。
    final reducedEffects = MediaQuery.disableAnimationsOf(context);
    final tint =
        color ??
        (dark ? colors.surfaceContainerLow : colors.surfaceContainerLowest)
            .withValues(alpha: dark ? 0.88 : 0.80);
    final fill = reducedEffects ? Color.alphaBlend(tint, colors.surface) : tint;
    final border =
        borderColor ??
        colors.outlineVariant.withValues(alpha: dark ? 0.58 : 0.48);
    final surface = Material(
      color: fill,
      surfaceTintColor: colors.surfaceTint.withValues(alpha: 0),
      animationDuration: reducedEffects ? Duration.zero : kThemeChangeDuration,
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius,
        side: BorderSide(color: border),
      ),
      child: Padding(padding: padding, child: child),
    );

    final clipped = ClipRRect(
      borderRadius: borderRadius,
      child: blur == 0 || reducedEffects
          ? surface
          : BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
              child: surface,
            ),
    );
    final animation = revealAnimation;
    return animation == null || reducedEffects
        ? clipped
        : FadeTransition(
            opacity: animation,
            alwaysIncludeSemantics: true,
            child: RepaintBoundary(child: clipped),
          );
  }
}
