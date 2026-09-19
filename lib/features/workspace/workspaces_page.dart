import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/error/failure.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_icon_badge.dart';
import '../../../core/widgets/app_linear_progress_indicator.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../data/models/workspace.dart';
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
    final showProgress = operation.busy || environment.isLoading;
    final progress = operation.busy && (operation.total ?? 0) > 0
        ? (operation.bytes / operation.total!).clamp(0.0, 1.0)
        : null;
    final progressLabel = operation.busy
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
        ],
      ),
    );
  }
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
