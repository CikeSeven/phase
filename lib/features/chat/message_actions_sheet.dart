import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';

/// 消息操作的结果。
enum MessageAction { copy, regenerate }

/// 返回用户选择的操作；取消面板返回 null。
Future<MessageAction?> showMessageActionsSheet(
  BuildContext context, {
  required bool canCopy,
  bool canRegenerate = false,
}) {
  FocusManager.instance.primaryFocus?.unfocus();
  return showModalBottomSheet<MessageAction>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) =>
        MessageActionsSheet(canCopy: canCopy, canRegenerate: canRegenerate),
  );
}

/// 按内容高度展开的消息操作面板。
class MessageActionsSheet extends StatelessWidget {
  const MessageActionsSheet({
    required this.canCopy,
    this.canRegenerate = false,
    super.key,
  });

  final bool canCopy;

  /// 仅当前分支最后一条回答可重新生成。
  final bool canRegenerate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.l,
            0,
            AppSpacing.l,
            AppSpacing.l,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.s),
                child: Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          '消息操作',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '关闭',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Symbols.close),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              ListTile(
                key: const ValueKey('copy-message'),
                leading: const Icon(Symbols.content_copy),
                title: const Text('复制'),
                shape: const RoundedRectangleBorder(
                  borderRadius: AppRadius.smallAll,
                ),
                enabled: canCopy,
                onTap: canCopy
                    ? () => Navigator.of(context).pop(MessageAction.copy)
                    : null,
              ),
              if (canRegenerate)
                ListTile(
                  key: const ValueKey('regenerate-message'),
                  leading: const Icon(Symbols.refresh),
                  title: const Text('重新生成'),
                  subtitle: const Text('保留当前回答，生成一条新的'),
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppRadius.smallAll,
                  ),
                  onTap: () =>
                      Navigator.of(context).pop(MessageAction.regenerate),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
