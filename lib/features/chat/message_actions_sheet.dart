import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import 'chat_action_sheet.dart';

/// 消息操作的结果。
enum MessageAction { copy, regenerate, usage }

/// 返回用户选择的操作；取消面板返回 null。
Future<MessageAction?> showMessageActionsSheet(
  BuildContext context, {
  required bool canCopy,
  bool canRegenerate = false,
  bool canViewUsage = false,
}) {
  FocusManager.instance.primaryFocus?.unfocus();
  return showModalBottomSheet<MessageAction>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => MessageActionsSheet(
      canCopy: canCopy,
      canRegenerate: canRegenerate,
      canViewUsage: canViewUsage,
    ),
  );
}

/// 按内容高度展开的消息操作面板。
class MessageActionsSheet extends StatelessWidget {
  const MessageActionsSheet({
    required this.canCopy,
    this.canRegenerate = false,
    this.canViewUsage = false,
    super.key,
  });

  final bool canCopy;

  /// 仅当前分支最后一条回答可重新生成。
  final bool canRegenerate;
  final bool canViewUsage;

  @override
  Widget build(BuildContext context) => ChatActionSheet<MessageAction>(
    title: '消息操作',
    actions: [
      ChatSheetAction(
        key: const ValueKey('copy-message'),
        value: MessageAction.copy,
        label: '复制',
        icon: Symbols.content_copy,
        enabled: canCopy,
      ),
      if (canRegenerate)
        const ChatSheetAction(
          key: ValueKey('regenerate-message'),
          value: MessageAction.regenerate,
          label: '重新生成',
          description: '保留当前回答，生成一条新的',
          icon: Symbols.refresh,
        ),
      if (canViewUsage)
        const ChatSheetAction(
          value: MessageAction.usage,
          label: '用量',
          description: '查看所属运行及每次请求',
          icon: Symbols.data_usage,
        ),
    ],
  );
}
