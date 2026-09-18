import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../core/error/failure.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../core/theme/frosted_surface.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_icon_badge.dart';
import '../../../data/models/conversation.dart';
import '../../../data/repositories/conversation_repository.dart';
import 'chat_controller.dart';
import 'conversation_export.dart';
import 'conversation_export_sheet.dart';

/// 可搜索的惰性会话列表；设置始终留在侧栏底部。
class ConversationDrawer extends ConsumerStatefulWidget {
  const ConversationDrawer({required this.width, super.key});

  final double width;

  @override
  ConsumerState<ConversationDrawer> createState() => _ConversationDrawerState();
}

class _ConversationDrawerState extends ConsumerState<ConversationDrawer> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final conversations = ref.watch(conversationsProvider);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    const radius = BorderRadius.horizontal(
      right: Radius.circular(AppRadius.extraLarge),
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
                  key: const ValueKey('conversation-drawer-scroll'),
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
                                  icon: Symbols.dark_mode,
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
                                  onPressed: () => Navigator.of(context).pop(),
                                  icon: const Icon(Symbols.close),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.m),
                            FilledButton.icon(
                              onPressed: () {
                                FocusScope.of(context).unfocus();
                                ref
                                    .read(chatControllerProvider.notifier)
                                    .startNewConversation();
                                Navigator.of(context).pop();
                              },
                              icon: const Icon(Symbols.add),
                              label: const Text('新会话'),
                            ),
                            const SizedBox(height: AppSpacing.l),
                            TextField(
                              key: const ValueKey('conversation-search'),
                              controller: _searchController,
                              textInputAction: TextInputAction.search,
                              decoration: InputDecoration(
                                hintText: '搜索会话',
                                prefixIcon: const Icon(Symbols.search),
                                suffixIcon: _query.isEmpty
                                    ? null
                                    : IconButton(
                                        tooltip: '清除搜索',
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() => _query = '');
                                        },
                                        icon: const Icon(Symbols.close),
                                      ),
                              ),
                              onChanged: (value) => setState(
                                () => _query = value.trim().toLowerCase(),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xl),
                            Text(
                              _query.isEmpty ? '最近会话' : '搜索结果',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    conversations.when(
                      data: (items) {
                        final filtered = [
                          for (final item in items)
                            if (item.title.toLowerCase().contains(_query)) item,
                        ];
                        if (filtered.isEmpty) {
                          return SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.xl),
                              child: Text(
                                _query.isEmpty ? '暂无会话' : '没有匹配的会话',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colors.onSurfaceVariant,
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
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.s,
                            0,
                            AppSpacing.s,
                            AppSpacing.l,
                          ),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => Padding(
                                key: ValueKey(filtered[index].id),
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.xs,
                                ),
                                child: _ConversationTile(
                                  conversation: filtered[index],
                                  onDeleted: () {
                                    if (!mounted) return;
                                    if (ref
                                            .read(activeConversationProvider)
                                            .conversationId ==
                                        filtered[index].id) {
                                      ref
                                          .read(chatControllerProvider.notifier)
                                          .startNewConversation();
                                    }
                                  },
                                ),
                              ),
                              childCount: filtered.length,
                              findChildIndexCallback: (key) => indices[key],
                            ),
                          ),
                        );
                      },
                      loading: () => const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(AppSpacing.xl),
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
                                error is Failure
                                    ? error.userMessage
                                    : '加载会话列表失败，请重试',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colors.error,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.s),
                              TextButton(
                                onPressed: () =>
                                    ref.invalidate(conversationsProvider),
                                child: const Text('重试'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.s),
                child: InkWell(
                  borderRadius: AppRadius.mediumAll,
                  onTap: () {
                    // 侧栏保持打开，从设置返回后停留在原状。
                    FocusScope.of(context).unfocus();
                    GoRouter.of(context).push('/settings');
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.s),
                    child: Row(
                      children: [
                        const AppIconBadge(
                          icon: Symbols.settings,
                          size: 40,
                          iconSize: 22,
                        ),
                        const SizedBox(width: AppSpacing.m),
                        Expanded(
                          child: Text('设置', style: theme.textTheme.titleMedium),
                        ),
                        const Icon(Symbols.chevron_right),
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
}

class _ConversationTile extends ConsumerStatefulWidget {
  const _ConversationTile({
    required this.conversation,
    required this.onDeleted,
  });

  final Conversation conversation;
  final VoidCallback onDeleted;

  @override
  ConsumerState<_ConversationTile> createState() => _ConversationTileState();
}

class _ConversationTileState extends ConsumerState<_ConversationTile> {
  final _menuController = MenuController();
  final _menuFocus = FocusNode();
  AnimationStatus _menuAnimationStatus = AnimationStatus.dismissed;
  LocalHistoryEntry? _menuHistory;

  Conversation get conversation => widget.conversation;

  void _toggleMenu() => _menuAnimationStatus.isForwardOrCompleted
      ? _menuController.close()
      : _menuController.open();

  void _menuOpened() {
    final route = ModalRoute.of(context);
    if (route == null || _menuHistory != null) return;
    late final LocalHistoryEntry entry;
    entry = LocalHistoryEntry(
      impliesAppBarDismissal: false,
      onRemove: () {
        if (_menuHistory == entry) {
          _menuHistory = null;
          _menuController.close();
        }
      },
    );
    _menuHistory = entry;
    route.addLocalHistoryEntry(entry);
  }

  void _menuClosed() {
    final entry = _menuHistory;
    _menuHistory = null;
    entry?.remove();
  }

  @override
  void dispose() {
    _menuClosed();
    _menuFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(
      activeConversationProvider.select(
        (active) => active.conversationId == conversation.id,
      ),
    );
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final label = TextPainter(
      text: TextSpan(text: '取消置顶', style: theme.textTheme.bodyMedium),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final menuWidth = (label.width + 96)
        .clamp(176.0, MediaQuery.sizeOf(context).width - 32)
        .toDouble();
    label.dispose();
    return Semantics(
      selected: selected,
      child: Material(
        key: ValueKey('conversation-row-${conversation.id}'),
        color: selected
            ? colors.primaryContainer.withValues(alpha: 0.82)
            : colors.surface.withValues(alpha: 0),
        borderRadius: AppRadius.smallAll,
        child: InkWell(
          borderRadius: AppRadius.smallAll,
          onLongPress: _toggleMenu,
          onTap: () {
            FocusScope.of(context).unfocus();
            ref
                .read(chatControllerProvider.notifier)
                .openConversation(conversation.id);
            Navigator.of(context).pop();
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.m,
              AppSpacing.xs,
              AppSpacing.xs,
              AppSpacing.xs,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        conversation.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: selected
                              ? colors.onPrimaryContainer
                              : colors.onSurface,
                        ),
                      ),
                      Row(
                        children: [
                          if (conversation.pinned) ...[
                            Icon(
                              Symbols.push_pin,
                              size: 14,
                              color: context.brandColors.gold,
                              semanticLabel: '已置顶',
                            ),
                            const SizedBox(width: AppSpacing.xs),
                          ],
                          Expanded(
                            child: Text(
                              _relativeTime(conversation.updatedAt),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: selected
                                    ? colors.onPrimaryContainer
                                    : colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                MenuAnchor(
                  controller: _menuController,
                  childFocusNode: _menuFocus,
                  animated: !AppMotion.reduce(context),
                  onAnimationStatusChanged: (status) =>
                      _menuAnimationStatus = status,
                  onOpen: _menuOpened,
                  onClose: _menuClosed,
                  consumeOutsideTap: true,
                  alignmentOffset: Offset(-menuWidth, AppSpacing.xs),
                  style: MenuStyle(
                    alignment: AlignmentDirectional.bottomEnd,
                    minimumSize: WidgetStatePropertyAll(Size(menuWidth, 0)),
                    maximumSize: WidgetStatePropertyAll(
                      Size(menuWidth, double.infinity),
                    ),
                  ),
                  menuChildren: [
                    MenuItemButton(
                      leadingIcon: const Icon(Symbols.edit),
                      onPressed: () => _rename(context, ref),
                      child: const Text('重命名'),
                    ),
                    MenuItemButton(
                      key: ValueKey(
                        'duplicate-conversation-${conversation.id}',
                      ),
                      leadingIcon: const Icon(Symbols.content_copy),
                      onPressed: () =>
                          _duplicate(context, ref, conversation.id),
                      child: const Text('复制会话'),
                    ),
                    MenuItemButton(
                      key: ValueKey('export-conversation-${conversation.id}'),
                      leadingIcon: const Icon(Symbols.download),
                      onPressed: () => _export(context, ref),
                      child: const Text('导出会话'),
                    ),
                    MenuItemButton(
                      key: ValueKey('tool-records-${conversation.id}'),
                      leadingIcon: const Icon(Symbols.history),
                      onPressed: () => context.push(
                        '/conversations/${conversation.id}/tools',
                      ),
                      child: const Text('执行记录'),
                    ),
                    MenuItemButton(
                      leadingIcon: const Icon(Symbols.push_pin),
                      onPressed: () => _runGuarded(context, () async {
                        final repository = await ref.read(
                          conversationRepositoryProvider.future,
                        );
                        await repository.setPinned(
                          conversation.id,
                          pinned: !conversation.pinned,
                        );
                      }),
                      child: Text(conversation.pinned ? '取消置顶' : '置顶'),
                    ),
                    MenuItemButton(
                      leadingIcon: Icon(Symbols.delete, color: colors.error),
                      onPressed: () => _confirmDelete(context, ref),
                      child: Text('删除', style: TextStyle(color: colors.error)),
                    ),
                  ],
                  builder: (context, controller, child) => IconButton(
                    focusNode: _menuFocus,
                    key: ValueKey('conversation-menu-${conversation.id}'),
                    tooltip: '会话菜单',
                    onPressed: _toggleMenu,
                    icon: const Icon(Symbols.more_horiz),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    final newTitle = await showDialog<String>(
      context: context,
      builder: (context) =>
          _RenameConversationDialog(title: conversation.title),
    );
    if (newTitle == null || !context.mounted) return;
    await _runGuarded(context, () async {
      final repository = await ref.read(conversationRepositoryProvider.future);
      await repository.renameConversation(conversation.id, newTitle);
    });
  }

  /// 复制会话并切到副本（副本立刻可用，原会话不受影响）。
  Future<void> _duplicate(
    BuildContext context,
    WidgetRef ref,
    String conversationId,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(chatControllerProvider.notifier)
          .duplicateFrom(conversationId);
      if (!context.mounted) return;
      Navigator.of(context).maybePop();
      messenger.showSnackBar(const SnackBar(content: Text('已复制会话')));
    } on Failure catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.userMessage)));
    }
  }

  /// 导出会话：选格式 → 写入应用私有导出目录 → 提示文件路径。
  ///
  /// 首版不接系统分享（S5 再做）；导出成功后收起侧栏，路径提示才可见。
  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final format = await showConversationExportSheet(context);
    if (format == null || !context.mounted) return;
    // 收起侧栏前取好导出器：之后只用拿到的对象，不再用 ref 与 context。
    final ConversationExporter exporter;
    try {
      exporter = await ref.read(conversationExporterProvider.future);
    } on Failure catch (error) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.userMessage)));
      return;
    }
    if (!context.mounted) return;
    navigator.maybePop();
    try {
      final result = await exporter.export(conversation.id, format);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('已导出 ${result.formatLabel}：${result.path}')),
        );
    } on Failure catch (error) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.userMessage)));
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final colors = Theme.of(context).colorScheme;
        return AppDialog(
          title: '删除会话',
          description: '该会话的所有消息将一并删除，此操作无法撤销。',
          content: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Symbols.delete, color: colors.error),
              const SizedBox(width: AppSpacing.m),
              Expanded(child: Text('确定删除「${conversation.title}」吗？')),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colors.error,
                foregroundColor: colors.onError,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !context.mounted) return;
    final deleted = await _runGuarded(context, () async {
      final repository = await ref.read(conversationRepositoryProvider.future);
      await repository.deleteConversation(conversation.id);
    });
    if (deleted) widget.onDeleted();
  }

  Future<bool> _runGuarded(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      return true;
    } catch (error) {
      if (messenger.mounted) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                error is Failure ? error.userMessage : '会话操作失败，请稍后重试',
              ),
            ),
          );
      }
      return false;
    }
  }

  static String _relativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes} 分钟前';
    if (diff.inDays < 1) return '${diff.inHours} 小时前';
    if (diff.inDays < 7) return '${diff.inDays} 天前';
    return '${time.month}月${time.day}日';
  }
}

class _RenameConversationDialog extends StatefulWidget {
  const _RenameConversationDialog({required this.title});

  final String title;

  @override
  State<_RenameConversationDialog> createState() =>
      _RenameConversationDialogState();
}

class _RenameConversationDialogState extends State<_RenameConversationDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.title);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final title = _controller.text.trim();
    if (title.isEmpty) {
      setState(() => _error = '请输入会话名称');
      return;
    }
    Navigator.of(context).pop(title);
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: '重命名会话',
      icon: Symbols.edit,
      content: TextField(
        key: const ValueKey('conversation-name-input'),
        controller: _controller,
        autofocus: true,
        maxLength: 50,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          labelText: '会话名称',
          counterText: '',
          errorText: _error,
        ),
        onSubmitted: (_) => _save(),
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _save, child: const Text('保存')),
      ],
    );
  }
}
