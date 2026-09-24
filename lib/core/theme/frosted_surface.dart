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
  }) : assert(blur >= 0);

  final Widget child;
  final BorderRadius borderRadius;
  final Color? color;
  final Color? borderColor;
  final double blur;

  /// 渐变底色、边缘、模糊强度与内容，不把背景采样放入整体透明度层。
  final Animation<double>? revealAnimation;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final animation = revealAnimation;
    if (animation == null) return _buildSurface(context, 1, child);
    return AnimatedBuilder(
      animation: animation,
      child: FadeTransition(
        opacity: animation,
        alwaysIncludeSemantics: true,
        child: child,
      ),
      builder: (context, child) =>
          _buildSurface(context, animation.value, child!),
    );
  }

  Widget _buildSurface(BuildContext context, double progress, Widget child) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    // 辅助服务读取控件也会开启无障碍导航，不等于用户要求减少动态效果。
    final reducedEffects =
        MediaQuery.maybeOf(context)?.disableAnimations == true;
    final tint =
        color ??
        (dark ? colors.surfaceContainerLow : colors.surfaceContainerLowest)
            .withValues(alpha: dark ? 0.88 : 0.80);
    final fill = reducedEffects ? Color.alphaBlend(tint, colors.surface) : tint;
    final border =
        borderColor ??
        colors.outlineVariant.withValues(alpha: dark ? 0.58 : 0.48);
    final surface = Material(
      color: fill.withValues(alpha: fill.a * progress),
      surfaceTintColor: colors.surfaceTint.withValues(alpha: 0),
      // 显式进度已经驱动边缘，避免 Material 再叠一层隐式动画产生拖尾。
      animationDuration: revealAnimation == null
          ? kThemeChangeDuration
          : Duration.zero,
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius,
        side: BorderSide(color: border.withValues(alpha: border.a * progress)),
      ),
      child: Padding(padding: padding, child: child),
    );

    return ClipRRect(
      borderRadius: borderRadius,
      child: blur == 0 || reducedEffects
          ? surface
          : BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: blur * progress,
                sigmaY: blur * progress,
              ),
              child: surface,
            ),
    );
  }
}
