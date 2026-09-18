import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'chat_action_sheet.dart';
import 'conversation_export.dart';

/// 选择导出格式；取消返回 null。
Future<ConversationExportFormat?> showConversationExportSheet(
  BuildContext context,
) {
  FocusManager.instance.primaryFocus?.unfocus();
  return showModalBottomSheet<ConversationExportFormat>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => const ChatActionSheet<ConversationExportFormat>(
      title: '导出会话',
      actions: [
        ChatSheetAction(
          key: ValueKey('export-markdown'),
          value: ConversationExportFormat.markdown,
          label: 'Markdown',
          description: '按当前分支顺序导出正文、思考与工具记录',
          icon: Symbols.description,
        ),
        ChatSheetAction(
          key: ValueKey('export-json'),
          value: ConversationExportFormat.json,
          label: 'JSON',
          description: '会话、消息与工具记录的完整结构',
          icon: Symbols.data_object,
        ),
      ],
    ),
  );
}
