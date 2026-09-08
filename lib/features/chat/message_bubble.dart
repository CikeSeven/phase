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
    final Widget content;
    if (_isUser) {
      content = Text(message.content, style: style);
    } else {
      final reasoning = message.reasoning;
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (reasoning != null && reasoning.isNotEmpty)
            _ReasoningSection(
              reasoning: reasoning,
              streaming: message.status == ChatMessageStatus.streaming,
            ),
          GptMarkdown(
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
          ),
        ],
      );
    }
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

/// AI 气泡内 Markdown 上方的「思考」区块。
///
/// 流式进行中自动展开、结束后默认收起；用户手动折叠/展开后不再跟随。
class _ReasoningSection extends StatefulWidget {
  const _ReasoningSection({required this.reasoning, required this.streaming});

  final String reasoning;
  final bool streaming;

  @override
  State<_ReasoningSection> createState() => _ReasoningSectionState();
}

class _ReasoningSectionState extends State<_ReasoningSection> {
  late bool _expanded = widget.streaming;
  var _userToggled = false;

  @override
  void didUpdateWidget(covariant _ReasoningSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 未手动干预时跟随流式状态：进行中展开，结束后收起。
    if (!_userToggled && oldWidget.streaming != widget.streaming) {
      _expanded = widget.streaming;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final labelStyle = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          borderRadius: AppRadius.smallAll,
          onTap: () => setState(() {
            _expanded = !_expanded;
            _userToggled = true;
          }),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Row(
              children: [
                Icon(
                  Symbols.psychology,
                  size: 20,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.s),
                Expanded(
                  child: Text(
                    widget.streaming ? '思考中…' : '已思考',
                    style: labelStyle,
                  ),
                ),
                Icon(
                  _expanded ? Symbols.expand_less : Symbols.expand_more,
                  size: 20,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
        if (_expanded)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(
              top: AppSpacing.xs,
              bottom: AppSpacing.s,
            ),
            padding: const EdgeInsets.only(left: AppSpacing.m),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: colorScheme.outlineVariant, width: 2),
              ),
            ),
            child: Text(
              widget.reasoning,
              style: labelStyle?.copyWith(height: 1.5),
            ),
          )
        else
          const SizedBox(height: AppSpacing.s),
      ],
    );
  }
}

/// 流式输出末尾的闪烁光标（DESIGN.md §5.2）。
class _BlinkingCursor extends StatefulWidget {  const _BlinkingCursor({this.style});

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
