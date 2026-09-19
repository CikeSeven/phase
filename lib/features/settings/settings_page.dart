import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../core/widgets/app_icon_badge.dart';
import '../../../core/widgets/app_interactive_surface.dart';
import '../../../core/widgets/app_scaffold.dart';
import 'settings_entry.dart';
import 'theme_mode_controller.dart';
import 'theme_mode_dialog.dart';
import 'theme_preview.dart';

/// 相月的外观偏好、服务商入口与版本信息。
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final themeMode = ref.watch(themeModeControllerProvider);
    return AppScaffold(
      title: '设置',
      showAppBarDivider: false,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.xl,
          AppSpacing.xl,
          AppSpacing.l,
        ),
        children: [
          _AppearanceSurface(mode: themeMode),
          const SizedBox(height: AppSpacing.xl),
          SettingsEntry(
            icon: Symbols.cloud,
            tone: AppTone.teal,
            title: '服务商配置',
            onTap: () => context.push('/settings/providers'),
          ),
          const SizedBox(height: AppSpacing.s),
          SettingsEntry(
            icon: Symbols.touch_app,
            tone: AppTone.teal,
            title: '执行与权限',
            onTap: () => context.push('/settings/execution'),
          ),
          const SizedBox(height: AppSpacing.s),
          SettingsEntry(
            icon: Symbols.folder_open,
            tone: AppTone.teal,
            title: '环境设置',
            onTap: () => context.push('/settings/workspaces'),
          ),
          const SizedBox(height: AppSpacing.s),
          SettingsEntry(
            icon: Symbols.extension,
            tone: AppTone.teal,
            title: '扩展',
            onTap: () => context.push('/settings/extensions'),
          ),
          const SizedBox(height: AppSpacing.l),
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xl),
            child: Column(
              children: [
                Icon(
                  Symbols.nightlight,
                  size: 24,
                  color: context.brandColors.gold,
                ),
                const SizedBox(height: AppSpacing.s),
                Text('相月', style: theme.textTheme.titleLarge),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '开发预览版',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '版本 1.0.0+1',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AppearanceSurface extends StatelessWidget {
  const _AppearanceSurface({required this.mode});

  final ThemeMode mode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brand = context.brandColors;
    return AppInteractiveSurface(
      color: brand.lavenderContainer.withValues(alpha: 0.48),
      radius: AppRadius.extraLarge,
      onTap: () => showDialog<void>(
        context: context,
        builder: (context) => ThemeModeDialog(initialMode: mode),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: Icon(Symbols.palette, size: 24, color: brand.lavender),
                ),
                const SizedBox(width: AppSpacing.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('主题模式', style: theme.textTheme.titleMedium),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        themeModeLabel(mode),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.s),
                ExcludeSemantics(
                  child: Icon(
                    Symbols.chevron_right,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.l),
            ExcludeSemantics(child: ThemePreview(mode: mode)),
          ],
        ),
      ),
    );
  }
}
