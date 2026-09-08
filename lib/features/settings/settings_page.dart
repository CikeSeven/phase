import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../core/theme/app_spacing.dart';
import 'theme_mode_controller.dart';

/// 设置页（DESIGN.md §5.4 的 M3 设置范式）。
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          const _SectionHeader('外观'),
          ListTile(
            leading: const Icon(Symbols.dark_mode),
            title: const Text('主题模式'),
            subtitle: Text(_themeModeLabel(themeMode)),
            trailing: const Icon(Symbols.chevron_right),
            onTap: () => _pickThemeMode(context, ref, themeMode),
          ),
          const _SectionHeader('服务商'),
          ListTile(
            leading: const Icon(Symbols.cloud),
            title: const Text('服务商配置'),
            subtitle: const Text('管理 Base URL、API Key 与模型'),
            trailing: const Icon(Symbols.chevron_right),
            onTap: () => context.push('/settings/providers'),
          ),
          const _SectionHeader('关于'),
          const ListTile(
            leading: Icon(Symbols.info),
            title: Text('相月'),
            // TODO(release): 接 package_info 后替换为真实版本号。
            subtitle: Text('版本 0.1.0'),
          ),
        ],
      ),
    );
  }

  static String _themeModeLabel(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.system => '跟随系统',
      ThemeMode.light => '浅色',
      ThemeMode.dark => '深色',
    };
  }

  Future<void> _pickThemeMode(
    BuildContext context,
    WidgetRef ref,
    ThemeMode current,
  ) async {
    final selected = await showDialog<ThemeMode>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('主题模式'),
        children: [
          for (final mode in ThemeMode.values)
            ListTile(
              title: Text(_themeModeLabel(mode)),
              trailing: mode == current ? const Icon(Symbols.check) : null,
              onTap: () => Navigator.of(context).pop(mode),
            ),
        ],
      ),
    );
    if (selected != null) {
      await ref.read(themeModeControllerProvider.notifier).setThemeMode(selected);
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.l,
        AppSpacing.xl,
        AppSpacing.l,
        AppSpacing.s,
      ),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
