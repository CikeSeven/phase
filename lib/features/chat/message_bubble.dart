import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_icon_badge.dart';
import '../../../data/models/attachment.dart';
import '../../../data/models/chat_message.dart';
import '../../../data/models/message_part.dart';
import 'attachment_chips.dart';
import 'chat_code_block.dart';
import 'message_actions_sheet.dart';
import 'thinking_panel.dart';
import 'tool_call_card.dart';

/// 用户消息保留右侧色面，AI 正文使用完整的阅读宽度。
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    required this.message,
    this.attachments = const {},
    this.onRegenerate,
    super.key,
  });

  final ChatMessage message;

  /// 当前会话的附件索引，用于把 Part 里的附件引用还原成文件。
  final Map<String, Attachment> attachments;

  /// 重新生成本条回答；仅当前分支最后一条回答会传入。
  final Future<void> Function()? onRegenerate;

  /// 面板里是否提供「重新生成」。
  bool get canRegenerate => onRegenerate != null && !_isUser;

  bool get _isUser => message.role == ChatRole.user;

  /// 正文、思考与工具卡片按 Part 顺序分段：连续的同类内容合成一段，
  /// 工具调用各成一段（卡片只引用记录 id，不复制参数）。
  ///
  /// 工具循环每轮落一条助手消息，跨轮合并后各轮之间隔着工具调用，于是每轮的
  /// 思考各自成区、落在它那一轮的卡片之后——不会全部叠到回答区顶部
  /// （design 第二部分 §6.2；pi 的 assistant-message 同样按块顺序渲染）。
  List<_ContentSegment> _contentSegments() {
    final segments = <_ContentSegment>[];
    final text = StringBuffer();
    final thinking = StringBuffer();
    var pending = _SegmentKind.none;

    void flushText() {
      if (text.isEmpty) return;
      segments.add(_TextSegment(text.toString()));
      text.clear();
    }

    void flushThinking() {
      if (thinking.isEmpty) return;
      segments.add(_ThinkingSegment(thinking.toString()));
      thinking.clear();
    }

    /// 按内容出现的先后收口：先出现的那一类先成段。
    void flush() {
      switch (pending) {
        case _SegmentKind.text:
          flushText();
        case _SegmentKind.thinking:
          flushThinking();
        case _SegmentKind.none:
          break;
      }
      pending = _SegmentKind.none;
    }

    for (final part in message.parts) {
      switch (part) {
        case TextPart(text: final partText):
          if (partText.isEmpty) break;
          if (pending != _SegmentKind.text) flush();
          pending = _SegmentKind.text;
          text.write(partText);
        case ReasoningPart(:final publicText):
          if (publicText.isEmpty) break;
          if (pending != _SegmentKind.thinking) flush();
          pending = _SegmentKind.thinking;
          thinking.write(publicText);
        case ToolCallPart(:final toolCallId):
          flush();
          segments.add(_ToolSegment(toolCallId));
        default:
          break;
      }
    }
    flush();
    return segments;
  }

  /// 用户消息的附件与正文；助手消息的正文与思考分开渲染。
  List<Attachment> get _messageAttachments => [
    for (final part in message.parts)
      if (part is ImagePart && attachments[part.attachmentId] != null)
        attachments[part.attachmentId]!
      else if (part is DocumentPart && attachments[part.attachmentId] != null)
        attachments[part.attachmentId]!,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isError = message.status == MessageStatus.failed;
    final streaming = message.status == MessageStatus.streaming;
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
        customSemanticsActions: message.text.isEmpty
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
                              if (_messageAttachments.isNotEmpty) ...[
                                MessageAttachments(
                                  attachments: _messageAttachments,
                                ),
                                if (message.text.isNotEmpty)
                                  const SizedBox(height: AppSpacing.s),
                              ],
                              if (message.text.isNotEmpty)
                                Text(message.text, style: textStyle),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }
                final segments = _contentSegments();
                final lastThinkingIndex = segments.lastIndexWhere(
                  (segment) => segment is _ThinkingSegment,
                );
                // 思考区的稳定身份用「第几个思考区」，不用段序号：正文与思考
                // 的先后一变，段序号就会跳，面板会重建、用户的折叠偏好丢失。
                var thinkingOrdinal = 0;
                // 正在接收增量的思考段：只有最后一段在思考中，前面几轮的
                // 思考随它那一轮结束（工具卡片插进来）而收起。
                final liveThinkingIndex = streaming ? lastThinkingIndex : -1;
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
                            message.modelLabel ?? '相月',
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
                          // 正文、思考与工具卡片按 Part 顺序交错渲染：一轮
                          // 回答里模型先想一段、说一句、调用工具、再接着说，
                          // 顺序就是用户实际看到的顺序（design 第二部分 §6.2）。
                          for (final (index, segment) in segments.indexed)
                            switch (segment) {
                              _TextSegment(:final text) => GptMarkdown(
                                text,
                                key: index == 0
                                    ? const ValueKey('message-markdown')
                                    : null,
                                style: textStyle,
                                isStreaming: streaming,
                                codeBuilder:
                                    (context, language, code, closed) =>
                                        ChatCodeBlock(
                                          language: language,
                                          code: code,
                                        ),
                              ),
                              _ThinkingSegment(:final reasoning) => Padding(
                                key: ValueKey(
                                  'thinking-${message.id}-${thinkingOrdinal++}',
                                ),
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.m,
                                ),
                                child: ThinkingPanel(
                                  reasoning: reasoning,
                                  // 跨轮合并后只有最后一段还在接收增量：
                                  // 前面的思考随它那一轮结束，自动收起。
                                  streaming: index == liveThinkingIndex,
                                  // 思考耗时是整个回答区的统计，挂在最后一段。
                                  duration: index == lastThinkingIndex
                                      ? message.thinkingDurationMs == null
                                            ? null
                                            : Duration(
                                                milliseconds:
                                                    message.thinkingDurationMs!,
                                              )
                                      : null,
                                ),
                              ),
                              _ToolSegment(:final toolCallId) => ToolCallCard(
                                toolCallId: toolCallId,
                                attachments: attachments,
                              ),
                            },
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
    final action = await showMessageActionsSheet(
      context,
      canCopy: message.text.isNotEmpty,
      canRegenerate: canRegenerate,
    );
    if (!context.mounted) return;
    switch (action) {
      case MessageAction.copy:
        await _copy(context);
      case MessageAction.regenerate:
        await onRegenerate?.call();
      case null:
        break;
    }
  }

  Future<void> _copy(BuildContext context) async {
    String feedback;
    try {
      await Clipboard.setData(ClipboardData(text: message.text));
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

/// 渲染分段：连续的同类内容、或单个工具调用。
sealed class _ContentSegment {
  const _ContentSegment();
}

enum _SegmentKind { none, text, thinking }

class _TextSegment extends _ContentSegment {
  const _TextSegment(this.text);

  final String text;
}

class _ThinkingSegment extends _ContentSegment {
  const _ThinkingSegment(this.reasoning);

  final String reasoning;
}

class _ToolSegment extends _ContentSegment {
  const _ToolSegment(this.toolCallId);

  final String toolCallId;
}
