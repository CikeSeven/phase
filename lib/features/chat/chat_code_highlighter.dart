import 'package:flutter/material.dart';
import 'package:re_highlight/languages/bash.dart';
import 'package:re_highlight/languages/c.dart';
import 'package:re_highlight/languages/cpp.dart';
import 'package:re_highlight/languages/csharp.dart';
import 'package:re_highlight/languages/css.dart';
import 'package:re_highlight/languages/dart.dart';
import 'package:re_highlight/languages/diff.dart';
import 'package:re_highlight/languages/go.dart';
import 'package:re_highlight/languages/java.dart';
import 'package:re_highlight/languages/javascript.dart';
import 'package:re_highlight/languages/json.dart';
import 'package:re_highlight/languages/kotlin.dart';
import 'package:re_highlight/languages/markdown.dart';
import 'package:re_highlight/languages/python.dart';
import 'package:re_highlight/languages/rust.dart';
import 'package:re_highlight/languages/sql.dart';
import 'package:re_highlight/languages/swift.dart';
import 'package:re_highlight/languages/typescript.dart';
import 'package:re_highlight/languages/xml.dart';
import 'package:re_highlight/languages/yaml.dart';
import 'package:re_highlight/re_highlight.dart';

import '../../../core/utils/logger.dart';

abstract final class ChatCodeHighlighter {
  // 只注册常用语法；别名交给语法定义，不对未知语言运行全库自动检测。
  static final _highlight = Highlight()
    ..registerLanguages({
      'bash': langBash,
      'c': langC,
      'cpp': langCpp,
      'csharp': langCsharp,
      'css': langCss,
      'dart': langDart,
      'diff': langDiff,
      'go': langGo,
      'java': langJava,
      'javascript': langJavascript,
      'json': langJson,
      'kotlin': langKotlin,
      'markdown': langMarkdown,
      'python': langPython,
      'rust': langRust,
      'sql': langSql,
      'swift': langSwift,
      'typescript': langTypescript,
      'xml': langXml,
      'yaml': langYaml,
    });

  static HighlightResult? parse(String language, String code) {
    final name = language.trim().toLowerCase().split(RegExp(r'\s+')).first;
    if (name.isEmpty || code.isEmpty || _highlight.getLanguage(name) == null) {
      return null;
    }
    try {
      return _highlight.highlight(code: code, language: name);
    } catch (_) {
      // 语法着色失败不能阻止阅读；不记录可能包含用户数据的异常和代码。
      AppLogger.warning('Markdown code highlighting failed.');
      return null;
    }
  }

  static TextSpan render(
    BuildContext context,
    HighlightResult? result,
    String code,
    TextStyle style,
  ) {
    if (result == null) return TextSpan(text: code, style: style);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    // 语法色独立于柔和的品牌色面，在代码卡片底色上保持对比与色相区分。
    final keyword = TextStyle(
      color: dark ? const Color(0xFFC792EA) : const Color(0xFF8A269D),
      fontWeight: FontWeight.w600,
    );
    final string = TextStyle(
      color: dark ? const Color(0xFF8FDBA2) : const Color(0xFF19713B),
    );
    final number = TextStyle(
      color: dark ? const Color(0xFFFFB86B) : const Color(0xFFAC4B16),
    );
    final type = TextStyle(
      color: dark ? const Color(0xFFF4D17C) : const Color(0xFF875600),
    );
    final title = TextStyle(
      color: dark ? const Color(0xFF82AAFF) : const Color(0xFF145BBD),
      fontWeight: FontWeight.w600,
    );
    final property = TextStyle(
      color: dark ? const Color(0xFF79DCE8) : const Color(0xFF086D83),
    );
    final comment = TextStyle(
      color: dark ? const Color(0xFF91A4BE) : const Color(0xFF586B84),
      fontStyle: FontStyle.italic,
    );
    try {
      final renderer = TextSpanRenderer(style, {
        'keyword': keyword,
        'selector-tag': keyword,
        'selector-id': title,
        'selector-class': title,
        'selector-attr': property,
        'selector-pseudo': keyword,
        'tag': keyword,
        'name': keyword,
        'meta': keyword,
        'doctag': keyword,
        'string': string,
        'regexp': string,
        'addition': string,
        'number': number,
        'literal': number,
        'symbol': number,
        'type': type,
        'built_in': type,
        'title': title,
        'title.class': type,
        'title.class.inherited': type,
        'title.function': title,
        'title.function.invoke': title,
        'attr': property,
        'attribute': property,
        'property': property,
        'variable': property,
        'variable.language': keyword,
        'variable.constant': number,
        'operator': keyword,
        'punctuation': TextStyle(color: colors.onSurfaceVariant),
        'comment': comment,
        'quote': comment,
        'deletion': TextStyle(color: colors.error),
        'strong': const TextStyle(fontWeight: FontWeight.w700),
        'emphasis': const TextStyle(fontStyle: FontStyle.italic),
      });
      result.render(renderer);
      return renderer.span ?? TextSpan(text: code, style: style);
    } catch (_) {
      AppLogger.warning('Markdown code coloring failed.');
      return TextSpan(text: code, style: style);
    }
  }
}
