import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/error/failure.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_list_tile.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../data/models/workspace.dart';
import '../chat/tool_artifact_viewer.dart';
import '../projects/project_providers.dart';
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
    final showProjectMaterials =
        path == '.' && workspace.value?.kind == WorkspaceKind.project;
    ref.listen(workspaceActionsProvider, (_, next) {
      if (next.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          buildAppSnackBar(
            content: Text(
              next.error is Failure
                  ? (next.error as Failure).userMessage
                  : '文件操作失败',
            ),
          ),
        );
      }
    });
    final page = AppScaffold(
      title: path == '.' ? workspace.value?.name ?? '工作区文件' : path,
      appBarBottom: showProjectMaterials
          ? const TabBar(
              tabs: [
                Tab(text: '目录'),
                Tab(text: '资料'),
              ],
            )
          : null,
      actions: [
        IconButton(
          tooltip: '刷新',
          onPressed: () {
            ref.invalidate(workspaceEntriesProvider(id, path));
            if (showProjectMaterials) {
              ref.invalidate(projectAttachmentsProvider(id));
            }
          },
          icon: const Icon(LucideIcons.rotateCw),
        ),
        IconButton(
          tooltip: '导入文件',
          onPressed: action.isLoading
              ? null
              : () =>
                    ref.read(workspaceActionsProvider.notifier).importFile(id),
          icon: const Icon(LucideIcons.fileUp),
        ),
      ],
      body: showProjectMaterials
          ? TabBarView(
              children: [
                _directory(context, ref, action, entries),
                _ProjectMaterials(workspaceId: id),
              ],
            )
          : _directory(context, ref, action, entries),
    );
    return showProjectMaterials
        ? DefaultTabController(length: 2, child: page)
        : page;
  }

  Widget _directory(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<void> action,
    AsyncValue<List<(String, int)>> entries,
  ) => entries.when(
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
                  directory ? LucideIcons.folder : LucideIcons.fileText,
                ),
                trailing: directory
                    ? null
                    : IconButton(
                        tooltip: '导出文件',
                        onPressed: action.isLoading
                            ? null
                            : () => ref
                                  .read(workspaceActionsProvider.notifier)
                                  .exportFile(id, entry.$1),
                        icon: const Icon(LucideIcons.fileDown),
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
                          if (attachment != null && context.mounted) {
                            await showToolArtifact(context, attachment);
                          }
                        }
                      },
              );
            },
          ),
  );
}

class _ProjectMaterials extends ConsumerWidget {
  const _ProjectMaterials({required this.workspaceId});

  final String workspaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attachments = ref.watch(projectAttachmentsProvider(workspaceId));
    final busy = ref.watch(workspaceActionsProvider).isLoading;
    return attachments.when(
      loading: () => const Center(child: AppLoadingIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.l),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(error is Failure ? error.userMessage : '无法读取项目资料'),
              TextButton(
                onPressed: () =>
                    ref.invalidate(projectAttachmentsProvider(workspaceId)),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      ),
      data: (items) => items.isEmpty
          ? const Center(child: Text('还没有项目资料'))
          : ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.l),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final attachment = items[index];
                return AppListTile(
                  key: ValueKey(attachment.id),
                  title: Text(attachment.name),
                  subtitle: Text(
                    '${(attachment.size / 1024).toStringAsFixed(1)} KiB',
                  ),
                  leading: Icon(
                    attachment.isImage
                        ? LucideIcons.image
                        : LucideIcons.fileText,
                  ),
                  trailing: IconButton(
                    tooltip: '导出文件',
                    onPressed: busy
                        ? null
                        : () => ref
                              .read(workspaceActionsProvider.notifier)
                              .exportProjectAttachment(
                                workspaceId,
                                attachment.id,
                              ),
                    icon: const Icon(LucideIcons.fileDown),
                  ),
                  onTap: busy
                      ? null
                      : () => showToolArtifact(context, attachment),
                );
              },
            ),
    );
  }
}
