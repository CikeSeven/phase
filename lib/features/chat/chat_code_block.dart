import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:re_highlight/re_highlight.dart';

import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/brand_colors.dart';
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
  Timer? _copyFeedbackTimer;
  bool _copying = false;
  bool _copied = false;
  bool _previewOpen = false;

  @override
  void initState() {
    super.initState();
    _parseCode();
  }

  @override
  void didUpdateWidget(ChatCodeBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.code != widget.code) {
      _copyFeedbackTimer?.cancel();
      _copied = false;
    }
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

  @override
  void dispose() {
    _copyFeedbackTimer?.cancel();
    super.dispose();
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
    final reduced = AppMotion.reduce(context);
    final copyIcon = Icon(
      _copied ? Symbols.check : Symbols.content_copy,
      key: ValueKey(_copied),
      size: 20,
      color: _copied ? context.brandColors.teal : colors.onSurfaceVariant,
    );
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
                      if (widget.language.trim().toLowerCase() == 'html')
                        IconButton(
                          tooltip: '预览 HTML',
                          onPressed: _previewOpen ? null : _preview,
                          icon: Icon(
                            Symbols.visibility,
                            size: 20,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      Semantics(
                        liveRegion: _copied,
                        child: IconButton(
                          tooltip: _copied ? '代码已复制' : '复制代码',
                          onPressed: _copy,
                          icon: ExcludeSemantics(
                            child: SizedBox.square(
                              dimension: 20,
                              child: reduced
                                  ? copyIcon
                                  : AnimatedSwitcher(
                                      duration: AppMotion.effects,
                                      switchInCurve: Curves.easeOutCubic,
                                      switchOutCurve: Curves.easeInCubic,
                                      transitionBuilder: _copyIconTransition,
                                      child: copyIcon,
                                    ),
                            ),
                          ),
                        ),
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

  static Widget _copyIconTransition(
    Widget child,
    Animation<double> animation,
  ) => FadeTransition(
    opacity: animation,
    child: ScaleTransition(
      scale: animation.drive(Tween<double>(begin: 0.8, end: 1)),
      child: child,
    ),
  );

  Future<void> _preview() async {
    if (_previewOpen) return;
    setState(() => _previewOpen = true);
    try {
      await context.push<void>('/html-preview', extra: widget.code);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)
        ?..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('无法打开 HTML 预览，请重试')));
    } finally {
      if (mounted) setState(() => _previewOpen = false);
    }
  }

  Future<void> _copy() async {
    if (_copying) return;
    _copying = true;
    final code = widget.code;
    try {
      await Clipboard.setData(ClipboardData(text: code));
      if (!mounted || widget.code != code) return;
      _copyFeedbackTimer?.cancel();
      setState(() => _copied = true);
      _copyFeedbackTimer = Timer(const Duration(seconds: 2), () {
        if (!mounted) return;
        setState(() => _copied = false);
      });
    } on PlatformException {
      if (!mounted || widget.code != code) return;
      _copyFeedbackTimer?.cancel();
      setState(() => _copied = false);
      ScaffoldMessenger.maybeOf(context)
        ?..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('复制失败，请重试')));
    } finally {
      _copying = false;
    }
  }
}
