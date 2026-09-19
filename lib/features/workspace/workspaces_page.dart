import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/error/failure.dart';
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
import 'workspace_controller.dart';

class WorkspacesPage extends ConsumerStatefulWidget {
  const WorkspacesPage({super.key});
  @override
  ConsumerState<WorkspacesPage> createState() => _WorkspacesPageState();
}

class _WorkspacesPageState extends ConsumerState<WorkspacesPage> {
  @override
  Widget build(BuildContext context) {
    final platform = ref.watch(linuxPlatformInfoProvider);
    final environment = ref.watch(runtimeEnvironmentProvider);
    final replacesEnvironment = environment.value?.rootPath != null;
    final operation = ref.watch(environmentControllerProvider);
    final dependencies = ref.watch(dependencyControllerProvider);
    final showProgress =
        operation.busy || environment.isLoading || dependencies.busy;
    // 依赖安装没有可计量的总量，按设计规范使用不定进度。
    final progress =
        !dependencies.busy && operation.busy && (operation.total ?? 0) > 0
        ? (operation.bytes / operation.total!).clamp(0.0, 1.0)
        : null;
    final progressLabel = dependencies.busy
        ? '正在安装${DependencyProfile.byId(dependencies.profileId ?? '')?.label ?? '依赖'}'
        : operation.busy
        ? _phase(operation.phase ?? EnvironmentPhase.checking)
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
          Text(
            'Ubuntu 24.04 ARM64',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (!operation.busy)
            Text(
              '下载 ${(UbuntuImage.downloadBytes / 1048576).toStringAsFixed(1)} MiB',
            ),
          if (platform.value?.available == false)
            const Text('此设备不支持 Ubuntu 环境，目前仅支持 ARM64。'),
          const SizedBox(height: 8),
          if (!operation.busy)
            environment.when(
              data: (value) => Text(
                '${_phase(value.phase)}${value.installedBytes > 0 ? ' · ${(value.installedBytes / 1048576).toStringAsFixed(1)} MiB' : ''}${value.error == null ? '' : '\n${value.error}'}',
              ),
              loading: () => const Text('正在读取环境状态…'),
              error: (error, _) =>
                  Text(error is Failure ? error.userMessage : '环境状态读取失败'),
            ),
          const SizedBox(height: 16),
          if (operation.busy) ...[
            Text(
              progress == null
                  ? progressLabel
                  : '$progressLabel · ${(progress * 100).floor()}%',
            ),
            if (progress != null)
              Text(
                '${(operation.bytes / 1048576).toStringAsFixed(1)} / ${(operation.total! / 1048576).toStringAsFixed(1)} MiB',
              )
            else if (operation.bytes > 0)
              Text('${(operation.bytes / 1048576).toStringAsFixed(1)} MiB'),
            TextButton(
              onPressed: ref
                  .read(environmentControllerProvider.notifier)
                  .cancel,
              child: const Text('取消安装'),
            ),
          ] else
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    style: replacesEnvironment
                        ? FilledButton.styleFrom(
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .error,
                            foregroundColor: Theme.of(context)
                                .colorScheme
                                .onError,
                          )
                        : null,
                    onPressed:
                        environment.hasValue &&
                            platform.value?.available == true
                        ? () async {
                            final allowed = await showDialog<bool>(
                              context: context,
                              builder: (context) => AppDialog(
                                title: environment.value?.ready == true
                                    ? '重新安装 Ubuntu？'
                                    : '安装 Ubuntu？',
                                icon: replacesEnvironment
                                    ? Symbols.warning
                                    : null,
                                tone: replacesEnvironment
                                    ? AppTone.error
                                    : AppTone.primary,
                                content: Text(
                                  '下载固定版本 ${UbuntuImage.revision}，需至少 605 MiB 可用空间。${environment.value?.ready == true ? '安装成功后替换原环境及其依赖，工作区文件保留。' : '工作区程序以相月应用身份运行，请只执行信任的程序。'}',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('取消'),
                                  ),
                                  FilledButton(
                                    style: replacesEnvironment
                                        ? FilledButton.styleFrom(
                                            backgroundColor: Theme.of(context)
                                                .colorScheme
                                                .error,
                                            foregroundColor: Theme.of(context)
                                                .colorScheme
                                                .onError,
                                          )
                                        : null,
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('安装'),
                                  ),
                                ],
                              ),
                            );
                            if (allowed == true && mounted) {
                              await ref
                                  .read(environmentControllerProvider.notifier)
                                  .install();
                            }
                          }
                        : null,
                    child: Text(
                      environment.value?.ready == true ? '重新安装' : '安装环境',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                if (environment.value?.rootPath != null) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                      ),
                      onPressed: () async {
                        final allowed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AppDialog(
                            title: '卸载 Ubuntu 环境？',
                            icon: Symbols.delete,
                            tone: AppTone.error,
                            content: const Text(
                              '删除环境和已安装依赖，保留全部工作区文件。正在使用时不能卸载。',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('取消'),
                              ),
                              FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: Theme.of(context)
                                      .colorScheme
                                      .error,
                                  foregroundColor: Theme.of(context)
                                      .colorScheme
                                      .onError,
                                ),
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('卸载'),
                              ),
                            ],
                          ),
                        );
                        if (allowed == true && mounted) {
                          await ref
                              .read(environmentControllerProvider.notifier)
                              .uninstall();
                        }
                      },
                      child: const Text('卸载环境', textAlign: TextAlign.center),
                    ),
                  ),
                ],
              ],
            ),
          if (operation.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                operation.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (!operation.busy && environment.value?.ready == true) ...[
            const SizedBox(height: 24),
            AppSection(
              title: '环境依赖',
              subtitle: '按需安装开发依赖并记录版本；失败或取消保留已知状态',
              child: Column(
                children: [
                  for (final profile in DependencyProfile.all)
                    _DependencyTile(
                      profile: profile,
                      installed:
                          environment.value?.installedDependencies[profile.id],
                      operation: dependencies,
                      onInstall: dependencies.busy
                          ? null
                          : () => _confirmInstall(profile),
                      onShowInfo: () => _showDependencyInfo(
                        profile,
                        environment.value!.installedDependencies[profile.id]!,
                      ),
                      onReinstall: dependencies.busy
                          ? null
                          : () => _confirmInstall(profile, reinstall: true),
                    ),
                ],
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
                    if (dependencies.failedProfileId != null)
                      TextButton(
                        onPressed: () => ref
                            .read(dependencyControllerProvider.notifier)
                            .install(dependencies.failedProfileId!),
                        child: const Text('重试'),
                      ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmInstall(
    DependencyProfile profile, {
    bool reinstall = false,
  }) async {
    final allowed = await showDialog<bool>(
      context: context,
      builder: (context) => AppDialog(
        title: reinstall ? '重新安装${profile.label}？' : '安装${profile.label}？',
        icon: reinstall ? Symbols.refresh : Symbols.terminal,
        content: Text(
          reinstall
              ? '通过 Ubuntu 软件源覆盖安装相同软件包，已有配置保留，可能需要数分钟。'
              : '通过 Ubuntu 软件源安装 ${profile.packages.join('、')}，可能需要数分钟；已安装内容跨会话保留。',
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
      await ref.read(dependencyControllerProvider.notifier).install(profile.id);
    }
  }

  /// 已安装条目点击后的信息概览；重装从这里或右侧按钮进入同一确认。
  Future<void> _showDependencyInfo(
    DependencyProfile profile,
    InstalledDependency installed,
  ) async {
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AppDialog(
        title: profile.label,
        icon: Symbols.check_circle,
        tone: AppTone.teal,
        description: '已安装 · ${_formatDate(installed.installedAt)}',
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('版本：${installed.version ?? '未记录'}'),
            const SizedBox(height: 8),
            Text('包含软件包：'),
            for (final package in profile.packages) Text('· $package'),
            const SizedBox(height: 8),
            Text('说明：${profile.description}'),
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
      await _confirmInstall(profile, reinstall: true);
    }
  }
}

class _DependencyTile extends StatelessWidget {
  const _DependencyTile({
    required this.profile,
    required this.installed,
    required this.operation,
    required this.onInstall,
    required this.onShowInfo,
    required this.onReinstall,
  });
  final DependencyProfile profile;
  final InstalledDependency? installed;
  final DependencyOperation operation;
  final VoidCallback? onInstall;
  final VoidCallback? onShowInfo;

  /// 已安装条目右侧的重装按钮；与 onInstall 分开便于概览弹窗复用。
  final VoidCallback? onReinstall;

  @override
  Widget build(BuildContext context) {
    final installing = operation.busy && operation.profileId == profile.id;
    final blocked = operation.busy && !installing;
    final theme = Theme.of(context);
    final isInstalled = installed != null;
    final subtitle = installing
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_stepLabel(operation.step ?? DependencyStep.repairing)),
              for (final line in operation.logTail.take(3))
                Text(
                  line,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
            ],
          )
        : Text(
            !isInstalled
                ? profile.description
                : '${installed!.version ?? '已安装'} · ${_date(installed!.installedAt)}',
          );
    return AppListTile(
      title: Text(profile.label),
      subtitle: subtitle,
      // 已安装用成功色勾选徽标；未安装保持终端图标。
      leading: AppIconBadge(
        icon: isInstalled ? Symbols.check_circle : Symbols.terminal,
        tone: isInstalled ? AppTone.teal : AppTone.primary,
        size: 40,
        iconSize: 20,
      ),
      trailing: installing
          ? const AppLoadingIndicator.small(size: 20)
          : blocked
          ? null
          : isInstalled
          ? IconButton(
              tooltip: '重新安装',
              onPressed: onReinstall,
              icon: const Icon(Symbols.refresh),
            )
          : const Icon(Symbols.download),
      // 已安装的点击展示概览而不是重复的安装确认。
      onTap: blocked
          ? null
          : isInstalled
          ? onShowInfo
          : onInstall,
    );
  }

  static String _date(DateTime time) => _formatDate(time);
  String _stepLabel(DependencyStep step) => switch (step) {
    DependencyStep.repairing => '修复包状态',
    DependencyStep.updating => '更新软件源',
    DependencyStep.installing => '正在安装 ${profile.label}',
    DependencyStep.verifying => '验证版本',
  };
}

String _phase(EnvironmentPhase phase) => switch (phase) {
  EnvironmentPhase.notInstalled => '未安装',
  EnvironmentPhase.downloading => '下载中',
  EnvironmentPhase.verifying => '校验镜像',
  EnvironmentPhase.extracting => '解压文件',
  EnvironmentPhase.checking => '检查 shell 和文件读写',
  EnvironmentPhase.ready => '可用',
  EnvironmentPhase.failed => '安装失败',
  EnvironmentPhase.cancelled => '已取消',
};

String _formatDate(DateTime time) =>
    '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')}';
