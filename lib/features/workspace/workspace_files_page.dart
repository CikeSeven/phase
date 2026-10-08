import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path/path.dart' as p;

import '../../../core/error/failure.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../../core/widgets/app_menu_anchor.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../data/models/workspace.dart';
import '../chat/tool_artifact_viewer.dart';
import '../projects/project_path_display.dart';
import 'workspace_actions.dart';
import 'workspace_breadcrumbs.dart';
import 'workspace_file_tile.dart';

/// 文件排序模式枚举。
enum FileSortMode {
  nameAsc('按名称升序 (A → Z)', LucideIcons.arrowDownAZ),
  nameDesc('按名称降序 (Z → A)', LucideIcons.arrowUpAZ),
  sizeDesc('按大小降序 (大 → 小)', LucideIcons.arrowDownWideNarrow),
  sizeAsc('按大小升序 (小 → 大)', LucideIcons.arrowDownNarrowWide),
  type('按文件类型', LucideIcons.slidersHorizontal);

  const FileSortMode(this.label, this.icon);
  final String label;
  final IconData icon;
}

class WorkspaceFilesPage extends ConsumerStatefulWidget {
  const WorkspaceFilesPage({super.key, required this.id, this.path = '.'});

  final String id;
  final String path;

  @override
  ConsumerState<WorkspaceFilesPage> createState() => _WorkspaceFilesPageState();
}

class _WorkspaceFilesPageState extends ConsumerState<WorkspaceFilesPage> {
  final _searchController = TextEditingController();
  final _sortMenuController = MenuController();
  late String _currentPath;
  FileSortMode _sortMode = FileSortMode.nameAsc;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _currentPath = widget.path;
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void didUpdateWidget(WorkspaceFilesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.path != oldWidget.path) {
      _currentPath = widget.path;
      _searchController.clear();
    }
  }

  void _onSearchChanged() {
    final text = _searchController.text.trim();
    if (text != _searchQuery) {
      setState(() => _searchQuery = text);
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _goUp() {
    if (_currentPath == '.') return;
    final parent = p.posix.dirname(_currentPath);
    final target = (parent == '.' || parent.isEmpty) ? '.' : parent;
    setState(() {
      _currentPath = target;
      _searchController.clear();
    });
  }

  void _navigateTo(String targetPath) {
    if (targetPath == _currentPath) return;
    setState(() {
      _currentPath = targetPath;
      _searchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final action = ref.watch(workspaceActionsProvider);
    final entries = ref.watch(
      workspaceEntriesProvider(widget.id, _currentPath),
    );
    final workspace = ref.watch(workspaceProvider(widget.id));

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

    final currentFolderName = _currentPath == '.'
        ? (workspace.value?.name ?? '工作区文件')
        : _currentPath.split('/').last;

    final subtitle = _currentPath == '.'
        ? (workspace.value?.kind == WorkspaceKind.project ? '项目根目录' : '会话工作区')
        : formatProjectPath(_currentPath, projectId: widget.id);

    return PopScope(
      canPop: _currentPath == '.',
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _currentPath != '.') {
          _goUp();
        }
      },
      child: AppScaffold(
        title: currentFolderName,
        subtitle: subtitle,
        leading: IconButton(
          tooltip: _currentPath == '.' ? '返回' : '上一级',
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () {
            if (_currentPath != '.') {
              _goUp();
            } else {
              Navigator.of(context).maybePop();
            }
          },
        ),
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: () => ref.invalidate(
              workspaceEntriesProvider(widget.id, _currentPath),
            ),
            icon: const Icon(LucideIcons.rotateCw),
          ),
          IconButton(
            tooltip: '导入文件',
            onPressed: action.isLoading
                ? null
                : () => ref
                      .read(workspaceActionsProvider.notifier)
                      .importFile(widget.id),
            icon: const Icon(LucideIcons.fileUp),
          ),
        ],
        body: _buildDirectoryView(
          context,
          action,
          entries,
          workspace.value?.name ?? '根目录',
        ),
      ),
    );
  }

  Widget _buildDirectoryView(
    BuildContext context,
    AsyncValue<void> action,
    AsyncValue<List<(String, int)>> entries,
    String rootLabel,
  ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return entries.when(
      loading: () => const Center(child: AppLoadingIndicator()),
      error: (error, _) => Center(
        child: AppEmptyState(
          icon: LucideIcons.folderX,
          title: '无法读取工作区文件',
          message: error is Failure ? error.userMessage : '读取工作区文件失败，请重试',
          action: TextButton(
            onPressed: () => ref.invalidate(
              workspaceEntriesProvider(widget.id, _currentPath),
            ),
            child: const Text('重试'),
          ),
        ),
      ),
      data: (values) {
        final allDirectories = <(String, int)>[];
        final allFiles = <(String, int)>[];
        var totalBytes = 0;

        for (final entry in values) {
          if (entry.$2 < 0) {
            allDirectories.add(entry);
          } else {
            allFiles.add(entry);
            totalBytes += entry.$2;
          }
        }

        final query = _searchQuery.toLowerCase();
        final filteredDirs = query.isEmpty
            ? List.of(allDirectories)
            : allDirectories
                  .where(
                    (d) => d.$1.split('/').last.toLowerCase().contains(query),
                  )
                  .toList();

        final filteredFiles = query.isEmpty
            ? List.of(allFiles)
            : allFiles
                  .where(
                    (f) => f.$1.split('/').last.toLowerCase().contains(query),
                  )
                  .toList();

        // 文件夹在同类中排序。
        if (_sortMode == FileSortMode.nameDesc) {
          filteredDirs.sort(
            (a, b) => b.$1
                .split('/')
                .last
                .toLowerCase()
                .compareTo(a.$1.split('/').last.toLowerCase()),
          );
        } else {
          filteredDirs.sort(
            (a, b) => a.$1
                .split('/')
                .last
                .toLowerCase()
                .compareTo(b.$1.split('/').last.toLowerCase()),
          );
        }

        // 文件按选中模式排序。
        switch (_sortMode) {
          case FileSortMode.nameAsc:
            filteredFiles.sort(
              (a, b) => a.$1
                  .split('/')
                  .last
                  .toLowerCase()
                  .compareTo(b.$1.split('/').last.toLowerCase()),
            );
          case FileSortMode.nameDesc:
            filteredFiles.sort(
              (a, b) => b.$1
                  .split('/')
                  .last
                  .toLowerCase()
                  .compareTo(a.$1.split('/').last.toLowerCase()),
            );
          case FileSortMode.sizeDesc:
            filteredFiles.sort((a, b) {
              final cmp = b.$2.compareTo(a.$2);
              if (cmp != 0) return cmp;
              return a.$1
                  .split('/')
                  .last
                  .toLowerCase()
                  .compareTo(b.$1.split('/').last.toLowerCase());
            });
          case FileSortMode.sizeAsc:
            filteredFiles.sort((a, b) {
              final cmp = a.$2.compareTo(b.$2);
              if (cmp != 0) return cmp;
              return a.$1
                  .split('/')
                  .last
                  .toLowerCase()
                  .compareTo(b.$1.split('/').last.toLowerCase());
            });
          case FileSortMode.type:
            filteredFiles.sort((a, b) {
              final extA = p.extension(a.$1).toLowerCase();
              final extB = p.extension(b.$1).toLowerCase();
              final cmp = extA.compareTo(extB);
              if (cmp != 0) return cmp;
              return a.$1
                  .split('/')
                  .last
                  .toLowerCase()
                  .compareTo(b.$1.split('/').last.toLowerCase());
            });
        }

        final isEmptyDirectory = values.isEmpty;
        final hasNoSearchResults =
            !isEmptyDirectory && filteredDirs.isEmpty && filteredFiles.isEmpty;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.l,
                AppSpacing.s,
                AppSpacing.l,
                AppSpacing.xs,
              ),
              child: WorkspaceBreadcrumbs(
                currentPath: _currentPath,
                rootLabel: rootLabel,
                onNavigate: _navigateTo,
                onGoUp: _currentPath == '.' ? null : _goUp,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.l,
                vertical: AppSpacing.xs,
              ),
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                style: theme.textTheme.bodyMedium,
                decoration: InputDecoration(
                  hintText: '搜索此目录下的文件与文件夹…',
                  hintStyle: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                  prefixIcon: const Icon(LucideIcons.search, size: 18),
                  suffixIcon: _searchQuery.isEmpty
                      ? null
                      : IconButton(
                          tooltip: '清除搜索',
                          icon: const Icon(LucideIcons.x, size: 16),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.m,
                    vertical: AppSpacing.s,
                  ),
                  filled: true,
                  fillColor: colors.surfaceContainerHigh.withValues(alpha: 0.5),
                  border: const OutlineInputBorder(
                    borderRadius: AppRadius.mediumAll,
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.l,
                vertical: AppSpacing.xs,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: query.isNotEmpty
                        ? Text(
                            '找到 ${filteredDirs.length + filteredFiles.length} 项匹配',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: colors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        : Text(
                            allDirectories.isEmpty && allFiles.isEmpty
                                ? '空目录'
                                : '${allDirectories.isNotEmpty ? "${allDirectories.length} 个文件夹" : ""}'
                                      '${allDirectories.isNotEmpty && allFiles.isNotEmpty ? " · " : ""}'
                                      '${allFiles.isNotEmpty ? "${allFiles.length} 个文件 (${formatFileSize(totalBytes)})" : ""}',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                  ),
                  AppMenuAnchor(
                    controller: _sortMenuController,
                    style: const MenuStyle(
                      alignment: AlignmentDirectional.bottomEnd,
                      minimumSize: WidgetStatePropertyAll(Size(200, 0)),
                      maximumSize: WidgetStatePropertyAll(
                        Size(220, double.infinity),
                      ),
                    ),
                    menuChildren: [
                      for (final mode in FileSortMode.values)
                        AppMenuItemButton(
                          leadingIcon: Icon(mode.icon, size: 18),
                          trailingIcon: mode == _sortMode
                              ? Icon(
                                  LucideIcons.check,
                                  size: 16,
                                  color: colors.primary,
                                )
                              : null,
                          onPressed: () => setState(() => _sortMode = mode),
                          child: Text(mode.label),
                        ),
                    ],
                    builder: (context, controller, _) => IconButton(
                      tooltip: '排序方式: ${_sortMode.label}',
                      onPressed: controller.open,
                      icon: Icon(
                        _sortMode.icon,
                        size: 18,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: isEmptyDirectory
                  ? AppEmptyState(
                      icon: LucideIcons.folderOpen,
                      title: '目录为空',
                      message: '此目录中还没有任何文件或子目录。',
                      action: _currentPath == '.'
                          ? TextButton.icon(
                              onPressed: action.isLoading
                                  ? null
                                  : () => ref
                                        .read(workspaceActionsProvider.notifier)
                                        .importFile(widget.id),
                              icon: const Icon(LucideIcons.fileUp, size: 16),
                              label: const Text('导入文件'),
                            )
                          : TextButton.icon(
                              onPressed: _goUp,
                              icon: const Icon(LucideIcons.folderUp, size: 16),
                              label: const Text('返回上一级'),
                            ),
                    )
                  : hasNoSearchResults
                  ? AppEmptyState(
                      icon: LucideIcons.searchX,
                      title: '未找到匹配项',
                      message: '未找到名称包含「$_searchQuery」的文件或文件夹。',
                      action: TextButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                        child: const Text('清除搜索'),
                      ),
                    )
                  : ListView(
                      padding: EdgeInsets.fromLTRB(
                        AppSpacing.l,
                        AppSpacing.xs,
                        AppSpacing.l,
                        AppSpacing.l + MediaQuery.paddingOf(context).bottom,
                      ),
                      children: [
                        if (filteredDirs.isNotEmpty && filteredFiles.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(
                              left: AppSpacing.xs,
                              top: AppSpacing.xs,
                              bottom: AppSpacing.s,
                            ),
                            child: Text(
                              '文件夹 (${filteredDirs.length})',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: colors.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        for (final dir in filteredDirs)
                          Padding(
                            key: ValueKey('dir-${dir.$1}'),
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.xs,
                            ),
                            child: WorkspaceFileTile(
                              name: dir.$1.split('/').last,
                              path: dir.$1,
                              size: -1,
                              isDirectory: true,
                              isBusy: action.isLoading,
                              onTap: () => _navigateTo(dir.$1),
                            ),
                          ),
                        if (filteredDirs.isNotEmpty && filteredFiles.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(
                              left: AppSpacing.xs,
                              top: AppSpacing.m,
                              bottom: AppSpacing.s,
                            ),
                            child: Text(
                              '文件 (${filteredFiles.length})',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: colors.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        for (final file in filteredFiles)
                          Padding(
                            key: ValueKey('file-${file.$1}'),
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.xs,
                            ),
                            child: WorkspaceFileTile(
                              name: file.$1.split('/').last,
                              path: file.$1,
                              size: file.$2,
                              isDirectory: false,
                              isBusy: action.isLoading,
                              onTap: () async {
                                final actions = ref.read(
                                  workspaceActionsProvider.notifier,
                                );
                                final attachment = await actions.perform(
                                  () => actions.preview(widget.id, file.$1),
                                );
                                if (attachment != null && context.mounted) {
                                  await showToolArtifact(context, attachment);
                                }
                              },
                              onPreview: () async {
                                final actions = ref.read(
                                  workspaceActionsProvider.notifier,
                                );
                                final attachment = await actions.perform(
                                  () => actions.preview(widget.id, file.$1),
                                );
                                if (attachment != null && context.mounted) {
                                  await showToolArtifact(context, attachment);
                                }
                              },
                              onExport: () => ref
                                  .read(workspaceActionsProvider.notifier)
                                  .exportFile(widget.id, file.$1),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }
}
