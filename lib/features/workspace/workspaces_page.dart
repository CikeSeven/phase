import '../commands/command_channels_section.dart';
import '../commands/command_channels_controller.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/error/failure.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_icon_badge.dart';
import '../../../core/widgets/app_linear_progress_indicator.dart';
import '../../../core/widgets/app_list_tile.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_section.dart';
import '../../../data/models/workspace.dart';
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
    final primaryEnvironment = ref.watch(defaultPrimaryEnvironmentProvider);
    final VoidCallback? onInstallEnvironment =
        environment.hasValue &&
            !dependencies.busy &&
            platform.value?.available == true
        ? () => _confirmEnvironmentInstall(
            replacesEnvironment: replacesEnvironment,
            ready: environment.value?.ready == true,
          )
        : null;
    final environmentActionStyle = IconButton.styleFrom(
      foregroundColor: colors.error,
    );
    final commandBusy =
        ref.watch(commandChannelsControllerProvider).value?.busy == true;
    final showProgress =
        operation.busy ||
        environment.isLoading ||
        dependencies.busy ||
        commandBusy ||
        primaryEnvironment.saving;
    // 依赖安装没有可计量的总量，按设计规范使用不定进度。
    final progress =
        !dependencies.busy &&
            !commandBusy &&
            operation.busy &&
            (operation.total ?? 0) > 0
        ? (operation.bytes / operation.total!).clamp(0.0, 1.0)
        : null;
    final progressLabel = primaryEnvironment.saving
        ? '正在保存主环境'
        : commandBusy
        ? '正在配置命令通道'
        : dependencies.busy
        ? '正在安装依赖'
        : operation.busy
        ? operation.uninstalling
              ? '正在卸载环境'
              : _phase(operation.phase)
        : '正在读取环境';
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
        padding: const EdgeInsets.all(24),
        children: [
          AppSection(
            title: '新会话主环境',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                RadioGroup<PrimaryEnvironment>(
                  groupValue: primaryEnvironment.environment,
                  onChanged: (value) {
                    if (value != null && !primaryEnvironment.saving) {
                      ref
                          .read(defaultPrimaryEnvironmentProvider.notifier)
                          .select(value);
                    }
                  },
                  child: Column(
                    children: [
                      for (final value in PrimaryEnvironment.values)
                        RadioListTile<PrimaryEnvironment>(
                          contentPadding: EdgeInsets.zero,
                          title: Text(value.label),
                          value: value,
                          enabled: !primaryEnvironment.saving,
                        ),
                    ],
                  ),
                ),
                if (primaryEnvironment.error != null)
                  Text(
                    primaryEnvironment.error!,
                    style: TextStyle(color: colors.error),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.l),
          Material(
            color: context.brandColors.goldContainer,
            borderRadius: AppRadius.mediumAll,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.l),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _UbuntuHeader(
                    actions: operation.busy
                        ? const []
                        : [
                            if (replacesEnvironment) ...[
                              IconButton(
                                tooltip: '重新安装 Ubuntu',
                                style: environmentActionStyle,
                                onPressed: onInstallEnvironment,
                                icon: const Icon(Symbols.refresh),
                              ),
                              IconButton(
                                tooltip: '卸载 Ubuntu',
                                style: environmentActionStyle,
                                onPressed: dependencies.busy
                                    ? null
                                    : _confirmEnvironmentUninstall,
                                icon: const Icon(Symbols.delete),
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
                                icon: const Icon(Symbols.download, size: 20),
                                label: const Text('安装'),
                              ),
                          ],
                  ),
                  if (platform.value?.available == false)
                    const Padding(
                      padding: EdgeInsets.only(top: AppSpacing.m),
                      child: Text('此设备不支持 Ubuntu 环境，目前仅支持 ARM64。'),
                    ),
                  if (!operation.busy)
                    environment.when(
                      data: (value) {
                        final status = [
                          if (value.phase != EnvironmentPhase.ready)
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
                  if (operation.busy) ...[
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
                          onPressed: ref
                              .read(environmentControllerProvider.notifier)
                              .cancel,
                          child: const Text('取消安装'),
                        ),
                      ),
                    ],
                  ],
                  if (operation.error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.m),
                      child: Text(
                        operation.error!,
                        style: TextStyle(color: colors.error),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (!operation.busy && environment.value?.ready == true) ...[
            const SizedBox(height: 24),
            AppSection(
              title: '环境依赖',
              child: _DependencyTile(
                records: environment.value!.installedDependencies,
                operation: dependencies,
                onInstall: dependencies.busy ? null : () => _confirmInstall(),
                onShowInfo: () => _showDependencyInfo(
                  environment.value!.installedDependencies,
                ),
                onReinstall: dependencies.busy
                    ? null
                    : () => _confirmInstall(reinstall: true),
              ),
            ),
            if (dependencies.busy ||
                dependencies.failed && dependencies.step != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: InstallationProgress(
                  title: '开发依赖',
                  steps: [for (final step in DependencyStep.values) step.label],
                  current:
                      (dependencies.step ?? DependencyStep.repairing).index,
                  description: (dependencies.step ?? DependencyStep.repairing)
                      .description,
                  lines: dependencies.logTail,
                  startedAt: dependencies.stepStartedAt,
                  updatedAt: dependencies.lastOutputAt,
                  running: dependencies.busy,
                ),
              ),
            if (dependencies.busy)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: TextButton(
                  onPressed: ref
                      .read(dependencyControllerProvider.notifier)
                      .cancel,
                  child: const Text('取消安装'),
                ),
              ),
            if (dependencies.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        dependencies.error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                    if (dependencies.failed)
                      TextButton(
                        onPressed: () => ref
                            .read(dependencyControllerProvider.notifier)
                            .install(),
                        child: const Text('重试'),
                      ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 24),
          const CommandChannelsSection(),
        ],
      ),
    );
  }

  Future<void> _confirmEnvironmentInstall({
    required bool replacesEnvironment,
    required bool ready,
  }) async {
    final colors = Theme.of(context).colorScheme;
    final allowed = await showDialog<bool>(
      context: context,
      builder: (context) => AppDialog(
        title: ready ? '重新安装 Ubuntu？' : '安装 Ubuntu？',
        icon: replacesEnvironment ? Symbols.warning : null,
        tone: replacesEnvironment ? AppTone.error : AppTone.primary,
        content: Text(
          '下载固定版本 ${UbuntuImage.revision}，需至少 605 MiB 可用空间。${ready ? '安装成功后替换原环境及其依赖，工作区文件保留。' : '工作区程序以相月应用身份运行，请只执行信任的程序。'}',
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
        icon: Symbols.delete,
        tone: AppTone.error,
        content: const Text('删除环境和已安装依赖，保留全部工作区文件。正在使用时不能卸载。'),
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

  Future<void> _confirmInstall({bool reinstall = false}) async {
    final allowed = await showDialog<bool>(
      context: context,
      builder: (context) => AppDialog(
        title: reinstall ? '重新安装环境依赖？' : '安装环境依赖？',
        icon: reinstall ? Symbols.refresh : Symbols.terminal,
        content: Text(
          reinstall
              ? '通过 Ubuntu 软件源覆盖安装相同软件包，已有配置保留，可能需要数分钟。'
              : '通过 Ubuntu 软件源一次安装 ${DependencyProfile.completePackages}，'
                    '可能需要数分钟；已安装内容跨会话保留。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(reinstall ? '重新安装' : '安装'),
          ),
        ],
      ),
    );
    if (allowed == true && mounted) {
      await ref.read(dependencyControllerProvider.notifier).install();
    }
  }

  /// 全部安装后点击条目的信息概览；重装从这里或右侧按钮进入同一确认。
  Future<void> _showDependencyInfo(
    Map<String, InstalledDependency> records,
  ) async {
    var latest = records.values.first.installedAt;
    for (final record in records.values) {
      if (record.installedAt.isAfter(latest)) latest = record.installedAt;
    }
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AppDialog(
        title: '开发依赖',
        icon: Symbols.check_circle,
        tone: AppTone.teal,
        description: '全部已安装 · ${_formatDate(latest)}',
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final profile in DependencyProfile.all)
              Text('${profile.label}：${records[profile.id]?.version ?? '已安装'}'),
            const SizedBox(height: 8),
            Text('包含软件包：${DependencyProfile.completePackages}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'close'),
            child: const Text('关闭'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'reinstall'),
            child: const Text('重新安装'),
          ),
        ],
      ),
    );
    if (action == 'reinstall' && mounted) {
      await _confirmInstall(reinstall: true);
    }
  }
}

class _UbuntuHeader extends StatelessWidget {
  const _UbuntuHeader({required this.actions});
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
              Text('24.04 ARM64', style: theme.textTheme.bodyMedium),
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

class _DependencyTile extends StatelessWidget {
  const _DependencyTile({
    required this.records,
    required this.operation,
    required this.onInstall,
    required this.onShowInfo,
    required this.onReinstall,
  });
  final Map<String, InstalledDependency> records;
  final DependencyOperation operation;
  final VoidCallback? onInstall;
  final VoidCallback? onShowInfo;

  /// 全部安装后条目右侧的重装按钮；与 onInstall 分开便于概览弹窗复用。
  final VoidCallback? onReinstall;

  @override
  Widget build(BuildContext context) {
    final allInstalled = DependencyProfile.all.every(
      (profile) => records.containsKey(profile.id),
    );
    final installing = operation.busy;
    return Semantics(
      value: installing
          ? '正在安装'
          : allInstalled
          ? '全部已安装'
          : '未全部安装',
      child: AppListTile(
        color: context.brandColors.lavenderContainer,
        title: const Text('开发依赖'),
        subtitle: const Text('Python、Node.js、Git与ripgrep'),
        leading: AppIconBadge(
          icon: allInstalled ? Symbols.check_circle : Symbols.terminal,
          tone: AppTone.lavender,
          size: 40,
          iconSize: 20,
        ),
        trailing: installing
            ? const AppLoadingIndicator.small(size: 20)
            : allInstalled
            ? IconButton(
                tooltip: '重新安装',
                onPressed: onReinstall,
                icon: const Icon(Symbols.refresh),
              )
            : const Icon(Symbols.download),
        // 全部安装后点击展示概览而不是重复的安装确认。
        onTap: installing
            ? null
            : allInstalled
            ? onShowInfo
            : onInstall,
      ),
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
