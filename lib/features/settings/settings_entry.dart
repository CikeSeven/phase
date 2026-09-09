import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../core/widgets/app_icon_badge.dart';

/// 设置分区中的单个入口或只读信息，不继承全局 ListTile 背景。
class SettingsEntry extends StatelessWidget {
  const SettingsEntry({
    required this.icon,
    required this.title,
    super.key,
    this.subtitle,
    this.tone = AppTone.primary,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final AppTone tone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: AppRadius.mediumAll,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.m,
            vertical: AppSpacing.m,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ExcludeSemantics(
                child: Icon(icon, size: 24, color: tone.foreground(context)),
              ),
              const SizedBox(width: AppSpacing.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium),
                    if (subtitle != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: AppSpacing.s),
                ExcludeSemantics(
                  child: Icon(
                    Symbols.chevron_right,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

extension on AppTone {
  Color foreground(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final brand = context.brandColors;
    return switch (this) {
      AppTone.primary => colors.primary,
      AppTone.teal => brand.teal,
      AppTone.lavender => brand.lavender,
      AppTone.gold => brand.gold,
    };
  }
}
