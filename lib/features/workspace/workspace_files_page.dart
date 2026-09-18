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
      title: path == '.' ? workspace.value?.name ?? '工作区文件' : path,
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
                    trailing: directory
                        ? const Icon(Symbols.chevron_right)
                        : IconButton(
                            tooltip: '导出文件',
                            icon: const Icon(Symbols.download),
                            onPressed: action.isLoading
                                ? null
                                : () => ref
                                      .read(workspaceActionsProvider.notifier)
                                      .exportFile(id, entry.$1),
                          ),
                    onTap: action.isLoading
                        ? null
                        : () async {
                            if (directory) {
                              context.push(
                                '/settings/workspaces/$id?path=${Uri.encodeQueryComponent(entry.$1)}',
                              );
                            } else {
                              final attachment = await ref
                                  .read(workspaceActionsProvider.notifier)
                                  .perform(
                                    () => ref
                                        .read(workspaceActionsProvider.notifier)
                                        .preview(id, entry.$1),
                                  );
                              if (attachment != null && context.mounted) {
                                await showToolArtifact(context, attachment);
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
