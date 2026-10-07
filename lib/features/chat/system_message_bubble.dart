import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../data/models/chat_message.dart';
import 'chat_selection_area.dart';

/// 可见的宿主通知；失败说明与模型回答分别展示。
class SystemMessageBubble extends StatelessWidget {
  const SystemMessageBubble({required this.message, super.key});

  final ChatMessage message;

  String get _text {
    final text = message.text;
    if (message.status != MessageStatus.failed) return text;
    final prefix = RegExp(r'^(?:请求失败（第 \d+ 次）：|模型请求失败：)').firstMatch(text);
    if (prefix == null) return text;
    final body = text.substring(prefix.end).trim();
    try {
      final decoded = jsonDecode(body);
      if (decoded case {'error': {'message': final String value}}) {
        return value;
      }
      if (decoded case {'message': final String value}) return value;
      if (decoded case {'error': final String value}) return value;
      if (decoded is Map || decoded is List) return '请求失败';
    } on FormatException {
      // 旧版本也保存过普通错误文本，保留其具体说明。
    }
    return body;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final failed = message.status == MessageStatus.failed;
    final foreground = failed ? colors.error : colors.onSurfaceVariant;

    return SizeChangedLayoutNotifier(
      child: Semantics(
        container: true,
        liveRegion: failed,
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
                  failed ? LucideIcons.circleAlert : LucideIcons.info,
                  size: 16,
                  color: foreground,
                ),
              ),
              const SizedBox(width: AppSpacing.s),
              Expanded(
                child: ChatSelectionArea(
                  child: Text(
                    _text,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: foreground,
                      height: 1.5,
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
