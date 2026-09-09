import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/brand_colors.dart';

/// 用真实主题色渲染的轻量聊天预览，不额外绘制边框。
class ThemePreview extends StatelessWidget {
  const ThemePreview({required this.mode, super.key});

  final ThemeMode mode;

  @override
  Widget build(BuildContext context) {
    final preview = ClipRRect(
      borderRadius: AppRadius.smallAll,
      child: switch (mode) {
        ThemeMode.system => Row(
          children: [
            Expanded(
              child: Theme(
                data: AppTheme.light(),
                child: const _ThemeMiniature(),
              ),
            ),
            Expanded(
              child: Theme(
                data: AppTheme.dark(),
                child: const _ThemeMiniature(),
              ),
            ),
          ],
        ),
        ThemeMode.light => Theme(
          data: AppTheme.light(),
          child: const _ThemeMiniature(),
        ),
        ThemeMode.dark => Theme(
          data: AppTheme.dark(),
          child: const _ThemeMiniature(),
        ),
      },
    );
    return SizedBox(height: 72, child: preview);
  }
}

class _ThemeMiniature extends StatelessWidget {
  const _ThemeMiniature();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.surface,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Symbols.nightlight,
                  size: 12,
                  color: context.brandColors.gold,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(child: _line(colors.onSurfaceVariant, AppSpacing.xs)),
              ],
            ),
            const SizedBox(height: AppSpacing.s),
            Align(
              alignment: Alignment.centerRight,
              child: FractionallySizedBox(
                widthFactor: 0.56,
                child: _line(colors.primaryContainer, AppSpacing.m),
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: 0.8,
                child: _line(colors.surfaceContainerHighest, AppSpacing.s),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _line(Color color, double height) => Container(
    height: height,
    decoration: BoxDecoration(color: color, borderRadius: AppRadius.smallAll),
  );
}
