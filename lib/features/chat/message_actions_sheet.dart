import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';

/// 返回是否复制消息；取消面板不执行操作。
Future<bool?> showMessageActionsSheet(
  BuildContext context, {
  required bool canCopy,
}) {
  FocusManager.instance.primaryFocus?.unfocus();
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => MessageActionsSheet(canCopy: canCopy),
  );
}

/// 按内容高度展开的消息操作面板。
class MessageActionsSheet extends StatelessWidget {
  const MessageActionsSheet({required this.canCopy, super.key});

  final bool canCopy;

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
                onTap: canCopy ? () => Navigator.of(context).pop(true) : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
