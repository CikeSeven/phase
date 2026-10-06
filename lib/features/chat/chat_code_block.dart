import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:re_highlight/re_highlight.dart';

import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../core/widgets/app_snack_bar.dart';
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
  bool _wrapLines = false;

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

  String get _normalizedCode => widget.closed && widget.code.endsWith('\n')
      ? widget.code.substring(0, widget.code.length - 1)
      : widget.code;

  void _parseCode() {
    // 未闭合代码立即显示原文；不为流式淡入的每一帧重复分词。
    final code = _normalizedCode;
    _highlight = widget.closed
        ? ChatCodeHighlighter.parse(widget.language, code)
        : null;
    _span = null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final brand = context.brandColors;
    final reduced = AppMotion.reduce(context);

    final normalized = _normalizedCode;
    final lineCount = '\n'.allMatches(normalized).length + 1;
    final showLineNumbers = lineCount > 1 && !_wrapLines;
    final langDisplay = ChatCodeHighlighter.formatLanguageName(widget.language);

    final copyIcon = Icon(
      _copied ? LucideIcons.check : LucideIcons.copy,
      key: ValueKey(_copied),
      size: 18,
      color: _copied ? brand.teal : colors.onSurfaceVariant,
    );

    final codeStyle = TextStyle(
      fontFamily: kGptMarkdownMonoFontFamily,
      package: kGptMarkdownFontPackage,
      fontSize: 14,
      height: 1.5,
      color: colors.onSurface,
    );

    _span ??= ChatCodeHighlighter.render(
      context,
      _highlight,
      normalized,
      codeStyle,
    );

    // 代码块作为 WidgetSpan 已由外层统一缩放，内部不再次缩放文字。
    return MediaQuery.withNoTextScaling(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
        child: Material(
          color: colors.surfaceContainerLowest,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.controlAll,
            side: BorderSide(
              color: colors.outlineVariant.withValues(alpha: 0.45),
              width: 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 代码块头部栏
              Container(
                color: colors.surfaceContainerHigh.withValues(alpha: 0.65),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
                child: Row(
                  children: [
                    // 语言标识与状态点
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.8),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s),
                    Text(
                      langDisplay,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                    if (lineCount > 1) ...[
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        '· $lineCount 行',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colors.onSurfaceVariant.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                    const Spacer(),
                    // 预览 HTML 动作
                    if (widget.language.trim().toLowerCase() == 'html')
                      IconButton(
                        tooltip: '预览 HTML',
                        visualDensity: VisualDensity.compact,
                        onPressed: _previewOpen ? null : _preview,
                        icon: Icon(
                          LucideIcons.eye,
                          size: 18,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    // 换行模式切换
                    IconButton(
                      tooltip: _wrapLines ? '单行横滚' : '自动折行',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => setState(() => _wrapLines = !_wrapLines),
                      icon: Icon(
                        _wrapLines
                            ? LucideIcons.alignLeft
                            : LucideIcons.wrapText,
                        size: 18,
                        color: _wrapLines
                            ? colors.primary
                            : colors.onSurfaceVariant,
                      ),
                    ),
                    // 复制代码
                    Semantics(
                      liveRegion: _copied,
                      child: IconButton(
                        tooltip: _copied ? '代码已复制' : '复制代码',
                        visualDensity: VisualDensity.compact,
                        onPressed: _copy,
                        icon: ExcludeSemantics(
                          child: SizedBox.square(
                            dimension: 18,
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
              // 分隔线
              Divider(
                height: 1,
                thickness: 1,
                color: colors.outlineVariant.withValues(alpha: 0.35),
              ),
              // 代码正文与行号区
              if (_wrapLines)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.l),
                  child: Text.rich(
                    _span!,
                    style: codeStyle,
                    softWrap: true,
                    textDirection: TextDirection.ltr,
                  ),
                )
              else
                ChatMarkdownScrollView(
                  padding: const EdgeInsets.all(AppSpacing.l),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (showLineNumbers)
                        Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.m),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              for (var i = 1; i <= lineCount; i++)
                                Text(
                                  '$i',
                                  style: codeStyle.copyWith(
                                    color: colors.onSurfaceVariant.withValues(
                                      alpha: 0.4,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      Text.rich(
                        _span!,
                        style: codeStyle,
                        softWrap: false,
                        textDirection: TextDirection.ltr,
                      ),
                    ],
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
      await context.push<void>('/html-preview', extra: _normalizedCode);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          buildAppSnackBar(content: const Text('无法打开 HTML 预览，请重试')),
        );
    } finally {
      if (mounted) setState(() => _previewOpen = false);
    }
  }

  Future<void> _copy() async {
    if (_copying) return;
    _copying = true;
    final code = _normalizedCode;
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
        ..showSnackBar(buildAppSnackBar(content: const Text('复制失败，请重试')));
    } finally {
      _copying = false;
    }
  }
}
