import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/models/chat_message.dart';

/// 聊天气泡（DESIGN.md §5.2）。
///
/// 用户消息靠右（primaryContainer），AI 消息靠左
/// （surfaceContainerHighest + 模型名小字 + Markdown 渲染）。
class MessageBubble extends StatelessWidget {
  const MessageBubble({required this.message, super.key});

  final ChatMessage message;

  bool get _isUser => message.role == ChatRole.user;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (bubbleColor, textColor) = switch (message.status) {
      ChatMessageStatus.error => (
        colorScheme.errorContainer,
        colorScheme.onErrorContainer,
      ),
      _ when _isUser => (
        colorScheme.primaryContainer,
        colorScheme.onPrimaryContainer,
      ),
      _ => (colorScheme.surfaceContainerHighest, colorScheme.onSurface),
    };

    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.8,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.l,
        vertical: AppSpacing.m,
      ),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: AppRadius.largeAll,
      ),
      child: _buildContent(context, textColor),
    );

    return MenuAnchor(
      menuChildren: [
        MenuItemButton(
          leadingIcon: const Icon(Symbols.keep),
          onPressed: () => _copy(context),
          child: const Text('复制'),
        ),
        if (!_isUser)
          const MenuItemButton(
            leadingIcon: Icon(Symbols.error),
            // TODO(chat): 重新生成——以该消息之前的上下文重新调用 streamChat。
            onPressed: null,
            child: Text('重新生成'),
          ),
        const MenuItemButton(
          leadingIcon: Icon(Symbols.delete),
          // TODO(chat): 删除消息（repository 增加 deleteMessage 后接入）。
          onPressed: null,
          child: Text('删除'),
        ),
      ],
      builder: (context, controller, child) {
        return GestureDetector(
          onLongPress: () =>
              controller.isOpen ? controller.close() : controller.open(),
          child: child,
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.l,
          vertical: AppSpacing.xs,
        ),
        child: Column(
          crossAxisAlignment: _isUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (!_isUser && message.modelName != null)
              Padding(
                padding: const EdgeInsets.only(
                  left: AppSpacing.xs,
                  bottom: AppSpacing.xs,
                ),
                child: Text(
                  message.modelName!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            Align(
              alignment: _isUser
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: bubble,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, Color textColor) {
    final style = Theme.of(
      context,
    ).textTheme.bodyLarge?.copyWith(color: textColor, height: 1.5);
    // AI 消息按 Markdown 渲染；流式输出直接追加文本，不做逐字动画。
    final content = _isUser
        ? Text(message.content, style: style)
        : GptMarkdown(message.content, style: style);
    if (message.status != ChatMessageStatus.streaming) {
      return content;
    }
    // 流式中的闪烁光标占位（DESIGN.md §5.2）。
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Flexible(child: content),
        Text(
          '▍',
          style: style?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  void _copy(BuildContext context) {
    Clipboard.setData(ClipboardData(text: message.content));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('已复制')));
  }
}
