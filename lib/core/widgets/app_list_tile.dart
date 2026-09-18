import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/app_spacing.dart';
import 'app_interactive_surface.dart';

/// 操作与多选列表共用的色面行；长标题、说明和大字自然增高。
class AppListTile extends StatelessWidget {
  const AppListTile({
    required this.title,
    required this.onTap,
    super.key,
    this.subtitle,
    this.leading,
    this.trailing,
    this.selected,
    this.color,
  });

  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool? selected;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return AppInteractiveSurface(
      selected: selected,
      onTap: onTap,
      color:
          color ??
          (selected == true
              ? colors.primaryContainer
              : colors.surfaceContainerLow),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Row(
          children: [
            if (selected != null) ...[
              ExcludeSemantics(
                child: Icon(
                  selected! ? Symbols.check_circle : Symbols.circle,
                  fill: selected! ? 1 : 0,
                  color: selected!
                      ? colors.onPrimaryContainer
                      : colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: AppSpacing.m),
            ],
            if (leading != null) ...[
              ExcludeSemantics(child: leading!),
              const SizedBox(width: AppSpacing.m),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  DefaultTextStyle.merge(
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: selected == true
                          ? colors.onPrimaryContainer
                          : colors.onSurface,
                    ),
                    child: title,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    DefaultTextStyle.merge(
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: selected == true
                            ? colors.onPrimaryContainer
                            : colors.onSurfaceVariant,
                      ),
                      child: subtitle!,
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: AppSpacing.m),
              ExcludeSemantics(child: trailing!),
            ],
          ],
        ),
      ),
    );
  }
}
