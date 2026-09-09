import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_icon_badge.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_section.dart';
import 'settings_entry.dart';
import 'theme_mode_controller.dart';
import 'theme_mode_dialog.dart';

/// 相月的外观偏好、服务商入口与版本信息。
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final themeMode = ref.watch(themeModeControllerProvider);
    return AppScaffold(
      title: '设置',
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.l),
        children: [
          AppCard(
            child: Row(
              children: [
                const AppIconBadge(
                  icon: Symbols.nightlight,
                  tone: AppTone.gold,
                ),
                const SizedBox(width: AppSpacing.l),
                Expanded(child: Text('相月', style: theme.textTheme.titleLarge)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppSection(
            title: '外观',
            child: SettingsEntry(
              icon: Symbols.palette,
              tone: AppTone.lavender,
              title: '主题模式',
              subtitle: themeModeLabel(themeMode),
              onTap: () => showDialog<void>(
                context: context,
                builder: (context) => ThemeModeDialog(initialMode: themeMode),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppSection(
            title: '服务商',
            child: SettingsEntry(
              icon: Symbols.cloud,
              tone: AppTone.teal,
              title: '服务商配置',
              onTap: () => context.push('/settings/providers'),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          const AppSection(
            title: '关于',
            child: SettingsEntry(
              icon: Symbols.info,
              title: '开发预览版',
              subtitle: '版本 1.0.0+1',
            ),
          ),
          const SizedBox(height: AppSpacing.l),
        ],
      ),
    );
  }
}
