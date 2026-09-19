import 'package:flutter/material.dart';

import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/brand_colors.dart';

/// 主操作、连接能力、次级信息、品牌点缀和危险操作的语义色调。
enum AppTone { primary, teal, lavender, gold, error }

/// 带成对前景与底色的装饰图标，触控行为由外层有标签的控件承担。
class AppIconBadge extends StatelessWidget {
  const AppIconBadge({
    required this.icon,
    super.key,
    this.tone = AppTone.primary,
    this.size = 48,
    this.iconSize = 24,
  }) : assert(size > 0),
       assert(iconSize > 0);

  final IconData icon;
  final AppTone tone;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final colors = _colorsFor(context, tone);
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: colors.container,
          borderRadius: AppRadius.smallAll,
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: iconSize, color: colors.onContainer),
      ),
    );
  }
}

/// 可放入 Wrap 的短文字标签，不以颜色单独表达状态。
class AppBadge extends StatelessWidget {
  const AppBadge({required this.label, super.key, this.tone = AppTone.primary});

  final String label;
  final AppTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = _colorsFor(context, tone);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.container,
        borderRadius: AppRadius.smallAll,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s,
          vertical: AppSpacing.xs,
        ),
        child: Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelMedium
              ?.copyWith(color: colors.onContainer),
        ),
      ),
    );
  }
}

({Color container, Color onContainer}) _colorsFor(
  BuildContext context,
  AppTone tone,
) {
  final colors = Theme.of(context).colorScheme;
  final brand = context.brandColors;
  return switch (tone) {
    AppTone.primary => (
      container: colors.primaryContainer,
      onContainer: colors.onPrimaryContainer,
    ),
    AppTone.teal => (
      container: brand.tealContainer,
      onContainer: brand.onTealContainer,
    ),
    AppTone.lavender => (
      container: brand.lavenderContainer,
      onContainer: brand.onLavenderContainer,
    ),
    AppTone.gold => (
      container: brand.goldContainer,
      onContainer: brand.onGoldContainer,
    ),
    AppTone.error => (
      container: colors.errorContainer,
      onContainer: colors.onErrorContainer,
    ),
  };
}
