import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:re_highlight/re_highlight.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import 'chat_code_highlighter.dart';
import 'chat_markdown_scroll_view.dart';

class ChatCodeBlock extends StatefulWidget {
  const ChatCodeBlock({
    required this.language,
    required this.code,
    this.closed = true,
    super.key,
  });

  final String language;
  final String code;
  final bool closed;

  @override
  State<ChatCodeBlock> createState() => _ChatCodeBlockState();
}

class _ChatCodeBlockState extends State<ChatCodeBlock> {
  HighlightResult? _highlight;
  TextSpan? _span;

  @override
  void initState() {
    super.initState();
    _parseCode();
  }

  @override
  void didUpdateWidget(ChatCodeBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.code != widget.code ||
        oldWidget.language != widget.language ||
        oldWidget.closed != widget.closed) {
      _parseCode();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _span = null;
  }

  void _parseCode() {
    // 未闭合代码立即显示原文；不要为流式淡入的每一帧重新分词。
    _highlight = widget.closed
        ? ChatCodeHighlighter.parse(widget.language, widget.code)
        : null;
    _span = null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final codeStyle = TextStyle(
      fontFamily: kGptMarkdownMonoFontFamily,
      package: kGptMarkdownFontPackage,
      fontSize: 15,
      height: 1.5,
      color: colors.onSurface,
    );
    _span ??= ChatCodeHighlighter.render(
      context,
      _highlight,
      widget.code,
      codeStyle,
    );
    // 代码块作为 WidgetSpan 已由 Markdown 段落缩放，内部不再次缩放文字。
    return MediaQuery.withNoTextScaling(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
        child: Material(
          color: colors.surfaceContainerLow,
          borderRadius: AppRadius.controlAll,
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              ColoredBox(
                color: colors.surfaceContainerHigh,
                child: Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.l),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.language.trim().isEmpty
                              ? '代码'
                              : widget.language.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: '复制代码',
                        onPressed: () => _copy(context),
                        icon: const Icon(Symbols.content_copy, size: 20),
                      ),
                    ],
                  ),
                ),
              ),
              ChatMarkdownScrollView(
                padding: const EdgeInsets.all(AppSpacing.l),
                child: Text.rich(
                  _span!,
                  style: codeStyle,
                  softWrap: false,
                  textDirection: TextDirection.ltr,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _copy(BuildContext context) async {
    String feedback;
    try {
      await Clipboard.setData(ClipboardData(text: widget.code));
      feedback = '代码已复制';
    } on PlatformException {
      feedback = '复制失败，请重试';
    }
    if (!context.mounted) return;
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(feedback)));
  }
}
