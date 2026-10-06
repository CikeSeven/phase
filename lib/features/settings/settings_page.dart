import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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
            icon: LucideIcons.cloud,
            tone: AppTone.primary,
            title: '服务商配置',
            subtitle: '模型接入与连接密钥',
            onTap: () => context.push('/settings/providers'),
          ),
          const SizedBox(height: AppSpacing.s),
          SettingsEntry(
            icon: LucideIcons.search,
            tone: AppTone.teal,
            title: '网页搜索',
            subtitle: '联网检索与搜索引擎',
            onTap: () => context.push('/settings/web-search'),
          ),
          const SizedBox(height: AppSpacing.s),
          SettingsEntry(
            icon: LucideIcons.pointer,
            tone: AppTone.gold,
            title: '执行与权限',
            subtitle: '工具规则、后台通知与设备权限',
            onTap: () => context.push('/settings/execution'),
          ),
          const SizedBox(height: AppSpacing.s),
          SettingsEntry(
            icon: LucideIcons.folderOpen,
            tone: AppTone.primary,
            title: '环境设置',
            subtitle: '沙盒环境与依赖管理',
            onTap: () => context.push('/settings/workspaces'),
          ),
          const SizedBox(height: AppSpacing.s),
          SettingsEntry(
            icon: LucideIcons.terminal,
            tone: AppTone.teal,
            title: '任务管理',
            subtitle: '后台命令与运行记录',
            onTap: () => context.push('/background-tasks'),
          ),
          const SizedBox(height: AppSpacing.s),
          SettingsEntry(
            icon: LucideIcons.puzzle,
            tone: AppTone.lavender,
            title: '扩展',
            subtitle: 'MCP 工具与技能扩展',
            onTap: () => context.push('/settings/extensions'),
          ),
          const SizedBox(height: AppSpacing.s),
          SettingsEntry(
            icon: LucideIcons.bookmark,
            tone: AppTone.gold,
            title: '长期记忆',
            subtitle: '偏好与跨会话记忆',
            onTap: () => context.push('/settings/memories'),
          ),
          const SizedBox(height: AppSpacing.xl),
          const _BrandFooter(),
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
    final colors = theme.colorScheme;
    return AppInteractiveSurface(
      color: brand.lavenderContainer.withValues(alpha: 0.48),
      radius: AppRadius.large,
      onTap: () => showDialog<void>(
        context: context,
        builder: (context) => ThemeModeDialog(initialMode: mode),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const AppIconBadge(
                  icon: LucideIcons.palette,
                  tone: AppTone.lavender,
                ),
                const SizedBox(width: AppSpacing.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('主题模式', style: theme.textTheme.titleMedium),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        themeModeLabel(mode),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.s),
                ExcludeSemantics(
                  child: Icon(
                    LucideIcons.chevronRight,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.m),
            ExcludeSemantics(child: ThemePreview(mode: mode)),
          ],
        ),
      ),
    );
  }
}

class _BrandFooter extends StatelessWidget {
  const _BrandFooter();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final brand = context.brandColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: brand.goldContainer.withValues(alpha: 0.36),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(LucideIcons.moon, size: 22, color: brand.gold),
          ),
          const SizedBox(height: AppSpacing.s),
          Text('相月', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '开发预览版',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '版本 1.0.0+1',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
