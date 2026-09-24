import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import 'chat_code_block.dart';
import 'chat_markdown_scroll_view.dart';
import 'chat_markdown_table.dart';

/// 只约束助手正文的排版，不改变原文、全局主题或工具内容。
class ChatMarkdown extends StatefulWidget {
  const ChatMarkdown({
    required this.text,
    required this.streaming,
    this.textColor,
    super.key,
  });

  final String text;
  final bool streaming;
  final Color? textColor;

  @override
  State<ChatMarkdown> createState() => _ChatMarkdownState();
}

class _ChatMarkdownState extends State<ChatMarkdown> {
  static final _components = [
    for (final component in MarkdownComponent.globalComponents)
      switch (component) {
        NewLines() => _ParagraphBreak(),
        UnOrderedList() => _SpacedUnorderedList(),
        OrderedList() => _SpacedOrderedList(),
        LatexMathMultiLine() => _ScrollableBlockMath(),
        _ => component,
      },
  ];

  late GptMarkdownThemeData _markdownTheme;
  late TextStyle _bodyStyle;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateTheme();
  }

  @override
  void didUpdateWidget(ChatMarkdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.textColor != widget.textColor) _updateTheme();
  }

  void _updateTheme() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final color = widget.textColor ?? colors.onSurface;
    final emphasis = color == colors.onSurface ? colors.primary : color;
    _bodyStyle = theme.textTheme.bodyLarge!.copyWith(
      color: color,
      fontSize: 16,
      height: 1.6,
    );
    TextStyle heading(double size, {bool secondary = false}) =>
        _bodyStyle.copyWith(
          fontSize: size,
          height: 1.4,
          color: secondary ? color : emphasis,
          fontWeight: secondary ? FontWeight.w600 : FontWeight.w700,
        );
    // 主题实例只随实际主题/前景色改变，避免流式增量使稳定前缀重新解析。
    _markdownTheme = GptMarkdownThemeData(
      brightness: theme.brightness,
      h1: heading(24),
      h2: heading(22),
      h3: heading(20),
      h4: heading(18, secondary: true),
      h5: heading(16, secondary: true),
      h6: heading(16, secondary: true),
      autoAddDividerLineAfterH1: false,
      linkColor: emphasis,
      linkHoverColor: emphasis,
      styleSheet: GptMarkdownStyleSheet(
        heading: const HeadingStyle(
          padding: EdgeInsets.only(top: AppSpacing.l, bottom: AppSpacing.s),
          showDivider: false,
        ),
        link: LinkStyle(
          color: emphasis,
          hoverColor: emphasis,
          decoration: TextDecoration.underline,
          fontWeight: FontWeight.w500,
        ),
        inlineCode: InlineCodeStyle(
          fontSizeFactor: 15 / 16,
          color: emphasis,
          backgroundColor: colors.surfaceContainerHigh,
          borderWidth: 0,
          borderColor: Colors.transparent,
          borderRadius: const Radius.circular(AppSpacing.xs),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        ),
        blockQuote: BlockQuoteStyle(
          barWidth: 3,
          barColor: colors.primary,
          barRadius: const Radius.circular(AppRadius.small),
          backgroundColor: Color.alphaBlend(
            colors.primary.withValues(alpha: 0.06),
            colors.surfaceContainerLow,
          ),
          padding: const EdgeInsets.all(AppSpacing.m),
          margin: const EdgeInsets.symmetric(vertical: AppSpacing.s),
          textStyle: _bodyStyle.copyWith(color: colors.onSurface),
        ),
        list: ListStyle(
          indent: AppSpacing.xs,
          gapAfterMarker: AppSpacing.s,
          bulletSize: AppSpacing.xs,
          bulletColor: emphasis,
          markerTextStyle: _bodyStyle.copyWith(
            color: emphasis,
            fontWeight: FontWeight.w600,
          ),
        ),
        hr: HrStyle(
          color: colors.outlineVariant,
          thickness: 1,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.m),
        ),
        latex: const LatexStyle(
          padding: EdgeInsets.all(AppSpacing.m),
          scrollBlockHorizontally: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => GptMarkdownTheme(
    gptThemeData: _markdownTheme,
    child: GptMarkdown(
      widget.text,
      style: _bodyStyle,
      components: _components,
      // 保留库的稳定前缀缓存和增量淡入，不把模型输出变成慢速打字效果。
      animation: widget.streaming
          ? GptMarkdownAnimation.fade
          : GptMarkdownAnimation.none,
      charactersPerSecond: 1200,
      isStreaming: widget.streaming,
      codeBuilder: (context, language, code, closed) =>
          ChatCodeBlock(language: language, code: code, closed: closed),
      tableBuilder: (context, rows, style, config) =>
          ChatMarkdownTable(rows: rows, config: config),
    ),
  );
}

class _ParagraphBreak extends NewLines {
  @override
  InlineSpan span(
    BuildContext context,
    String text,
    GptMarkdownConfig config,
  ) => const TextSpan(
    children: [
      TextSpan(text: '\n'),
      // 仅调整空白行的行盒，不替换原文，也不拆开代码、公式和列表。
      TextSpan(
        text: '\n',
        style: TextStyle(fontSize: AppSpacing.m, height: 1),
      ),
    ],
  );
}

class _SpacedUnorderedList extends UnOrderedList {
  @override
  Widget build(BuildContext context, String text, GptMarkdownConfig config) =>
      Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
        child: super.build(context, text, config),
      );
}

class _SpacedOrderedList extends OrderedList {
  @override
  Widget build(BuildContext context, String text, GptMarkdownConfig config) =>
      Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
        child: super.build(context, text, config),
      );
}

class _ScrollableBlockMath extends LatexMathMultiLine {
  @override
  Widget build(BuildContext context, String text, GptMarkdownConfig config) {
    final sheet = resolvedStyleSheet(context, config);
    final latex = sheet.latex ?? const LatexStyle();
    // 沿用库的公式解析/错误回退，只替换横滚宿主，避免嵌套两层横滚。
    final content = super.build(
      context,
      text,
      config.copyWith(
        styleSheet: sheet.copyWith(
          latex: latex.copyWith(
            padding: EdgeInsets.zero,
            scrollBlockHorizontally: false,
          ),
        ),
      ),
    );
    return MediaQuery.withNoTextScaling(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
        child: ChatMarkdownScrollView(
          padding: const EdgeInsets.all(AppSpacing.m),
          child: content,
        ),
      ),
    );
  }
}
