import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/error/failure.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_icon_badge.dart';
import '../../../core/widgets/app_linear_progress_indicator.dart';
import '../../../core/widgets/app_list_tile.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../data/models/workspace.dart';
import '../../../data/repositories/conversation_repository.dart';
import 'linux_installer.dart';
import 'workspace_actions.dart';
import 'workspace_controller.dart';

class WorkspacesPage extends ConsumerStatefulWidget {
  const WorkspacesPage({super.key, this.conversationId});
  final String? conversationId;
  @override
  ConsumerState<WorkspacesPage> createState() => _WorkspacesPageState();
}

class _WorkspacesPageState extends ConsumerState<WorkspacesPage> {
  String? _draft;
  bool _loaded = false;
  @override
  void initState() {
    super.initState();
    if (widget.conversationId == null) {
      _loaded = true;
    } else {
      _loadBinding();
    }
  }

  Future<void> _loadBinding() async {
    try {
      final repository = await ref.read(conversationRepositoryProvider.future);
      final thread = await repository.getThread(widget.conversationId!);
      if (mounted) {
        setState(() {
          _draft = thread?.conversation.workspaceId;
          _loaded = true;
        });
      }
    } catch (error) {
      if (mounted) _message(error);
    }
  }

  void _message(Object error) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(error is Failure ? error.userMessage : '操作失败，请重试')),
  );
  Future<void> _create() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _WorkspaceNameDialog(),
    );
    if (name == null || !mounted) return;
    final result = await ref
        .read(workspaceActionsProvider.notifier)
        .perform(
          () async =>
              (await ref.read(workspaceRepositoryProvider.future)).create(name),
        );
    if (result != null && mounted) setState(() => _draft = result.id);
  }

  Future<void> _delete(Workspace workspace) async {
    final actions = ref.read(workspaceActionsProvider.notifier);
    await actions.perform(() async {
      final repository = await ref.read(workspaceRepositoryProvider.future);
      final names = await repository.conversationsUsing(workspace.id);
      if (!mounted) return null;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AppDialog(
          title: '删除「${workspace.name}」？',
          icon: Symbols.delete,
          tone: AppTone.error,
          content: Text(
            '${repository.inUse(workspace.id) ? '此工作区有活动任务，请先停止任务。\n' : ''}将删除工作区全部文件并解除会话绑定，历史消息与已保存产物保留。\n关联会话：${names.isEmpty ? '无' : names.join('、')}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              onPressed: repository.inUse(workspace.id)
                  ? null
                  : () => Navigator.pop(context, true),
              child: const Text('删除工作区'),
            ),
          ],
        ),
      );
      if (confirmed != true) return null;
      await repository.delete(workspace.id);
      if (mounted && _draft == workspace.id) setState(() => _draft = null);
      return true;
    });
  }

  Future<void> _save() async {
    final result = await ref.read(workspaceActionsProvider.notifier).perform(
      () async {
        await (await ref.read(workspaceRepositoryProvider.future))
            .bind(widget.conversationId!, _draft);
        return true;
      },
    );
    if (result == true && mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(workspacesProvider);
    final platform = ref.watch(linuxPlatformInfoProvider);
    final environment = ref.watch(runtimeEnvironmentProvider);
    final replacesEnvironment = environment.value?.rootPath != null;
    final operation = ref.watch(environmentControllerProvider);
    final showProgress =
        operation.busy || environment.isLoading || entries.isLoading;
    final progress = operation.busy && (operation.total ?? 0) > 0
        ? (operation.bytes / operation.total!).clamp(0.0, 1.0)
        : null;
    final progressLabel = operation.busy
        ? _phase(operation.phase ?? EnvironmentPhase.checking)
        : '正在读取环境与工作区';
    final action = ref.watch(workspaceActionsProvider);
    ref.listen(workspaceActionsProvider, (_, next) {
      if (next.hasError) _message(next.error!);
    });
    return AppScaffold(
      title: widget.conversationId == null ? '环境与工作区' : '会话工作区',
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
      actions: [
        if (widget.conversationId != null)
          TextButton(
            onPressed: !_loaded || action.isLoading ? null : _save,
            child: const Text('保存'),
          ),
      ],
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
          const SizedBox(height: 32),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            children: [
              Text('工作区', style: Theme.of(context).textTheme.titleMedium),
              TextButton.icon(
                onPressed: action.isLoading ? null : _create,
                icon: const Icon(Symbols.add),
                label: const Text('新建'),
              ),
            ],
          ),
          if (widget.conversationId != null) ...[
            const Text('保存后用于新运行；进行中的任务保留原绑定。复制会话会保留工作区绑定，文件不会重复复制。'),
            AppListTile(
              title: const Text('不绑定工作区'),
              leading: Icon(
                _draft == null
                    ? Symbols.radio_button_checked
                    : Symbols.radio_button_unchecked,
              ),
              onTap: action.isLoading
                  ? null
                  : () => setState(() => _draft = null),
            ),
          ],
          entries.when(
            loading: () => const Text('正在读取工作区…'),
            error: (error, _) =>
                Text(error is Failure ? error.userMessage : '工作区读取失败'),
            data: (values) => Column(
              children: [
                if (values.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('创建工作区以持久保存任务文件。'),
                  ),
                for (final workspace in values)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: AppListTile(
                      title: Text(workspace.name),
                      subtitle: workspace.deleting
                          ? const Text('清理未完成，可重试删除')
                          : null,
                      leading: Icon(
                        widget.conversationId == null
                            ? Symbols.folder
                            : _draft == workspace.id
                            ? Symbols.radio_button_checked
                            : Symbols.radio_button_unchecked,
                      ),
                      onTap: action.isLoading || workspace.deleting
                          ? null
                          : widget.conversationId == null
                          ? () => context.push(
                              '/settings/workspaces/${workspace.id}',
                            )
                          : () => setState(() => _draft = workspace.id),
                      trailing: Wrap(
                        children: [
                          if (widget.conversationId != null)
                            IconButton(
                              tooltip: '查看文件',
                              onPressed: () => context.push(
                                '/settings/workspaces/${workspace.id}',
                              ),
                              icon: const Icon(Symbols.folder_open),
                            ),
                          IconButton(
                            tooltip: '删除工作区',
                            color: Theme.of(context).colorScheme.error,
                            onPressed: action.isLoading
                                ? null
                                : () => _delete(workspace),
                            icon: const Icon(Symbols.delete),
                          ),
                        ],
                      ),
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

class _WorkspaceNameDialog extends StatefulWidget {
  const _WorkspaceNameDialog();
  @override
  State<_WorkspaceNameDialog> createState() => _WorkspaceNameDialogState();
}

class _WorkspaceNameDialogState extends State<_WorkspaceNameDialog> {
  final controller = TextEditingController();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppDialog(
    title: '新建工作区',
    content: TextField(
      controller: controller,
      maxLength: 100,
      decoration: const InputDecoration(labelText: '名称'),
      onChanged: (_) => setState(() {}),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: controller.text.trim().isEmpty
            ? null
            : () => Navigator.pop(context, controller.text.trim()),
        child: const Text('创建'),
      ),
    ],
  );
}
