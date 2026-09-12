import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_spacing.dart';
import 'conversation_export.dart';

/// 选择导出格式；取消返回 null。
Future<ConversationExportFormat?> showConversationExportSheet(
  BuildContext context,
) {
  FocusManager.instance.primaryFocus?.unfocus();
  return showModalBottomSheet<ConversationExportFormat>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.l,
              0,
              AppSpacing.l,
              AppSpacing.s,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Semantics(
                header: true,
                child: Text(
                  '导出会话',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
          ),
          ListTile(
            key: const ValueKey('export-markdown'),
            leading: const Icon(Symbols.description),
            title: const Text('Markdown'),
            subtitle: const Text('按当前分支顺序导出正文、思考与工具记录'),
            onTap: () =>
                Navigator.of(context).pop(ConversationExportFormat.markdown),
          ),
          ListTile(
            key: const ValueKey('export-json'),
            leading: const Icon(Symbols.data_object),
            title: const Text('JSON'),
            subtitle: const Text('会话、消息与工具记录的完整结构'),
            onTap: () =>
                Navigator.of(context).pop(ConversationExportFormat.json),
          ),
          const SizedBox(height: AppSpacing.s),
        ],
      ),
    ),
  );
}
