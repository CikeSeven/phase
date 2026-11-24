import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_spacing.dart';
import '../theme/app_radius.dart';
import 'app_card_dialog.dart';
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
    this.dialogTag,
  });

  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool? selected;
  final Color? color;
  final Object? dialogTag;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final fill =
        color ??
        (selected == true
            ? colors.primaryContainer
            : colors.surfaceContainerLow);
    final content = Padding(
      padding: const EdgeInsets.all(AppSpacing.l),
      child: Row(
        children: [
          if (selected != null) ...[
            ExcludeSemantics(
              child: Icon(
                selected! ? LucideIcons.circleCheck : LucideIcons.circle,
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
    );
    Widget surface(Widget child) => AppInteractiveSurface(
      selected: selected,
      onTap: onTap,
      color: fill,
      child: child,
    );
    final tag = dialogTag;
    return tag == null
        ? surface(content)
        : AppCardDialogHero(
            tag: tag,
            color: fill,
            radius: AppRadius.medium,
            surfaceBuilder: surface,
            child: content,
          );
  }
}
