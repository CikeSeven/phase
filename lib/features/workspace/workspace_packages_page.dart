import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_icon_badge.dart';
import '../../../core/widgets/app_linear_progress_indicator.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../data/models/workspace.dart';
import 'dependency_controller.dart';
import 'dependency_profiles.dart';
import 'installation_progress.dart';
import 'workspace_controller.dart';

/// Ubuntu 依赖与扩展软件包管理页面。
class WorkspacePackagesPage extends ConsumerStatefulWidget {
  const WorkspacePackagesPage({super.key});

  @override
  ConsumerState<WorkspacePackagesPage> createState() =>
      _WorkspacePackagesPageState();
}

class _WorkspacePackagesPageState extends ConsumerState<WorkspacePackagesPage> {
  @override
  Widget build(BuildContext context) {
    final environment = ref.watch(runtimeEnvironmentProvider);
    final dependencies = ref.watch(dependencyControllerProvider);
    final platform = ref.watch(linuxPlatformInfoProvider);

    return AppScaffold(
      title: '软件包管理',
      showAppBarDivider: !dependencies.busy,
      appBarBottom: dependencies.busy
          ? const PreferredSize(
              preferredSize: Size.fromHeight(18),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: AppLinearProgressIndicator(semanticsLabel: '正在安装依赖'),
              ),
            )
          : null,
      body: environment.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => const AppEmptyState(
          icon: LucideIcons.circleAlert,
          title: '无法读取环境状态',
          message: '读取环境配置失败，请返回重试。',
        ),
        data: (env) {
          if (!env.ready) {
            return const AppEmptyState(
              icon: LucideIcons.box,
              title: 'Ubuntu 环境未就绪',
              message: '请先在环境设置中安装并初始化 Ubuntu 运行环境。',
            );
          }

          final records = env.installedDependencies;
          final baseInstalled = DependencyProfile.base.every(
            (p) => records.containsKey(p.id),
          );

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.l),
            children: [
              const _SectionHeader(title: '核心环境'),
              const SizedBox(height: AppSpacing.s),
              _BaseEnvironmentCard(
                records: records,
                baseInstalled: baseInstalled,
                dependencies: dependencies,
                onRepair: platform.value?.available == true
                    ? _repairBaseEnvironment
                    : null,
              ),
              const SizedBox(height: AppSpacing.xl),
              const _SectionHeader(title: '可选扩展包'),
              const SizedBox(height: AppSpacing.s),
              for (final bundle in DependencyBundle.optionalBundles) ...[
                _BundleCard(
                  bundle: bundle,
                  records: records,
                  dependencies: dependencies,
                  onInstall: platform.value?.available == true
                      ? () => _confirmInstall(bundle)
                      : null,
                ),
                const SizedBox(height: AppSpacing.m),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _repairBaseEnvironment() async {
    if (ref.read(dependencyControllerProvider).busy) return;
    await ref
        .read(dependencyControllerProvider.notifier)
        .installSelected(profiles: DependencyProfile.base, title: '基础环境');
  }

  Future<void> _confirmInstall(DependencyBundle bundle) async {
    final operation = ref.read(dependencyControllerProvider);
    if (operation.busy) return;

    final records =
        ref.read(runtimeEnvironmentProvider).value?.installedDependencies ??
        const {};
    final installed = bundle.isInstalled(records);
    final partial = bundle.isPartiallyInstalled(records);
    final actionLabel = installed
        ? '重新安装'
        : partial
        ? '继续安装'
        : '安装';

    final allowed = await showDialog<bool>(
      context: context,
      builder: (context) => AppDialog(
        title: '$actionLabel${bundle.label}？',
        icon: bundle.icon,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('将安装以下 Ubuntu 命令行软件包：'),
            for (final profile in bundle.profiles) ...[
              const SizedBox(height: AppSpacing.m),
              Text(
                '${profile.label}\n${profile.packages.join('、')}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: AppSpacing.l),
            const Text(
              '此可选包不安装桌面环境。需要联网和额外存储空间；安装内容保留在 Ubuntu 中，卸载 Ubuntu 时一并删除。',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(actionLabel),
          ),
        ],
      ),
    );

    if (allowed == true && mounted) {
      await ref
          .read(dependencyControllerProvider.notifier)
          .installSelected(profiles: bundle.profiles, title: bundle.label);
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      title,
      style: theme.textTheme.titleSmall?.copyWith(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _BaseEnvironmentCard extends StatelessWidget {
  const _BaseEnvironmentCard({
    required this.records,
    required this.baseInstalled,
    required this.dependencies,
    required this.onRepair,
  });

  final Map<String, InstalledDependency> records;
  final bool baseInstalled;
  final DependencyOperation dependencies;
  final VoidCallback? onRepair;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final brand = context.brandColors;
    final isCurrentOperation =
        dependencies.title == '基础环境' || dependencies.title == '开发依赖';
    final isInstallingThis = dependencies.busy && isCurrentOperation;
    final failedThis = dependencies.failed && isCurrentOperation;

    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: AppRadius.mediumAll,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const AppIconBadge(
                  icon: LucideIcons.terminal,
                  tone: AppTone.teal,
                  size: 40,
                  iconSize: 20,
                ),
                const SizedBox(width: AppSpacing.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('基础开发环境', style: theme.textTheme.titleMedium),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '随 Ubuntu 自动配置的核心工具',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.s),
                _StatusBadge(
                  label: baseInstalled ? '已就绪' : '未就绪',
                  icon: baseInstalled
                      ? LucideIcons.circleCheck
                      : LucideIcons.triangleAlert,
                  backgroundColor: baseInstalled
                      ? brand.tealContainer
                      : colors.errorContainer,
                  foregroundColor: baseInstalled
                      ? brand.onTealContainer
                      : colors.onErrorContainer,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.m),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.s),
            for (final profile in DependencyProfile.base) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        profile.label,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.m),
                    Flexible(
                      child: Text(
                        records[profile.id]?.version ?? '未安装',
                        textAlign: TextAlign.end,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: records.containsKey(profile.id)
                              ? colors.onSurfaceVariant
                              : colors.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (isInstallingThis ||
                (failedThis && dependencies.step != null)) ...[
              const SizedBox(height: AppSpacing.m),
              InstallationProgress(
                title: '基础环境',
                steps: [for (final step in DependencyStep.values) step.label],
                current: (dependencies.step ?? DependencyStep.repairing).index,
                description:
                    (dependencies.step ?? DependencyStep.repairing).description,
                lines: dependencies.logTail,
                startedAt: dependencies.stepStartedAt,
                updatedAt: dependencies.lastOutputAt,
                running: isInstallingThis,
              ),
            ],
            if (failedThis && dependencies.error != null) ...[
              const SizedBox(height: AppSpacing.s),
              Text(
                dependencies.error!,
                style: theme.textTheme.bodySmall?.copyWith(color: colors.error),
              ),
            ],
            if (isInstallingThis) ...[
              Align(
                alignment: Alignment.centerRight,
                child: Consumer(
                  builder: (context, ref, _) => TextButton(
                    onPressed: ref
                        .read(dependencyControllerProvider.notifier)
                        .cancel,
                    child: const Text('取消安装'),
                  ),
                ),
              ),
            ] else if (!baseInstalled) ...[
              const SizedBox(height: AppSpacing.m),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: dependencies.busy ? null : onRepair,
                  icon: const Icon(LucideIcons.wrench, size: 18),
                  label: const Text('修复基础环境'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BundleCard extends StatelessWidget {
  const _BundleCard({
    required this.bundle,
    required this.records,
    required this.dependencies,
    required this.onInstall,
  });

  final DependencyBundle bundle;
  final Map<String, InstalledDependency> records;
  final DependencyOperation dependencies;
  final VoidCallback? onInstall;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final brand = context.brandColors;
    final isInstalled = bundle.isInstalled(records);
    final isPartial = bundle.isPartiallyInstalled(records);
    final installedCount = bundle.installedCount(records);
    final isInstallingThis =
        dependencies.busy && dependencies.title == bundle.label;
    final failedThis =
        dependencies.failed && dependencies.title == bundle.label;

    final (badgeLabel, badgeIcon, badgeBg, badgeFg) = isInstalled
        ? (
            '已安装',
            LucideIcons.circleCheck,
            brand.tealContainer,
            brand.onTealContainer,
          )
        : isPartial
        ? (
            '部分安装 · $installedCount/${bundle.profiles.length} 组',
            LucideIcons.circleAlert,
            brand.lavenderContainer,
            brand.onLavenderContainer,
          )
        : (
            '未安装',
            LucideIcons.circle,
            colors.surfaceContainerHighest,
            colors.onSurfaceVariant,
          );

    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: AppRadius.mediumAll,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppIconBadge(
                  icon: bundle.icon,
                  tone: AppTone.primary,
                  size: 40,
                  iconSize: 20,
                ),
                const SizedBox(width: AppSpacing.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(bundle.label, style: theme.textTheme.titleMedium),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        bundle.description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.m),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: _StatusBadge(
                label: badgeLabel,
                icon: badgeIcon,
                backgroundColor: badgeBg,
                foregroundColor: badgeFg,
              ),
            ),
            const SizedBox(height: AppSpacing.m),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.s),
            for (final profile in bundle.profiles) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        profile.label,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.m),
                    Flexible(
                      child: Text(
                        records[profile.id]?.version ?? '未安装',
                        textAlign: TextAlign.end,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: records.containsKey(profile.id)
                              ? colors.onSurfaceVariant
                              : colors.outline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (isInstallingThis ||
                (failedThis && dependencies.step != null)) ...[
              const SizedBox(height: AppSpacing.m),
              InstallationProgress(
                title: bundle.label,
                steps: [for (final step in DependencyStep.values) step.label],
                current: (dependencies.step ?? DependencyStep.repairing).index,
                description:
                    (dependencies.step ?? DependencyStep.repairing).description,
                lines: dependencies.logTail,
                startedAt: dependencies.stepStartedAt,
                updatedAt: dependencies.lastOutputAt,
                running: isInstallingThis,
              ),
            ],
            if (isInstallingThis) ...[
              Align(
                alignment: Alignment.centerRight,
                child: Consumer(
                  builder: (context, ref, _) => TextButton(
                    onPressed: ref
                        .read(dependencyControllerProvider.notifier)
                        .cancel,
                    child: const Text('取消安装'),
                  ),
                ),
              ),
            ] else ...[
              if (failedThis && dependencies.error != null) ...[
                const SizedBox(height: AppSpacing.s),
                Text(
                  dependencies.error!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.error,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.m),
              Align(
                alignment: Alignment.centerRight,
                child: isInstalled
                    ? OutlinedButton.icon(
                        onPressed: dependencies.busy ? null : onInstall,
                        icon: const Icon(LucideIcons.rotateCw, size: 18),
                        label: const Text('重新安装'),
                      )
                    : isPartial
                    ? FilledButton.icon(
                        onPressed: dependencies.busy ? null : onInstall,
                        icon: const Icon(LucideIcons.wrench, size: 18),
                        label: const Text('继续安装'),
                      )
                    : FilledButton.icon(
                        onPressed: dependencies.busy ? null : onInstall,
                        icon: const Icon(LucideIcons.download, size: 18),
                        label: const Text('安装'),
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: AppRadius.smallAll,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: foregroundColor),
            const SizedBox(width: AppSpacing.xs),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: foregroundColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
