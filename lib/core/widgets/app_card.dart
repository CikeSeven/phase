import 'package:flutter/material.dart';

import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/frosted_surface.dart';

/// 不创建模糊层的内容卡片；tint 仅为表面加入少量语义衬色。
class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(AppSpacing.l),
    this.tint,
    this.borderRadius = AppRadius.largeAll,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? tint;
  final BorderRadius borderRadius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final base = dark
        ? colors.surfaceContainerLow
        : colors.surfaceContainerLowest;
    final surface = tint == null
        ? base
        : Color.alphaBlend(tint!.withValues(alpha: dark ? 0.09 : 0.045), base);
    final content = Padding(padding: padding, child: child);

    return FrostedSurface(
      blur: 0,
      borderRadius: borderRadius,
      color: surface.withValues(alpha: dark ? 0.88 : 0.80),
      child: onTap == null
          ? content
          : InkWell(
              onTap: onTap,
              borderRadius: borderRadius,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                child: content,
              ),
            ),
    );
  }
}
