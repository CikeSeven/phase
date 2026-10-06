import 'package:flutter/material.dart';
import 'package:re_highlight/languages/bash.dart';
import 'package:re_highlight/languages/c.dart';
import 'package:re_highlight/languages/cpp.dart';
import 'package:re_highlight/languages/csharp.dart';
import 'package:re_highlight/languages/css.dart';
import 'package:re_highlight/languages/dart.dart';
import 'package:re_highlight/languages/diff.dart';
import 'package:re_highlight/languages/dockerfile.dart';
import 'package:re_highlight/languages/go.dart';
import 'package:re_highlight/languages/ini.dart';
import 'package:re_highlight/languages/java.dart';
import 'package:re_highlight/languages/javascript.dart';
import 'package:re_highlight/languages/json.dart';
import 'package:re_highlight/languages/kotlin.dart';
import 'package:re_highlight/languages/less.dart';
import 'package:re_highlight/languages/lua.dart';
import 'package:re_highlight/languages/makefile.dart';
import 'package:re_highlight/languages/markdown.dart';
import 'package:re_highlight/languages/pgsql.dart';
import 'package:re_highlight/languages/php.dart';
import 'package:re_highlight/languages/powershell.dart';
import 'package:re_highlight/languages/python.dart';
import 'package:re_highlight/languages/ruby.dart';
import 'package:re_highlight/languages/rust.dart';
import 'package:re_highlight/languages/scss.dart';
import 'package:re_highlight/languages/shell.dart';
import 'package:re_highlight/languages/sql.dart';
import 'package:re_highlight/languages/swift.dart';
import 'package:re_highlight/languages/typescript.dart';
import 'package:re_highlight/languages/xml.dart';
import 'package:re_highlight/languages/yaml.dart';
import 'package:re_highlight/re_highlight.dart';

import '../../../core/utils/logger.dart';

abstract final class ChatCodeHighlighter {
  static final _highlight = Highlight()
    ..registerLanguages({
      'bash': langBash,
      'c': langC,
      'cpp': langCpp,
      'csharp': langCsharp,
      'css': langCss,
      'dart': langDart,
      'diff': langDiff,
      'dockerfile': langDockerfile,
      'go': langGo,
      'ini': langIni,
      'java': langJava,
      'javascript': langJavascript,
      'json': langJson,
      'kotlin': langKotlin,
      'less': langLess,
      'lua': langLua,
      'makefile': langMakefile,
      'markdown': langMarkdown,
      'pgsql': langPgsql,
      'php': langPhp,
      'powershell': langPowershell,
      'python': langPython,
      'ruby': langRuby,
      'rust': langRust,
      'scss': langScss,
      'shell': langShell,
      'sql': langSql,
      'swift': langSwift,
      'typescript': langTypescript,
      'xml': langXml,
      'yaml': langYaml,
    });

  static const _aliases = <String, String>{
    'js': 'javascript',
    'jsx': 'javascript',
    'mjs': 'javascript',
    'cjs': 'javascript',
    'ts': 'typescript',
    'tsx': 'typescript',
    'mts': 'typescript',
    'cts': 'typescript',
    'py': 'python',
    'py3': 'python',
    'python3': 'python',
    'sh': 'bash',
    'shell': 'bash',
    'zsh': 'bash',
    'bash': 'bash',
    'env': 'bash',
    'html': 'xml',
    'htm': 'xml',
    'xhtml': 'xml',
    'svg': 'xml',
    'xml': 'xml',
    'yml': 'yaml',
    'yaml': 'yaml',
    'md': 'markdown',
    'markdown': 'markdown',
    'c++': 'cpp',
    'cpp': 'cpp',
    'cc': 'cpp',
    'cxx': 'cpp',
    'hpp': 'cpp',
    'h': 'c',
    'c': 'c',
    'c#': 'csharp',
    'cs': 'csharp',
    'csharp': 'csharp',
    'golang': 'go',
    'go': 'go',
    'rs': 'rust',
    'rust': 'rust',
    'rb': 'ruby',
    'ruby': 'ruby',
    'kt': 'kotlin',
    'kts': 'kotlin',
    'kotlin': 'kotlin',
    'json5': 'json',
    'jsonc': 'json',
    'json': 'json',
    'docker': 'dockerfile',
    'dockerfile': 'dockerfile',
    'ps1': 'powershell',
    'pwsh': 'powershell',
    'powershell': 'powershell',
    'make': 'makefile',
    'makefile': 'makefile',
    'patch': 'diff',
    'diff': 'diff',
    'postgres': 'pgsql',
    'postgresql': 'pgsql',
    'pgsql': 'pgsql',
    'mysql': 'sql',
    'sql': 'sql',
    'sass': 'scss',
    'scss': 'scss',
    'less': 'less',
    'ini': 'ini',
    'toml': 'ini',
    'lua': 'lua',
    'php': 'php',
    'dart': 'dart',
    'java': 'java',
    'swift': 'swift',
  };

  static String formatLanguageName(String language) {
    final clean = language.trim().toLowerCase().split(RegExp(r'\s+')).first;
    switch (clean) {
      case 'js' || 'javascript':
        return 'JavaScript';
      case 'ts' || 'typescript':
        return 'TypeScript';
      case 'jsx':
        return 'JSX';
      case 'tsx':
        return 'TSX';
      case 'py' || 'python' || 'py3' || 'python3':
        return 'Python';
      case 'dart':
        return 'Dart';
      case 'rs' || 'rust':
        return 'Rust';
      case 'go' || 'golang':
        return 'Go';
      case 'c':
        return 'C';
      case 'cpp' || 'c++' || 'cc' || 'cxx':
        return 'C++';
      case 'cs' || 'c#' || 'csharp':
        return 'C#';
      case 'java':
        return 'Java';
      case 'kt' || 'kotlin' || 'kts':
        return 'Kotlin';
      case 'swift':
        return 'Swift';
      case 'html' || 'htm':
        return 'HTML';
      case 'css':
        return 'CSS';
      case 'scss' || 'sass':
        return 'SCSS';
      case 'less':
        return 'Less';
      case 'json' || 'jsonc' || 'json5':
        return 'JSON';
      case 'yaml' || 'yml':
        return 'YAML';
      case 'md' || 'markdown':
        return 'Markdown';
      case 'sql' || 'mysql':
        return 'SQL';
      case 'pgsql' || 'postgres' || 'postgresql':
        return 'PostgreSQL';
      case 'sh' || 'bash' || 'shell' || 'zsh':
        return 'Shell';
      case 'dockerfile' || 'docker':
        return 'Dockerfile';
      case 'xml' || 'svg':
        return 'XML';
      case 'php':
        return 'PHP';
      case 'rb' || 'ruby':
        return 'Ruby';
      case 'lua':
        return 'Lua';
      case 'powershell' || 'ps1' || 'pwsh':
        return 'PowerShell';
      case 'diff' || 'patch':
        return 'Diff';
      case 'makefile' || 'make':
        return 'Makefile';
      case 'ini' || 'toml':
        return 'INI';
      default:
        if (clean.isEmpty) return '代码';
        return clean[0].toUpperCase() + clean.substring(1);
    }
  }

  static HighlightResult? parse(String language, String code) {
    var name = language.trim().toLowerCase().split(RegExp(r'\s+')).first;
    if (name.isEmpty || code.isEmpty) {
      return null;
    }
    name = _aliases[name] ?? name;
    if (_highlight.getLanguage(name) == null) {
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
