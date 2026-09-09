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
    this.padding = EdgeInsets.zero,
  }) : assert(blur >= 0);

  final Widget child;
  final BorderRadius borderRadius;
  final Color? color;
  final Color? borderColor;
  final double blur;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final media = MediaQuery.maybeOf(context);
    final reducedEffects =
        media?.disableAnimations == true || media?.accessibleNavigation == true;
    final tint =
        color ??
        (dark ? colors.surfaceContainerLow : colors.surfaceContainerLowest)
            .withValues(alpha: dark ? 0.88 : 0.80);
    final surface = Material(
      color: reducedEffects ? Color.alphaBlend(tint, colors.surface) : tint,
      surfaceTintColor: colors.surfaceTint.withValues(alpha: 0),
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius,
        side: BorderSide(
          color:
              borderColor ??
              colors.outlineVariant.withValues(alpha: dark ? 0.58 : 0.48),
        ),
      ),
      child: Padding(padding: padding, child: child),
    );

    return ClipRRect(
      borderRadius: borderRadius,
      child: blur == 0 || reducedEffects
          ? surface
          : BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
              child: surface,
            ),
    );
  }
}
