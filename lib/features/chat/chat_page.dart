import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../core/error/failure.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../data/models/conversation.dart';
import '../../../data/repositories/conversation_repository.dart';
import 'chat_controller.dart';
import 'chat_input_bar.dart';
import 'message_bubble.dart';

/// 聊天页（`/`）：抽屉会话列表 + 消息区 + 底部输入栏。
class ChatPage extends ConsumerWidget {
  const ChatPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatState = ref.watch(chatControllerProvider);
    final conversationId = chatState.conversationId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('相月'),
        actions: [
          IconButton(
            icon: const Icon(Symbols.settings),
            tooltip: '设置',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      drawer: const _ConversationDrawer(),
      body: Column(
        children: [
          Expanded(
            child: conversationId == null
                ? const _EmptyState()
                : _MessageList(conversationId: conversationId),
          ),
          const ChatInputBar(),
        ],
      ),
    );
  }
}

class _MessageList extends ConsumerWidget {
  const _MessageList({required this.conversationId});

  final String conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messagesAsync = ref.watch(chatMessagesProvider(conversationId));
    return messagesAsync.when(
      data: (messages) {
        if (messages.isEmpty) {
          return const _EmptyState();
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.m),
          itemCount: messages.length,
          itemBuilder: (context, index) =>
              MessageBubble(message: messages[index]),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _ErrorState(
        message: error is Failure ? error.userMessage : '加载消息失败',
      ),
    );
  }
}

/// DESIGN.md §5.5 空状态：48dp 图标 + 引导文案 + 主操作。
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Symbols.forum, size: 48, color: colorScheme.onSurfaceVariant),
          const SizedBox(height: AppSpacing.l),
          Text(
            '向相月提问，或选择一个助手',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          FilledButton.tonalIcon(
            onPressed: () => context.push('/assistants'),
            icon: const Icon(Symbols.smart_toy),
            label: const Text('选择助手'),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Symbols.error, size: 48, color: colorScheme.error),
          const SizedBox(height: AppSpacing.l),
          Text(message, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}

/// 会话抽屉（DESIGN.md §5.1）：顶部「新会话」+ 会话 ListTile 列表。
class _ConversationDrawer extends ConsumerWidget {
  const _ConversationDrawer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(conversationsProvider);
    return NavigationDrawer(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.l,
            AppSpacing.l,
            AppSpacing.l,
            AppSpacing.s,
          ),
          child: FilledButton.tonalIcon(
            onPressed: () {
              ref.read(chatControllerProvider.notifier).startNewConversation();
              Navigator.of(context).pop();
            },
            icon: const Icon(Symbols.add),
            label: const Text('新会话'),
          ),
        ),
        ...conversationsAsync.when(
          data: (conversations) => [
            for (final conversation in conversations)
              _ConversationTile(conversation: conversation),
          ],
          loading: () => [
            const Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
          error: (error, _) => [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.l),
              child: Text(
                error is Failure ? error.userMessage : '加载会话列表失败',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ConversationTile extends ConsumerWidget {
  const _ConversationTile({required this.conversation});

  final Conversation conversation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected =
        ref.watch(chatControllerProvider).conversationId == conversation.id;
    return MenuAnchor(
      menuChildren: [
        MenuItemButton(
          leadingIcon: const Icon(Symbols.edit),
          onPressed: () => _rename(context, ref),
          child: const Text('重命名'),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Symbols.push_pin),
          onPressed: () => _togglePinned(context, ref),
          child: Text(conversation.pinned ? '取消置顶' : '置顶'),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Symbols.delete),
          onPressed: () => _confirmDelete(context, ref),
          child: const Text('删除'),
        ),
      ],
      builder: (context, controller, child) {
        return ListTile(
          selected: selected,
          title: Text(conversation.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            _relativeTime(conversation.updatedAt),
            maxLines: 1,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          trailing: conversation.pinned
              ? Icon(
                  Symbols.keep,
                  size: 20,
                  // 置顶标记是全屏唯一的金色元素（DESIGN.md §2.1）。
                  color: context.brandColors.gold,
                )
              : null,
          onTap: () {
            ref
                .read(chatControllerProvider.notifier)
                .openConversation(conversation.id);
            Navigator.of(context).pop();
          },
          onLongPress: () =>
              controller.isOpen ? controller.close() : controller.open(),
        );
      },
    );
  }

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: conversation.title);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重命名会话'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 50,
          decoration: const InputDecoration(hintText: '会话名称'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (newTitle == null || newTitle.isEmpty || !context.mounted) {
      return;
    }
    await _runGuarded(
      context,
      () => ref
          .read(conversationRepositoryProvider)
          .renameConversation(conversation.id, newTitle),
    );
  }

  Future<void> _togglePinned(BuildContext context, WidgetRef ref) {
    return _runGuarded(
      context,
      () => ref
          .read(conversationRepositoryProvider)
          .setPinned(conversation.id, pinned: !conversation.pinned),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除会话'),
        content: Text('确定删除「${conversation.title}」吗？该会话的所有消息将一并删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    await _runGuarded(
      context,
      () => ref
          .read(conversationRepositoryProvider)
          .deleteConversation(conversation.id),
    );
    if (context.mounted &&
        ref.read(chatControllerProvider).conversationId == conversation.id) {
      ref.read(chatControllerProvider.notifier).startNewConversation();
    }
  }

  /// repository 异常统一在此兜成 SnackBar，不向 UI 上层抛（AGENTS.md §5）。
  Future<void> _runGuarded(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } on Failure catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(e.userMessage)));
      }
    }
  }

  static String _relativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) {
      return '刚刚';
    }
    if (diff.inHours < 1) {
      return '${diff.inMinutes} 分钟前';
    }
    if (diff.inDays < 1) {
      return '${diff.inHours} 小时前';
    }
    if (diff.inDays < 7) {
      return '${diff.inDays} 天前';
    }
    return '${time.month}月${time.day}日';
  }
}
