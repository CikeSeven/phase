import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/app_spacing.dart';
import 'app_selection_surface.dart';

/// 可换行的紧凑选择面；保留勾选槽位，改选时不移动相邻选项。
class AppChoiceChip extends StatelessWidget {
  const AppChoiceChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    super.key,
    this.icon,
    this.tooltip,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool>? onSelected;
  final IconData? icon;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final foreground = onSelected == null
        ? colors.onSurface.withValues(alpha: 0.38)
        : selected
        ? colors.onPrimaryContainer
        : colors.onSurfaceVariant;
    final chip = AppSelectionSurface(
      selected: selected,
      color: selected ? colors.primaryContainer : colors.surfaceContainerHigh,
      onTap: onSelected == null ? null : () => onSelected!(!selected),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.m,
          vertical: AppSpacing.s,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: 20,
              child: selected || icon != null
                  ? ExcludeSemantics(
                      child: Icon(
                        selected ? Symbols.check_circle : icon,
                        fill: selected ? 1 : 0,
                        size: 20,
                        color: foreground,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: AppSpacing.s),
            Flexible(
              child: Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(color: foreground),
              ),
            ),
          ],
        ),
      ),
    );
    return tooltip == null ? chip : Tooltip(message: tooltip!, child: chip);
  }
}
