import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/error/failure.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_icon_badge.dart';
import '../../../core/widgets/app_linear_progress_indicator.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../data/models/workspace.dart';
import '../commands/command_channels_section.dart';
import 'dependency_controller.dart';
import 'dependency_profiles.dart';
import 'linux_installer.dart';
import 'installation_progress.dart';
import 'workspace_controller.dart';
import 'ubuntu_icon.dart';

class WorkspacesPage extends ConsumerStatefulWidget {
  const WorkspacesPage({super.key});
  @override
  ConsumerState<WorkspacesPage> createState() => _WorkspacesPageState();
}

class _WorkspacesPageState extends ConsumerState<WorkspacesPage> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final platform = ref.watch(linuxPlatformInfoProvider);
    final environment = ref.watch(runtimeEnvironmentProvider);
    final replacesEnvironment = environment.value?.rootPath != null;
    final operation = ref.watch(environmentControllerProvider);
    final dependencies = ref.watch(dependencyControllerProvider);
    final installingDependencies =
        operation.busy && operation.phase == EnvironmentPhase.ready;
    final allDependenciesInstalled = DependencyProfile.all.every(
      (profile) =>
          environment.value?.installedDependencies.containsKey(profile.id) ==
          true,
    );
    final needsRepair = !allDependenciesInstalled;
    final VoidCallback? onInstallEnvironment =
        environment.hasValue &&
            !operation.busy &&
            !dependencies.busy &&
            platform.value?.available == true
        ? () => _confirmEnvironmentInstall(
            replacesEnvironment: replacesEnvironment,
          )
        : null;
    final environmentActionStyle = IconButton.styleFrom(
      foregroundColor: colors.error,
    );
    final showProgress =
        operation.busy || environment.isLoading || dependencies.busy;
    // 依赖安装没有可计量的总量，按设计规范使用不定进度。
    final progress =
        !dependencies.busy && operation.busy && (operation.total ?? 0) > 0
        ? (operation.bytes / operation.total!).clamp(0.0, 1.0)
        : null;
    final progressLabel = dependencies.busy || installingDependencies
        ? '正在安装依赖'
        : operation.busy
        ? operation.uninstalling
              ? '正在卸载环境'
              : _phase(operation.phase)
        : '正在读取环境';

    final String subtitle;
    final Color? subtitleColor;
    if (operation.busy) {
      subtitle = operation.uninstalling
          ? '24.04 ARM64 · 卸载中'
          : installingDependencies
          ? '24.04 ARM64 · 配置依赖中'
          : '24.04 ARM64 · 安装中';
      subtitleColor = null;
    } else if (dependencies.busy) {
      subtitle = '24.04 ARM64 · 配置依赖中';
      subtitleColor = null;
    } else if (!replacesEnvironment) {
      subtitle = '24.04 ARM64 · 未安装';
      subtitleColor = null;
    } else if (environment.value?.ready != true) {
      subtitle = '24.04 ARM64 · 未就绪';
      subtitleColor = colors.error;
    } else if (needsRepair) {
      subtitle = '24.04 ARM64 · 依赖未完整安装';
      subtitleColor = colors.error;
    } else {
      subtitle = '24.04 ARM64 · 已就绪';
      subtitleColor = null;
    }

    final headerActions = <Widget>[
      if (operation.busy || dependencies.busy)
        ...const []
      else if (replacesEnvironment) ...[
        if (environment.value?.ready != true)
          IconButton(
            tooltip: '重试安装 Ubuntu',
            style: environmentActionStyle,
            onPressed: onInstallEnvironment,
            icon: const Icon(LucideIcons.rotateCw),
          )
        else
          IconButton(
            tooltip: '开发依赖详情',
            onPressed: () =>
                _showDependencyInfo(environment.value!.installedDependencies),
            icon: const Icon(LucideIcons.info),
          ),
        IconButton(
          tooltip: '卸载 Ubuntu',
          style: environmentActionStyle,
          onPressed: _confirmEnvironmentUninstall,
          icon: const Icon(LucideIcons.trash2),
        ),
      ] else
        FilledButton.icon(
          style: FilledButton.styleFrom(
            minimumSize: const Size(48, 40),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.l,
              vertical: AppSpacing.s,
            ),
            textStyle: theme.textTheme.labelLarge,
          ),
          onPressed: onInstallEnvironment,
          icon: const Icon(LucideIcons.download, size: 20),
          label: const Text('安装'),
        ),
    ];

    void onCancel() {
      if (operation.busy) {
        ref.read(environmentControllerProvider.notifier).cancel();
      } else {
        ref.read(dependencyControllerProvider.notifier).cancel();
      }
    }

    return AppScaffold(
      title: '环境设置',
      showAppBarDivider: !showProgress,
      appBarBottom: showProgress
          ? PreferredSize(
              preferredSize: const Size.fromHeight(18),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: AppLinearProgressIndicator(
                  value: progress,
                  semanticsLabel: progressLabel,
                ),
              ),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.l),
        children: [
          Material(
            color: context.brandColors.goldContainer,
            borderRadius: AppRadius.mediumAll,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.l),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _UbuntuHeader(
                    subtitle: subtitle,
                    subtitleColor: subtitleColor,
                    actions: headerActions,
                  ),
                  if (platform.value?.available == false)
                    const Padding(
                      padding: EdgeInsets.only(top: AppSpacing.m),
                      child: Text('此设备不支持 Ubuntu 环境，目前仅支持 ARM64。'),
                    ),
                  if (!operation.busy && !dependencies.busy)
                    environment.when(
                      data: (value) {
                        final status = [
                          if (replacesEnvironment &&
                              value.phase != EnvironmentPhase.ready)
                            _phase(value.phase),
                          ?value.error,
                        ].join('\n');
                        if (status.isEmpty) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.m),
                          child: Text(status),
                        );
                      },
                      loading: () => const Padding(
                        padding: EdgeInsets.only(top: AppSpacing.m),
                        child: Text('正在读取环境状态…'),
                      ),
                      error: (error, _) => Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.m),
                        child: Text(
                          error is Failure ? error.userMessage : '环境状态读取失败',
                          style: TextStyle(color: colors.error),
                        ),
                      ),
                    ),
                  if (dependencies.busy || installingDependencies) ...[
                    const SizedBox(height: AppSpacing.l),
                    InstallationProgress(
                      title: '开发依赖',
                      steps: [
                        for (final step in DependencyStep.values) step.label,
                      ],
                      current:
                          (dependencies.step ?? DependencyStep.repairing).index,
                      description:
                          (dependencies.step ?? DependencyStep.repairing)
                              .description,
                      lines: dependencies.logTail,
                      startedAt: dependencies.stepStartedAt,
                      updatedAt: dependencies.lastOutputAt,
                      running: dependencies.busy,
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: onCancel,
                        child: const Text('取消安装'),
                      ),
                    ),
                  ] else if (operation.busy) ...[
                    const SizedBox(height: AppSpacing.l),
                    if (operation.uninstalling)
                      const Text('正在卸载环境…')
                    else ...[
                      InstallationProgress(
                        title: '基础环境',
                        steps: [
                          for (final phase in _installPhases) _phase(phase),
                        ],
                        current: _installPhases
                            .indexOf(operation.phase)
                            .clamp(0, _installPhases.length - 1),
                        description: switch (operation.phase) {
                          null => '检查设备支持与可用空间',
                          EnvironmentPhase.downloading => '从 Ubuntu 下载固定版本镜像',
                          EnvironmentPhase.verifying => '校验 SHA-256，确认镜像完整性',
                          EnvironmentPhase.extracting => '展开归档、写入文件并设置权限',
                          EnvironmentPhase.configuring =>
                            '选择软件源并配置 DNS 与 Ubuntu 软件包来源',
                          _ => '启动 Ubuntu shell，检查文件读写与进程退出码',
                        },
                        detail: progress != null
                            ? '${(progress * 100).floor()}% · ${(operation.bytes / 1048576).toStringAsFixed(1)} / ${(operation.total! / 1048576).toStringAsFixed(1)} MiB'
                            : operation.bytes > 0
                            ? '已写入 ${(operation.bytes / 1048576).toStringAsFixed(1)} MiB'
                            : null,
                        startedAt: operation.phaseStartedAt,
                        updatedAt: operation.lastProgressAt,
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: onCancel,
                          child: const Text('取消安装'),
                        ),
                      ),
                    ],
                  ] else if (dependencies.failed &&
                      dependencies.step != null) ...[
                    const SizedBox(height: AppSpacing.l),
                    InstallationProgress(
                      title: '开发依赖',
                      steps: [
                        for (final step in DependencyStep.values) step.label,
                      ],
                      current: dependencies.step!.index,
                      description: dependencies.step!.description,
                      lines: dependencies.logTail,
                      startedAt: dependencies.stepStartedAt,
                      updatedAt: dependencies.lastOutputAt,
                      running: false,
                    ),
                  ],
                  if (dependencies.error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.m),
                      child: Text(
                        dependencies.error!,
                        style: TextStyle(color: colors.error),
                      ),
                    ),
                  if (operation.error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.m),
                      child: Text(
                        operation.error!,
                        style: TextStyle(color: colors.error),
                      ),
                    ),
                  if (needsRepair &&
                      !operation.busy &&
                      !dependencies.busy &&
                      environment.value?.ready == true) ...[
                    if (dependencies.error == null)
                      const Padding(
                        padding: EdgeInsets.only(top: AppSpacing.m),
                        child: Text('开发依赖未安装完成，可能影响工具执行'),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.m),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          onPressed: platform.value?.available == true
                              ? _repairEnvironment
                              : null,
                          icon: const Icon(LucideIcons.wrench),
                          label: const Text('修复环境'),
                        ),
                      ),
                    ),
                  ],
                  if (!needsRepair &&
                      !operation.busy &&
                      !dependencies.busy &&
                      environment.value?.ready == true)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.m),
                      child: Text(
                        '内置 Python、Node.js、Git 与 ripgrep',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.l),
          const CommandChannelsSection(),
        ],
      ),
    );
  }

  Future<void> _confirmEnvironmentInstall({
    required bool replacesEnvironment,
  }) async {
    final colors = Theme.of(context).colorScheme;
    final allowed = await showDialog<bool>(
      context: context,
      builder: (context) => AppDialog(
        title: replacesEnvironment ? '重试安装 Ubuntu？' : '安装 Ubuntu？',
        icon: replacesEnvironment ? LucideIcons.triangleAlert : null,
        tone: replacesEnvironment ? AppTone.error : AppTone.primary,
        content: Text(
          '安装 Ubuntu ${UbuntuImage.revision}，并自动安装 Python、Node.js、Git 与 ripgrep。'
          '基础环境需至少 605 MiB 可用空间，依赖安装另需空间。'
          '保留会话和服务文件；程序以相月应用身份运行。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: replacesEnvironment
                ? FilledButton.styleFrom(
                    backgroundColor: colors.error,
                    foregroundColor: colors.onError,
                  )
                : null,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('安装'),
          ),
        ],
      ),
    );
    if (allowed == true && mounted) {
      await ref.read(environmentControllerProvider.notifier).install();
    }
  }

  Future<void> _confirmEnvironmentUninstall() async {
    final colors = Theme.of(context).colorScheme;
    final allowed = await showDialog<bool>(
      context: context,
      builder: (context) => AppDialog(
        title: '卸载 Ubuntu 环境？',
        icon: LucideIcons.trash2,
        tone: AppTone.error,
        content: const Text(
          '保留会话和 MCP 服务文件；删除已安装软件及 /root 等其他 Ubuntu 内容。正在使用时不能卸载。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: colors.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('卸载'),
          ),
        ],
      ),
    );
    if (allowed == true && mounted) {
      await ref.read(environmentControllerProvider.notifier).uninstall();
    }
  }

  Future<void> _repairEnvironment() async {
    final environment = ref.read(runtimeEnvironmentProvider).value;
    if (ref.read(environmentControllerProvider).busy ||
        ref.read(dependencyControllerProvider).busy ||
        environment == null ||
        !environment.ready ||
        DependencyProfile.all.every(
          (profile) =>
              environment.installedDependencies.containsKey(profile.id),
        )) {
      return;
    }
    await ref.read(dependencyControllerProvider.notifier).install();
  }

  Future<void> _showDependencyInfo(
    Map<String, InstalledDependency> records,
  ) async {
    var latest = records.values.firstOrNull?.installedAt ?? DateTime.now();
    for (final record in records.values) {
      if (record.installedAt.isAfter(latest)) latest = record.installedAt;
    }
    final allInstalled = DependencyProfile.all.every(
      (profile) => records.containsKey(profile.id),
    );
    await showDialog<void>(
      context: context,
      builder: (context) => AppDialog(
        title: '开发依赖',
        icon: allInstalled
            ? LucideIcons.circleCheck
            : LucideIcons.triangleAlert,
        tone: allInstalled ? AppTone.teal : AppTone.error,
        description: allInstalled
            ? '全部已安装 · ${_formatDate(latest)}'
            : '部分依赖未安装',
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final profile in DependencyProfile.all)
              Text('${profile.label}：${records[profile.id]?.version ?? '未安装'}'),
            const SizedBox(height: 8),
            Text('包含软件包：${DependencyProfile.completePackages}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}

class _UbuntuHeader extends StatelessWidget {
  const _UbuntuHeader({
    required this.subtitle,
    required this.actions,
    this.subtitleColor,
  });

  final String subtitle;
  final Color? subtitleColor;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final details = Row(
      children: [
        const UbuntuIcon(),
        const SizedBox(width: AppSpacing.m),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Ubuntu', style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: subtitleColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
    if (actions.isEmpty) return details;
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
        if (constraints.maxWidth < 280 * scale) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              details,
              const SizedBox(height: AppSpacing.m),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: AppSpacing.s,
                runSpacing: AppSpacing.s,
                children: actions,
              ),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: details),
            const SizedBox(width: AppSpacing.m),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < actions.length; i++) ...[
                  if (i > 0) const SizedBox(width: AppSpacing.s),
                  actions[i],
                ],
              ],
            ),
          ],
        );
      },
    );
  }
}

const _installPhases = [
  null,
  EnvironmentPhase.downloading,
  EnvironmentPhase.verifying,
  EnvironmentPhase.extracting,
  EnvironmentPhase.configuring,
  EnvironmentPhase.checking,
];

String _phase(EnvironmentPhase? phase) => switch (phase) {
  null => '准备安装',
  EnvironmentPhase.notInstalled => '未安装',
  EnvironmentPhase.downloading => '下载中',
  EnvironmentPhase.verifying => '校验镜像',
  EnvironmentPhase.extracting => '解压文件',
  EnvironmentPhase.configuring => '配置软件源',
  EnvironmentPhase.checking => '检查 shell 和文件读写',
  EnvironmentPhase.ready => '安装完成',
  EnvironmentPhase.failed => '安装失败',
  EnvironmentPhase.cancelled => '已取消',
};

String _formatDate(DateTime time) =>
    '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')}';
