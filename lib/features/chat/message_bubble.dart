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
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ),
            Align(
              alignment: _isUser ? Alignment.centerRight : Alignment.centerLeft,
              child: bubble,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, Color textColor) {
    final colorScheme = Theme.of(context).colorScheme;
    final bodyLarge = Theme.of(context).textTheme.bodyLarge;
    final style = bodyLarge?.copyWith(color: textColor, height: 1.5);
    // AI 消息按 Markdown 渲染；流式输出直接追加文本，不做逐字动画。
    final content = _isUser
        ? Text(message.content, style: style)
        : GptMarkdown(
            message.content,
            style: style,
            styleSheet: GptMarkdownStyleSheet(
              // 代码块语义槽位见 DESIGN.md §2.2；复制按钮为 gpt_markdown 自带能力。
              codeBlock: CodeBlockStyle(
                backgroundColor: colorScheme.surfaceContainerHigh,
                textColor: colorScheme.onSurfaceVariant,
                borderRadius: const Radius.circular(AppRadius.medium),
                fontSize: (bodyLarge?.fontSize ?? 16) - 1,
                copyLabel: '复制代码',
                copiedLabel: '已复制',
              ),
            ),
          );
    if (message.status != ChatMessageStatus.streaming) {
      return content;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Flexible(child: content),
        _BlinkingCursor(
          style: style?.copyWith(color: colorScheme.onSurfaceVariant),
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

/// 流式输出末尾的闪烁光标（DESIGN.md §5.2）。
class _BlinkingCursor extends StatefulWidget {
  const _BlinkingCursor({this.style});

  final TextStyle? style;

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 系统「减少动态效果」开启时不闪烁（DESIGN.md §6）。
    // MediaQuery 只能在 didChangeDependencies 之后读取，不能放 initState。
    if (MediaQuery.of(context).disableAnimations) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Text('▍', style: widget.style),
    );
  }
}
