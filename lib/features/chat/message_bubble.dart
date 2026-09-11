import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_icon_badge.dart';
import '../../../data/models/chat_message.dart';
import 'attachment_chips.dart';
import 'chat_code_block.dart';
import 'message_actions_sheet.dart';
import 'thinking_panel.dart';

/// 用户消息保留右侧色面，AI 正文使用完整的阅读宽度。
class MessageBubble extends StatelessWidget {
  const MessageBubble({required this.message, super.key});

  final ChatMessage message;

  bool get _isUser => message.role == ChatRole.user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isError = message.status == ChatMessageStatus.error;
    final streaming = message.status == ChatMessageStatus.streaming;
    final textColor = isError
        ? colors.onErrorContainer
        : _isUser
        ? colors.onPrimaryContainer
        : colors.onSurface;
    final textStyle = theme.textTheme.bodyLarge?.copyWith(
      color: textColor,
      height: 1.5,
    );

    return SizeChangedLayoutNotifier(
      child: Semantics(
        customSemanticsActions: message.content.isEmpty
            ? null
            : {CustomSemanticsAction(label: '复制消息'): () => _copy(context)},
        child: GestureDetector(
          onLongPress: () => _showActions(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.l,
              vertical: AppSpacing.m,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (_isUser) {
                  return Align(
                    alignment: Alignment.centerRight,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: constraints.maxWidth * 0.88,
                      ),
                      child: Material(
                        color:
                            (isError
                                    ? colors.errorContainer
                                    : colors.primaryContainer)
                                .withValues(alpha: 0.82),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(AppRadius.large),
                          topRight: Radius.circular(AppRadius.large),
                          bottomLeft: Radius.circular(AppRadius.large),
                          bottomRight: Radius.circular(AppRadius.small),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.l,
                            vertical: AppSpacing.m,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (message.attachments.isNotEmpty) ...[
                                MessageAttachments(
                                  attachments: message.attachments,
                                ),
                                if (message.content.isNotEmpty)
                                  const SizedBox(height: AppSpacing.s),
                              ],
                              if (message.content.isNotEmpty)
                                Text(message.content, style: textStyle),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const AppIconBadge(
                          icon: Symbols.auto_awesome,
                          tone: AppTone.teal,
                          size: 32,
                          iconSize: 18,
                        ),
                        const SizedBox(width: AppSpacing.s),
                        Expanded(
                          child: Text(
                            message.modelName ?? '相月',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: '消息操作',
                          onPressed: () => _showActions(context),
                          icon: const Icon(Symbols.more_horiz),
                        ),
                      ],
                    ),
                    if (message.reasoning?.isNotEmpty == true)
                      Padding(
                        key: ValueKey('thinking-${message.id}'),
                        padding: const EdgeInsets.only(
                          top: AppSpacing.s,
                          bottom: AppSpacing.m,
                        ),
                        child: ThinkingPanel(
                          reasoning: message.reasoning!,
                          streaming: streaming,
                        ),
                      ),
                    Container(
                      key: const ValueKey('message-body'),
                      padding: isError
                          ? const EdgeInsets.all(AppSpacing.l)
                          : EdgeInsets.zero,
                      decoration: isError
                          ? BoxDecoration(
                              color: colors.errorContainer.withValues(
                                alpha: 0.72,
                              ),
                              borderRadius: AppRadius.mediumAll,
                              border: Border.all(
                                color: colors.error.withValues(alpha: 0.24),
                              ),
                            )
                          : null,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (isError) ...[
                            Row(
                              children: [
                                Icon(
                                  Symbols.error,
                                  size: 18,
                                  color: colors.onErrorContainer,
                                ),
                                const SizedBox(width: AppSpacing.s),
                                Expanded(
                                  child: Text(
                                    '回复未完成',
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      color: colors.onErrorContainer,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.s),
                          ],
                          GptMarkdown(
                            message.content,
                            key: const ValueKey('message-markdown'),
                            style: textStyle,
                            isStreaming: streaming,
                            codeBuilder: (context, language, code, closed) =>
                                ChatCodeBlock(language: language, code: code),
                          ),
                        ],
                      ),
                    ),
                    if (streaming)
                      Align(
                        key: const ValueKey('generation-cursor'),
                        alignment: Alignment.centerLeft,
                        child: _GenerationCursor(
                          style: textStyle?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showActions(BuildContext context) async {
    final copy = await showMessageActionsSheet(
      context,
      canCopy: message.content.isNotEmpty,
    );
    if (copy == true && context.mounted) await _copy(context);
  }

  Future<void> _copy(BuildContext context) async {
    String feedback;
    try {
      await Clipboard.setData(ClipboardData(text: message.content));
      feedback = '已复制';
    } on PlatformException {
      feedback = '复制失败，请重试';
    }
    if (!context.mounted) return;
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(feedback)));
  }
}

class _GenerationCursor extends StatefulWidget {
  const _GenerationCursor({this.style});

  final TextStyle? style;

  @override
  State<_GenerationCursor> createState() => _GenerationCursorState();
}

class _GenerationCursorState extends State<_GenerationCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      value: 1,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final media = MediaQuery.of(context);
    if (media.disableAnimations ||
        media.accessibleNavigation ||
        !TickerMode.valuesOf(context).enabled) {
      _controller.stop();
      _controller.value = 1;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true, min: 0.25, max: 1);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: FadeTransition(
        opacity: _controller,
        child: Text('▍', style: widget.style),
      ),
    );
  }
}
