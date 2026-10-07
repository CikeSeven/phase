import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/error/failure.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_icon_badge.dart';
import '../../core/widgets/app_list_tile.dart';
import '../../core/widgets/app_loading_indicator.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/app_section.dart';
import '../../core/widgets/app_snack_bar.dart';
import '../../data/models/conversation.dart';
import '../../data/models/project.dart';
import '../chat/conversation_tile.dart';
import '../workspace/workspace_actions.dart';
import 'project_navigation.dart';
import 'project_providers.dart';

class ProjectPage extends ConsumerStatefulWidget {
  const ProjectPage({required this.id, super.key});

  final String id;

  @override
  ConsumerState<ProjectPage> createState() => _ProjectPageState();
}

class _ProjectPageState extends ConsumerState<ProjectPage> {
  final _search = TextEditingController();
  bool _opening = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _openChat([String? conversationId]) async {
    if (_opening) return;
    FocusScope.of(context).unfocus();
    setState(() => _opening = true);
    try {
      await openProjectConversation(
        context,
        ref,
        widget.id,
        conversationId: conversationId,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        buildAppSnackBar(
          content: Text(error is Failure ? error.userMessage : '打开会话失败，请重试'),
        ),
      );
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(projectProvider(widget.id));
    final projectValue = project.value;

    return AppScaffold(
      title: projectValue?.name ?? '项目',
      subtitle: projectValue == null
          ? null
          : '创建于 ${projectValue.createdAt.year}年${projectValue.createdAt.month}月${projectValue.createdAt.day}日',
      actions: projectValue == null
          ? const []
          : [
              IconButton(
                tooltip: '新会话',
                onPressed: _opening ? null : () => _openChat(),
                icon: const Icon(LucideIcons.plus),
              ),
            ],
      body: project.when(
        loading: () => const Center(child: AppLoadingIndicator()),
        error: (error, _) => AppEmptyState(
          icon: LucideIcons.folder,
          title: '无法读取项目',
          message: error is Failure ? error.userMessage : '读取项目失败，请重试',
          action: TextButton(
            onPressed: () => ref.invalidate(projectProvider(widget.id)),
            child: const Text('重试'),
          ),
        ),
        data: (value) => value == null
            ? const AppEmptyState(
                icon: LucideIcons.folder,
                title: '项目已不存在',
                message: '请返回项目列表。',
              )
            : _content(value),
      ),
    );
  }

  Widget _content(Project project) {
    final conversations = ref.watch(projectConversationsProvider(project.id));
    final rootEntries = ref.watch(
      workspaceEntriesProvider(project.workspaceId, '.'),
    );
    final attachments = ref.watch(projectAttachmentsProvider(project.id));
    final theme = Theme.of(context);
    final date = project.createdAt;

    return CustomScrollView(
      key: PageStorageKey('project-${project.id}'),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(AppSpacing.l),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const AppIconBadge(
                            icon: LucideIcons.folderKanban,
                            tone: AppTone.primary,
                            size: 48,
                            iconSize: 24,
                          ),
                          const SizedBox(width: AppSpacing.m),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  project.name,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  '创建于 ${date.year}年${date.month}月${date.day}日',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.m),
                      Wrap(
                        spacing: AppSpacing.s,
                        runSpacing: AppSpacing.xs,
                        children: [
                          AppBadge(
                            label: '${conversations.value?.length ?? 0} 个会话',
                            tone: AppTone.primary,
                          ),
                          AppBadge(
                            label: '${rootEntries.value?.length ?? 0} 个文件项',
                            tone: AppTone.teal,
                          ),
                          AppBadge(
                            label: '${attachments.value?.length ?? 0} 份资料',
                            tone: AppTone.lavender,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.m),
                      AppListTile(
                        key: const ValueKey('project-files'),
                        title: const Text('项目文件'),
                        subtitle: const Text('项目根目录 · 浏览工作区文件与资料'),
                        leading: const Icon(LucideIcons.folderOpen),
                        trailing: const Icon(LucideIcons.chevronRight),
                        onTap: () => context.push(
                          '/settings/workspaces/${project.workspaceId}',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppSection(
                  title: '会话',
                  action: FilledButton.icon(
                    key: const ValueKey('new-project-conversation'),
                    onPressed: _opening ? null : () => _openChat(),
                    icon: const Icon(LucideIcons.plus),
                    label: const Text('新会话'),
                  ),
                  child: TextField(
                    key: const ValueKey('project-conversation-search'),
                    controller: _search,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: '搜索会话',
                      prefixIcon: const Icon(LucideIcons.search),
                      suffixIcon: _search.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: '清除搜索',
                              onPressed: () => setState(_search.clear),
                              icon: const Icon(LucideIcons.x),
                            ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
          ),
        ),
        _conversationList(conversations),
        SliverToBoxAdapter(
          child: SizedBox(
            height: AppSpacing.l + MediaQuery.paddingOf(context).bottom,
          ),
        ),
      ],
    );
  }

  Widget _conversationList(AsyncValue<List<Conversation>> conversations) =>
      conversations.when(
        loading: () => const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.l),
            child: Text('正在读取会话…'),
          ),
        ),
        error: (error, _) => SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  error is Failure ? error.userMessage : '读取会话失败，请重试',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: AppSpacing.s),
                TextButton(
                  onPressed: () =>
                      ref.invalidate(projectConversationsProvider(widget.id)),
                  child: const Text('重试'),
                ),
              ],
            ),
          ),
        ),
        data: (items) {
          final query = _search.text.trim().toLowerCase();
          final filtered = [
            for (final item in items)
              if (item.title.toLowerCase().contains(query)) item,
          ];
          if (filtered.isEmpty) {
            return SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.l),
                child: query.isEmpty
                    ? AppCard(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const AppIconBadge(
                                icon: LucideIcons.messageSquarePlus,
                                tone: AppTone.primary,
                                size: 56,
                                iconSize: 28,
                              ),
                              const SizedBox(height: AppSpacing.m),
                              Text(
                                '暂无会话',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                '在此项目中发起新会话，与模型探讨项目代码或资料。',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: AppSpacing.l),
                              FilledButton.icon(
                                onPressed: _opening ? null : () => _openChat(),
                                icon: const Icon(LucideIcons.plus),
                                label: const Text('发起新会话'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          child: Text(
                            '没有匹配的会话',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                        ),
                      ),
              ),
            );
          }
          final indices = {
            for (var index = 0; index < filtered.length; index++)
              ValueKey(filtered[index].id): index,
          };
          return SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final item = filtered[index];
                  return Padding(
                    key: ValueKey(item.id),
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: ConversationTile(
                      conversation: item,
                      onOpen: () => _openChat(item.id),
                      onDuplicated: (id) => _openChat(id),
                    ),
                  );
                },
                childCount: filtered.length,
                findChildIndexCallback: (key) => indices[key],
              ),
            ),
          );
        },
      );
}
