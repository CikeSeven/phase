import '../../../data/models/workspace.dart';
import '../../../core/widgets/app_dialog.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/error/failure.dart';
import '../../../core/widgets/app_list_tile.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../chat/tool_artifact_viewer.dart';
import 'workspace_actions.dart';

class WorkspaceFilesPage extends ConsumerWidget {
  const WorkspaceFilesPage({super.key, required this.id, this.path = '.'});
  final String id;
  final String path;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final action = ref.watch(workspaceActionsProvider);
    final entries = ref.watch(workspaceEntriesProvider(id, path));
    final workspace = ref.watch(workspaceProvider(id));
    ref.listen(workspaceActionsProvider, (_, next) {
      if (next.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              next.error is Failure
                  ? (next.error as Failure).userMessage
                  : '文件操作失败',
            ),
          ),
        );
      }
    });
    return AppScaffold(
      title:
          '${workspace.value?.primaryEnvironment.label ?? ''} · ${path == '.' ? workspace.value?.name ?? '工作区文件' : path}',
      actions: [
        IconButton(
          tooltip: '刷新',
          onPressed: () => ref.invalidate(workspaceEntriesProvider(id, path)),
          icon: const Icon(Symbols.refresh),
        ),
        IconButton(
          tooltip: '导入文件',
          onPressed: action.isLoading
              ? null
              : () =>
                    ref.read(workspaceActionsProvider.notifier).importFile(id),
          icon: const Icon(Symbols.upload_file),
        ),
      ],
      body: entries.when(
        loading: () => const Center(child: AppLoadingIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(error is Failure ? error.userMessage : '无法读取工作区文件'),
          ),
        ),
        data: (values) => values.isEmpty
            ? const Center(child: Text('此目录还没有文件'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: values.length,
                itemBuilder: (context, index) {
                  final entry = values[index];
                  final directory = entry.$2 < 0;
                  return AppListTile(
                    title: Text(entry.$1.split('/').last),
                    subtitle: directory
                        ? null
                        : Text('${(entry.$2 / 1024).toStringAsFixed(1)} KiB'),
                    leading: Icon(
                      directory ? Symbols.folder : Symbols.description,
                    ),
                    trailing: PopupMenuButton<String>(
                      enabled: !action.isLoading,
                      itemBuilder: (context) => [
                        if (!directory)
                          const PopupMenuItem(
                            value: 'export',
                            child: Text('导出文件'),
                          ),
                        PopupMenuItem(
                          value: 'copy',
                          child: Text(
                            '复制到 ${workspace.value?.primaryEnvironment.other.label ?? '另一环境'}',
                          ),
                        ),
                      ],
                      onSelected: (value) async {
                        final actions = ref.read(
                          workspaceActionsProvider.notifier,
                        );
                        if (value == 'export') {
                          await actions.exportFile(id, entry.$1);
                          return;
                        }
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AppDialog(
                            title:
                                '复制到 ${workspace.value?.primaryEnvironment.other.label ?? '另一环境'}？',
                            content: Text(
                              '${entry.$1}\n同名文件将覆盖，目录合并，目标额外文件保留。',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('取消'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('复制'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          await actions.copyToOther(id, entry.$1);
                        }
                      },
                    ),
                    onTap: action.isLoading
                        ? null
                        : () async {
                            if (directory) {
                              context.push(
                                '/settings/workspaces/$id?path=${Uri.encodeQueryComponent(entry.$1)}',
                              );
                            } else {
                              final actions = ref.read(
                                workspaceActionsProvider.notifier,
                              );
                              final attachment = await actions.perform(
                                () => actions.preview(id, entry.$1),
                              );
                              if (attachment != null) {
                                try {
                                  if (context.mounted) {
                                    await showToolArtifact(context, attachment);
                                  }
                                } finally {
                                  await actions.releasePreview(attachment);
                                }
                              }
                            }
                          },
                  );
                },
              ),
      ),
    );
  }
}
