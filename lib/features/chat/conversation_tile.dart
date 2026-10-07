import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/error/failure.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_icon_badge.dart';
import '../../../core/widgets/app_interactive_surface.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../../core/widgets/app_menu_anchor.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../data/models/conversation.dart';
import '../../../data/repositories/conversation_repository.dart';
import 'chat_controller.dart';
import 'conversation_export.dart';
import 'conversation_export_sheet.dart';

class ConversationTile extends ConsumerStatefulWidget {
  const ConversationTile({
    required this.conversation,
    required this.onOpen,
    this.onDeleted,
    this.onDuplicated,
    this.onClose,
    super.key,
  });

  final Conversation conversation;
  final VoidCallback onOpen;
  final VoidCallback? onDeleted;
  final ValueChanged<String>? onDuplicated;
  final VoidCallback? onClose;

  @override
  ConsumerState<ConversationTile> createState() => _ConversationTileState();
}

class _ConversationTileState extends ConsumerState<ConversationTile> {
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
    final isRunning = ref.watch(
      chatControllerProvider.select(
        (state) => state.isConversationRunning(conversation.id),
      ),
    );
    final isCompleted = ref.watch(
      chatControllerProvider.select(
        (state) => state.isConversationCompleted(conversation.id),
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
    final semanticStatus = isRunning
        ? '运行中'
        : isCompleted
        ? '已完成'
        : null;
    return Semantics(
      selected: selected,
      value: semanticStatus,
      child: AppInteractiveSurface(
        key: ValueKey('conversation-row-${conversation.id}'),
        selected: selected,
        color: selected
            ? colors.primaryContainer.withValues(alpha: 0.82)
            : colors.surface.withValues(alpha: 0),
        onLongPress: _toggleMenu,
        onTap: () {
          FocusScope.of(context).unfocus();
          widget.onOpen();
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            conversation.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: selected
                                  ? colors.onPrimaryContainer
                                  : colors.onSurface,
                            ),
                          ),
                        ),
                        if (isCompleted) ...[
                          const SizedBox(width: AppSpacing.xs),
                          Tooltip(
                            message: '已完成',
                            child: Icon(
                              LucideIcons.circleCheck,
                              key: ValueKey(
                                'conversation-completed-${conversation.id}',
                              ),
                              size: 14,
                              color: selected
                                  ? colors.onPrimaryContainer
                                  : context.brandColors.teal,
                              semanticLabel: '已完成',
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (conversation.pinned) ...[
                          Icon(
                            LucideIcons.pin,
                            size: 14,
                            color: context.brandColors.gold,
                            semanticLabel: '已置顶',
                          ),
                          const SizedBox(width: AppSpacing.xs),
                        ],
                        if (isRunning) ...[
                          Tooltip(
                            message: '运行中',
                            child: AppLoadingIndicator.small(
                              size: 14,
                              color: selected
                                  ? colors.onPrimaryContainer
                                  : colors.primary,
                              semanticsLabel: '运行中',
                            ),
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
              AppMenuAnchor(
                controller: _menuController,
                childFocusNode: _menuFocus,
                onAnimationStatusChanged: (status) =>
                    _menuAnimationStatus = status,
                onOpen: _menuOpened,
                onClose: _menuClosed,
                alignmentOffset: Offset(-menuWidth, AppSpacing.xs),
                style: MenuStyle(
                  alignment: AlignmentDirectional.bottomEnd,
                  minimumSize: WidgetStatePropertyAll(Size(menuWidth, 0)),
                  maximumSize: WidgetStatePropertyAll(
                    Size(menuWidth, double.infinity),
                  ),
                ),
                menuChildren: [
                  if (isRunning)
                    AppMenuItemButton(
                      key: ValueKey('stop-conversation-${conversation.id}'),
                      leadingIcon: const Icon(LucideIcons.square),
                      onPressed: () => ref
                          .read(chatControllerProvider.notifier)
                          .stopConversation(conversation.id),
                      child: const Text('停止运行'),
                    ),
                  AppMenuItemButton(
                    leadingIcon: const Icon(LucideIcons.pencil),
                    onPressed: () => _rename(context, ref),
                    child: const Text('重命名'),
                  ),
                  AppMenuItemButton(
                    key: ValueKey('duplicate-conversation-${conversation.id}'),
                    leadingIcon: const Icon(LucideIcons.copy),
                    onPressed: () => _duplicate(context, ref, conversation.id),
                    child: const Text('复制会话'),
                  ),
                  AppMenuItemButton(
                    key: ValueKey('export-conversation-${conversation.id}'),
                    leadingIcon: const Icon(LucideIcons.download),
                    onPressed: () => _export(context, ref),
                    child: const Text('导出会话'),
                  ),
                  AppMenuItemButton(
                    key: ValueKey('tool-records-${conversation.id}'),
                    leadingIcon: const Icon(LucideIcons.history),
                    onPressed: () =>
                        context.push('/conversations/${conversation.id}/tools'),
                    child: const Text('执行记录'),
                  ),
                  AppMenuItemButton(
                    leadingIcon: const Icon(LucideIcons.pin),
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
                  AppMenuItemButton(
                    style: MenuItemButton.styleFrom(
                      foregroundColor: colors.error,
                      iconColor: colors.error,
                    ),
                    leadingIcon: const Icon(LucideIcons.trash2),
                    onPressed: () => _confirmDelete(context, ref),
                    child: const Text('删除'),
                  ),
                ],
                builder: (context, controller, child) => IconButton(
                  focusNode: _menuFocus,
                  key: ValueKey('conversation-menu-${conversation.id}'),
                  tooltip: '会话菜单',
                  onPressed: _toggleMenu,
                  icon: const Icon(LucideIcons.ellipsis),
                ),
              ),
            ],
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
      final id = await ref
          .read(chatControllerProvider.notifier)
          .duplicateFrom(conversationId, open: conversation.projectId == null);
      if (!context.mounted) return;
      widget.onClose?.call();
      widget.onDuplicated?.call(id);
      messenger.showSnackBar(buildAppSnackBar(content: const Text('已复制会话')));
    } on Failure catch (error) {
      messenger.showSnackBar(
        buildAppSnackBar(content: Text(error.userMessage)),
      );
    }
  }

  /// 导出会话：选格式 → 写入应用私有导出目录 → 提示文件路径。
  ///
  /// 首版不接系统分享（S5 再做）；导出成功后收起侧栏，路径提示才可见。
  Future<void> _export(BuildContext context, WidgetRef ref) async {
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
        ..showSnackBar(buildAppSnackBar(content: Text(error.userMessage)));
      return;
    }
    if (!context.mounted) return;
    widget.onClose?.call();
    try {
      final result = await exporter.export(conversation.id, format);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          buildAppSnackBar(
            content: Text('已导出 ${result.formatLabel}：${result.path}'),
          ),
        );
    } on Failure catch (error) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(buildAppSnackBar(content: Text(error.userMessage)));
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final colors = Theme.of(context).colorScheme;
        return AppDialog(
          title: '删除会话',
          description: conversation.projectId == null
              ? '该会话的所有消息、附件、工作区文件与产物将一并删除，此操作无法撤销。'
              : '仅删除此会话的历史和运行记录，项目文件、附件和产物都会保留。此操作无法撤销。',
          icon: LucideIcons.trash2,
          tone: AppTone.error,
          content: Text('确定删除「${conversation.title}」吗？'),
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
      await ref
          .read(chatControllerProvider.notifier)
          .deleteConversation(conversation.id);
    });
    if (deleted) widget.onDeleted?.call();
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
            buildAppSnackBar(
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
      icon: LucideIcons.pencil,
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
