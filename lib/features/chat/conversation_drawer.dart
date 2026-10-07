import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/error/failure.dart';
import '../../../core/theme/app_control_style.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/frosted_surface.dart';
import '../../../core/widgets/app_icon_badge.dart';
import '../../../core/widgets/app_interactive_surface.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../data/models/conversation.dart';
import '../../../data/models/project.dart';
import '../projects/create_project_dialog.dart';
import '../projects/project_providers.dart';
import 'chat_controller.dart';
import 'conversation_tile.dart';
import 'sidebar_mode.dart';

/// 列表模式独立于当前聊天；切换保留两份搜索与滚动位置。
class ConversationDrawer extends ConsumerStatefulWidget {
  const ConversationDrawer({
    required this.width,
    this.onNewConversation,
    this.onOpenConversation,
    this.onOpenProject,
    this.onDuplicatedConversation,
    super.key,
  });

  final double width;
  final VoidCallback? onNewConversation;
  final ValueChanged<Conversation>? onOpenConversation;
  final ValueChanged<String>? onOpenProject;
  final ValueChanged<String>? onDuplicatedConversation;

  @override
  ConsumerState<ConversationDrawer> createState() => _ConversationDrawerState();
}

class _ConversationDrawerState extends ConsumerState<ConversationDrawer>
    with SingleTickerProviderStateMixin {
  final _chatSearch = TextEditingController();
  final _projectSearch = TextEditingController();
  final _chatScroll = ScrollController();
  final _projectScroll = ScrollController();
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: SidebarMode.values.length,
      vsync: this,
      initialIndex: ref.read(sidebarModeControllerProvider).index,
    );
    ref.listenManual(sidebarModeControllerProvider, (_, next) {
      if (_tabs.index != next.index) _tabs.animateTo(next.index);
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _chatSearch.dispose();
    _projectSearch.dispose();
    _chatScroll.dispose();
    _projectScroll.dispose();
    super.dispose();
  }

  void _close() {
    FocusScope.of(context).unfocus();
    Scaffold.of(context).closeDrawer();
  }

  void _openProject(String id) {
    _close();
    final open = widget.onOpenProject;
    if (open != null) {
      open(id);
    } else {
      context.push('/projects/$id');
    }
  }

  Future<void> _createProject() async {
    final project = await showCreateProjectDialog(context);
    if (!mounted || project == null) return;
    _openProject(project.id);
  }

  Future<void> _openConversation(Conversation conversation) async {
    _close();
    final open = widget.onOpenConversation;
    if (open != null) {
      open(conversation);
      return;
    }
    try {
      await ref
          .read(chatControllerProvider.notifier)
          .openConversation(conversation.id);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        buildAppSnackBar(
          content: Text(error is Failure ? error.userMessage : '打开会话失败，请重试'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(sidebarModeControllerProvider);
    final isChat = mode == SidebarMode.chat;
    final search = isChat ? _chatSearch : _projectSearch;
    final query = search.text.trim().toLowerCase();
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    const radius = BorderRadius.horizontal(
      right: Radius.circular(AppRadius.extraLarge),
    );
    final list = isChat
        ? _items<Conversation>(
            entries: ref.watch(standaloneConversationsProvider),
            query: query,
            noun: '会话',
            id: (item) => item.id,
            title: (item) => item.title,
            retry: () => ref.invalidate(standaloneConversationsProvider),
            builder: (item) => ConversationTile(
              conversation: item,
              onOpen: () => _openConversation(item),
              onClose: _close,
              onDuplicated: widget.onDuplicatedConversation,
            ),
          )
        : _items<Project>(
            entries: ref.watch(projectsProvider),
            query: query,
            noun: '项目',
            id: (item) => item.id,
            title: (item) => item.name,
            retry: () => ref.invalidate(projectsProvider),
            builder: (item) => _ProjectTile(
              project: item,
              onOpen: () => _openProject(item.id),
            ),
          );

    return Drawer(
      width: widget.width,
      elevation: 0,
      backgroundColor: colors.surface.withValues(alpha: 0),
      surfaceTintColor: colors.surfaceTint.withValues(alpha: 0),
      shape: const RoundedRectangleBorder(borderRadius: radius),
      child: FrostedSurface(
        borderRadius: radius,
        color: colors.surfaceContainerLow.withValues(
          alpha: theme.brightness == Brightness.dark ? 0.94 : 0.88,
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: CustomScrollView(
                  key: ValueKey(
                    isChat
                        ? 'conversation-drawer-scroll'
                        : 'project-drawer-scroll',
                  ),
                  controller: isChat ? _chatScroll : _projectScroll,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.l),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                const AppIconBadge(
                                  icon: LucideIcons.moon,
                                  tone: AppTone.gold,
                                  size: 40,
                                  iconSize: 22,
                                ),
                                const SizedBox(width: AppSpacing.m),
                                Expanded(
                                  child: Text(
                                    '相月',
                                    style: theme.textTheme.titleLarge,
                                  ),
                                ),
                                IconButton(
                                  tooltip: '关闭侧栏',
                                  onPressed: _close,
                                  icon: const Icon(LucideIcons.x),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.m),
                            TabBar(
                              key: const ValueKey('sidebar-mode-tabs'),
                              controller: _tabs,
                              indicatorSize: TabBarIndicatorSize.tab,
                              onTap: (index) => ref
                                  .read(sidebarModeControllerProvider.notifier)
                                  .select(SidebarMode.values[index]),
                              tabs: const [
                                Tab(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(LucideIcons.messageSquare, size: 20),
                                      SizedBox(width: AppSpacing.s),
                                      Text('聊天'),
                                    ],
                                  ),
                                ),
                                Tab(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(LucideIcons.folder, size: 20),
                                      SizedBox(width: AppSpacing.s),
                                      Text('项目'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.m),
                            FilledButton.icon(
                              style: AppControlStyle.compact,
                              onPressed: isChat
                                  ? () {
                                      ref
                                          .read(chatControllerProvider.notifier)
                                          .startNewConversation();
                                      _close();
                                      widget.onNewConversation?.call();
                                    }
                                  : _createProject,
                              icon: const Icon(LucideIcons.plus),
                              label: Text(isChat ? '新会话' : '新建项目'),
                            ),
                            const SizedBox(height: AppSpacing.l),
                            TextField(
                              key: ValueKey(
                                isChat
                                    ? 'conversation-search'
                                    : 'project-search',
                              ),
                              controller: search,
                              textInputAction: TextInputAction.search,
                              decoration: InputDecoration(
                                hintText: isChat ? '搜索会话' : '搜索项目',
                                prefixIcon: const Icon(LucideIcons.search),
                                suffixIcon: query.isEmpty
                                    ? null
                                    : IconButton(
                                        tooltip: '清除搜索',
                                        onPressed: () => setState(search.clear),
                                        icon: const Icon(LucideIcons.x),
                                      ),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: AppSpacing.xl),
                            Text(
                              query.isNotEmpty
                                  ? '搜索结果'
                                  : isChat
                                  ? '最近会话'
                                  : '项目',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    list,
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s,
                  vertical: AppSpacing.xs,
                ),
                child: AppInteractiveSurface(
                  onTap: () {
                    FocusScope.of(context).unfocus();
                    context.push('/settings');
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s,
                      vertical: AppSpacing.xs,
                    ),
                    child: Row(
                      children: [
                        const AppIconBadge(
                          icon: LucideIcons.settings,
                          size: 40,
                          iconSize: 22,
                        ),
                        const SizedBox(width: AppSpacing.m),
                        Expanded(
                          child: Text('设置', style: theme.textTheme.titleMedium),
                        ),
                        const Icon(LucideIcons.chevronRight),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _items<T>({
    required AsyncValue<List<T>> entries,
    required String query,
    required String noun,
    required String Function(T item) id,
    required String Function(T item) title,
    required VoidCallback retry,
    required Widget Function(T item) builder,
  }) => entries.when(
    data: (items) {
      final filtered = [
        for (final item in items)
          if (title(item).toLowerCase().contains(query)) item,
      ];
      if (filtered.isEmpty) {
        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Text(
              query.isEmpty ? '暂无$noun' : '没有匹配的$noun',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        );
      }
      final indices = {
        for (var index = 0; index < filtered.length; index++)
          ValueKey(id(filtered[index])): index,
      };
      return SliverPadding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s,
          0,
          AppSpacing.s,
          AppSpacing.l,
        ),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => Padding(
              key: ValueKey(id(filtered[index])),
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: builder(filtered[index]),
            ),
            childCount: filtered.length,
            findChildIndexCallback: (key) => indices[key],
          ),
        ),
      );
    },
    loading: () => SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Text('正在读取$noun…'),
      ),
    ),
    error: (error, _) => SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              error is Failure ? error.userMessage : '加载$noun列表失败，请重试',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: AppSpacing.s),
            TextButton(onPressed: retry, child: const Text('重试')),
          ],
        ),
      ),
    ),
  );
}

class _ProjectTile extends StatelessWidget {
  const _ProjectTile({required this.project, required this.onOpen});

  final Project project;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = project.createdAt;
    return AppInteractiveSurface(
      key: ValueKey('project-row-${project.id}'),
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.m,
          vertical: AppSpacing.s,
        ),
        child: Row(
          children: [
            const AppIconBadge(
              icon: LucideIcons.folderKanban,
              tone: AppTone.primary,
              size: 40,
              iconSize: 20,
            ),
            const SizedBox(width: AppSpacing.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    project.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${date.year}年${date.month}月${date.day}日',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              LucideIcons.chevronRight,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
