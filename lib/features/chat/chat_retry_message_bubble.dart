import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_spacing.dart';
import 'chat_retry_message.dart';
import 'chat_selection_area.dart';
import 'model_retry_status.dart';

/// 最近一次失败说明与重试进度在同一个列表位置更新。
class ChatRetryMessageBubble extends StatelessWidget {
  const ChatRetryMessageBubble({required this.message, super.key});

  final ChatRetryMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return SizeChangedLayoutNotifier(
      child: Semantics(
        container: true,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.l,
            AppSpacing.xs,
            AppSpacing.l,
            AppSpacing.s,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Icon(
                  LucideIcons.rotateCw,
                  size: 16,
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: AppSpacing.s),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (message.text.isNotEmpty) ...[
                      ChatSelectionArea(
                        child: Text(
                          message.text,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.error,
                            height: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                    ],
                    ModelRetryStatus(retry: message.retry),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
