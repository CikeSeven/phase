import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/external_web_link.dart';
import 'chat_code_block.dart';
import 'chat_markdown_alert.dart';
import 'chat_markdown_scroll_view.dart';
import 'chat_markdown_table.dart';

/// 聊天 Markdown 渲染组件：针对 Material 3 Expressive 体系深度定制，
/// 支持代码块语法高亮与行号、GitHub 风格 Callout 警告卡片、任务清单复选框、
/// 独立横滚数据表格以及 LaTeX 数学公式。
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
        BlockQuote() => _ChatBlockQuote(),
        UnOrderedList() => _ChatUnorderedList(),
        OrderedList() => _SpacedOrderedList(),
        LatexMathMultiLine() => _ScrollableBlockMath(),
        _ => component,
      },
  ];

  late GptMarkdownThemeData _markdownTheme;
  late TextStyle _bodyStyle;

  String _cachedOriginalText = '';
  String _cachedTransformedText = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateTheme();
  }

  @override
  void didUpdateWidget(ChatMarkdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.textColor != widget.textColor) {
      _updateTheme();
    }
  }

  void _updateTheme() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final color = widget.textColor ?? colors.onSurface;
    final emphasis = color == colors.onSurface ? colors.primary : color;
    final isDark = theme.brightness == Brightness.dark;

    _bodyStyle = theme.textTheme.bodyLarge!.copyWith(
      color: color,
      fontSize: 15.5,
      height: 1.6,
    );

    TextStyle heading(double size, {FontWeight weight = FontWeight.w700}) =>
        _bodyStyle.copyWith(
          fontSize: size,
          height: 1.35,
          color: color,
          fontWeight: weight,
          letterSpacing: -0.2,
        );

    _markdownTheme = GptMarkdownThemeData(
      brightness: theme.brightness,
      h1: heading(22),
      h2: heading(19),
      h3: heading(17, weight: FontWeight.w600),
      h4: heading(15.5, weight: FontWeight.w600),
      h5: heading(14.5, weight: FontWeight.w600),
      h6: heading(
        13.5,
        weight: FontWeight.w600,
      ).copyWith(color: colors.onSurfaceVariant),
      autoAddDividerLineAfterH1: false,
      linkColor: colors.primary,
      linkHoverColor: colors.primary.withValues(alpha: 0.8),
      // 行内代码配置：使用零水平 padding 避免 canvas 底色切入/压盖相邻字符；
      // 使用品牌主题色与柔和底色胶囊，保持辨识度同时融入段落排版。
      inlineCode: InlineCodeStyle(
        fontFamily: kGptMarkdownMonoFontFamily,
        fontFamilyPackage: kGptMarkdownFontPackage,
        fontFamilyFallback: const ['monospace', 'sans-serif'],
        fontSizeFactor: 0.92,
        fontWeight: FontWeight.w500,
        color: emphasis,
        backgroundColor: colors.primary.withValues(alpha: isDark ? 0.16 : 0.09),
        borderWidth: 0,
        borderColor: Colors.transparent,
        borderRadius: const Radius.circular(AppRadius.small),
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
      ),
      styleSheet: GptMarkdownStyleSheet(
        heading: const HeadingStyle(
          padding: EdgeInsets.only(top: AppSpacing.l, bottom: AppSpacing.s),
          showDivider: false,
        ),
        link: LinkStyle(
          color: colors.primary,
          hoverColor: colors.primary.withValues(alpha: 0.8),
          decoration: TextDecoration.underline,
          decorationThickness: 1.2,
          fontWeight: FontWeight.w600,
        ),
        blockQuote: BlockQuoteStyle(
          barWidth: 3.5,
          barColor: colors.primary,
          barRadius: const Radius.circular(AppRadius.small),
          backgroundColor: Color.alphaBlend(
            colors.primary.withValues(alpha: 0.05),
            colors.surfaceContainerLow,
          ),
          padding: const EdgeInsets.all(AppSpacing.l),
          margin: const EdgeInsets.symmetric(vertical: AppSpacing.s),
          textStyle: _bodyStyle.copyWith(
            color: colors.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
        ),
        list: ListStyle(
          indent: AppSpacing.xs,
          gapAfterMarker: AppSpacing.s,
          bulletSize: 5,
          bulletColor: colors.onSurfaceVariant.withValues(alpha: 0.85),
          markerTextStyle: _bodyStyle.copyWith(
            color: colors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        hr: HrStyle(
          color: colors.outlineVariant.withValues(alpha: 0.45),
          thickness: 1,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.l),
        ),
        latex: const LatexStyle(
          padding: EdgeInsets.all(AppSpacing.m),
          scrollBlockHorizontally: true,
        ),
      ),
    );
  }

  String _processMarkdown(String text) {
    if (identical(text, _cachedOriginalText) || text == _cachedOriginalText) {
      return _cachedTransformedText;
    }
    _cachedOriginalText = text;
    _cachedTransformedText = _preprocessMathNotation(text);
    return _cachedTransformedText;
  }

  static String _preprocessMathNotation(String text) {
    if (text.isEmpty) return text;
    // 保护代码块与行内代码，仅对外部正文转换 $$...$$ 与 $...$
    final fencePattern = RegExp(r'(```[\s\S]*?```|``[\s\S]*?``|`[^`\n]*`)');
    final buffer = StringBuffer();
    var lastIndex = 0;

    for (final match in fencePattern.allMatches(text)) {
      if (match.start > lastIndex) {
        buffer.write(_convertMath(text.substring(lastIndex, match.start)));
      }
      buffer.write(match.group(0)!);
      lastIndex = match.end;
    }
    if (lastIndex < text.length) {
      buffer.write(_convertMath(text.substring(lastIndex)));
    }
    return buffer.toString();
  }

  static String _convertMath(String segment) {
    // 1. 多行/独立块公式: $$...$$ -> \n\[...\]\n
    var result = segment.replaceAllMapped(
      RegExp(r'\$\$\s*([\s\S]*?)\s*\$\$'),
      (m) => '\n\\[${m[1]?.trim()}\\]\n',
    );

    // 2. 行内公式: $...$ -> \(...\)
    // 避免误匹配普通货币符号（如 $100 and $200）
    result = result.replaceAllMapped(
      RegExp(r'(?<![\$\\])\$(?!\s)([^$\n]+?)(?<![\s\\])\$(?!\$)'),
      (m) => '\\(${m[1]}\\)',
    );

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final renderText = _processMarkdown(widget.text);

    return GptMarkdownTheme(
      gptThemeData: _markdownTheme,
      child: GptMarkdown(
        renderText,
        style: _bodyStyle,
        components: _components,
        animation: widget.streaming
            ? GptMarkdownAnimation.fade
            : GptMarkdownAnimation.none,
        charactersPerSecond: 1200,
        isStreaming: widget.streaming,
        onLinkTap: (url, _) => openExternalWebLink(context, url),
        codeBuilder: (context, language, code, closed) =>
            ChatCodeBlock(language: language, code: code, closed: closed),
        tableBuilder: (context, rows, style, config) =>
            ChatMarkdownTable(rows: rows, config: config),
        imageBuilder: (context, url, width, height) =>
            _buildMarkdownImage(context, url, width, height),
      ),
    );
  }

  static Widget _buildMarkdownImage(
    BuildContext context,
    String url,
    double? width,
    double? height,
  ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
      child: Material(
        color: colors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.controlAll,
          side: BorderSide(
            color: colors.outlineVariant.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 360),
          child: Image.network(
            url,
            width: width,
            height: height,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                height: 160,
                color: colors.surfaceContainerLow,
                alignment: Alignment.center,
                child: SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) => Container(
              height: 100,
              color: colors.surfaceContainerLow,
              alignment: Alignment.center,
              padding: const EdgeInsets.all(AppSpacing.m),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    LucideIcons.imageOff,
                    size: 20,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppSpacing.s),
                  Text(
                    '图片加载失败',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
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
      TextSpan(
        text: '\n',
        style: TextStyle(fontSize: AppSpacing.s, height: 1),
      ),
    ],
  );
}

class _ChatBlockQuote extends BlockQuote {
  static final _alertRegex = RegExp(
    r'^\[!(NOTE|TIP|IMPORTANT|WARNING|CAUTION|INFO|DANGER|ERROR)\](?:[ \t]*([^\n]*))?(?:\n([\s\S]*))?$',
    caseSensitive: false,
  );

  @override
  InlineSpan span(BuildContext context, String text, GptMarkdownConfig config) {
    final match = exp.firstMatch(text);
    final dataBuilder = StringBuffer();
    final m = match?[0] ?? '';
    for (final each in m.split('\n')) {
      if (each.startsWith(RegExp(r'\ *>'))) {
        var subString = each.trimLeft().substring(1);
        if (subString.startsWith(' ')) {
          subString = subString.substring(1);
        }
        dataBuilder.writeln(subString);
      } else {
        dataBuilder.writeln(each);
      }
    }
    final data = dataBuilder.toString().trim();
    final alertMatch = _alertRegex.firstMatch(data);

    if (alertMatch != null) {
      final typeStr = alertMatch.group(1)!;
      final customTitle = alertMatch.group(2)?.trim();
      final bodyText = alertMatch.group(3)?.trim() ?? '';
      final alertType = ChatAlertType.fromString(typeStr);

      final theme = Theme.of(context);
      final bodyStyle = theme.textTheme.bodyMedium?.copyWith(
        fontSize: 14,
        height: 1.55,
        color: theme.colorScheme.onSurface,
      );
      final bodyConfig = config.copyWith(style: bodyStyle);
      final bodyWidget = bodyText.isNotEmpty
          ? MdWidget(context, bodyText, false, config: bodyConfig)
          : null;

      final titleStyle = theme.textTheme.labelLarge?.copyWith(
        color: alertType.resolveColor(context),
        fontWeight: FontWeight.w700,
        letterSpacing: 0.1,
      );
      final titleWidget = (customTitle != null && customTitle.isNotEmpty)
          ? MdWidget(
              context,
              customTitle,
              false,
              config: config.copyWith(style: titleStyle),
            )
          : null;

      return TextSpan(
        children: [
          scaledWidgetSpan(
            config: config,
            alignment: PlaceholderAlignment.bottom,
            child: ChatMarkdownAlert(
              type: alertType,
              title: customTitle,
              titleWidget: titleWidget,
              body: bodyWidget,
            ),
          ),
        ],
      );
    }

    // 标准引用
    final theme = Theme.of(context);
    final quoteStyle = theme.textTheme.bodyMedium?.copyWith(
      fontSize: 14,
      height: 1.55,
      color: theme.colorScheme.onSurfaceVariant,
      fontStyle: FontStyle.italic,
    );
    final quoteConfig = config.copyWith(style: quoteStyle);
    final quoteWidget = MdWidget(context, data, false, config: quoteConfig);

    return TextSpan(
      children: [
        scaledWidgetSpan(
          config: config,
          alignment: PlaceholderAlignment.bottom,
          child: ChatMarkdownQuote(child: quoteWidget),
        ),
      ],
    );
  }
}

class _ChatUnorderedList extends UnOrderedList {
  static final _taskRegex = RegExp(r'^\[([ xX])\]\s+(.*)$');

  @override
  Widget build(BuildContext context, String text, GptMarkdownConfig config) {
    final match = exp.firstMatch(text);
    final rawItem = match?[1]?.trim() ?? '';
    final taskMatch = _taskRegex.firstMatch(rawItem);
    if (taskMatch != null) {
      final checked = taskMatch.group(1)!.toLowerCase() == 'x';
      final itemText = taskMatch.group(2)!.trim();
      return _TaskListItem(
        checked: checked,
        itemText: itemText,
        config: config,
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: super.build(context, text, config),
    );
  }
}

class _TaskListItem extends StatelessWidget {
  const _TaskListItem({
    required this.checked,
    required this.itemText,
    required this.config,
  });

  final bool checked;
  final String itemText;
  final GptMarkdownConfig config;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final itemStyle = (config.style ?? theme.textTheme.bodyLarge)!.copyWith(
      fontSize: 15,
      height: 1.5,
      color: checked ? colors.onSurfaceVariant : colors.onSurface,
      decoration: checked ? TextDecoration.lineThrough : null,
      decorationColor: colors.onSurfaceVariant,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 3.5, right: AppSpacing.m),
            child: AnimatedContainer(
              duration: AppMotion.effects,
              width: 17,
              height: 17,
              decoration: BoxDecoration(
                color: checked ? colors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: checked ? colors.primary : colors.outlineVariant,
                  width: 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: checked
                  ? Icon(LucideIcons.check, size: 12, color: colors.onPrimary)
                  : null,
            ),
          ),
          Expanded(
            child: MdWidget(
              context,
              itemText,
              true,
              config: config.copyWith(style: itemStyle),
            ),
          ),
        ],
      ),
    );
  }
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final sheet = resolvedStyleSheet(context, config);
    final latex = sheet.latex ?? const LatexStyle();

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
        child: Material(
          color: colors.surfaceContainerLowest,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.controlAll,
            side: BorderSide(
              color: colors.outlineVariant.withValues(alpha: 0.4),
              width: 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: ChatMarkdownScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.l,
              vertical: AppSpacing.m,
            ),
            child: Center(child: content),
          ),
        ),
      ),
    );
  }
}
