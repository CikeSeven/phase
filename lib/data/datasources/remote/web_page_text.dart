import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;

/// 用真实 DOM 清洗网页，仅提取可读内容；不把脚本、隐藏文本或表单交给模型。
({String content, String? title, bool truncated}) webPageText(
  String source,
  Uri uri,
  int maxCharacters,
) {
  final document = html.parse(source);
  final title = document.querySelector('title')?.text.trim();
  for (final element in document.querySelectorAll(
    'script, style, noscript, template, iframe, object, embed, svg, canvas, '
    'form, input, button, select, textarea, nav, footer, header, '
    '[hidden], [inert], [aria-hidden="true"]',
  )) {
    element.remove();
  }
  final hiddenStyle = RegExp(
    r'(display\s*:\s*none|visibility\s*:\s*hidden)',
    caseSensitive: false,
  );
  for (final element in document.querySelectorAll('[style]')) {
    if (hiddenStyle.hasMatch(element.attributes['style'] ?? '')) {
      element.remove();
    }
  }
  final root =
      document.querySelector('main') ??
      document.querySelector('article') ??
      document.body;
  final renderer = _WebTextRenderer(uri, maxCharacters);
  if (root != null) renderer.node(root, 0);
  final raw = renderer.output
      .toString()
      .replaceAll(RegExp(r'\n[ \t]+'), '\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
  return (
    content: clipWebText(raw, maxCharacters),
    title: title == null || title.isEmpty ? null : clipWebText(title, 400),
    truncated: renderer.truncated || raw.length > maxCharacters,
  );
}

String clipWebText(String value, int maxCharacters) {
  if (value.length <= maxCharacters) return value;
  var end = maxCharacters;
  if (end > 0 &&
      value.codeUnitAt(end - 1) >= 0xd800 &&
      value.codeUnitAt(end - 1) <= 0xdbff) {
    end--;
  }
  return value.substring(0, end);
}

class _WebTextRenderer {
  _WebTextRenderer(this.uri, this.limit);
  final Uri uri;
  final int limit;
  final output = StringBuffer();
  bool truncated = false;
  int _visited = 0;

  void add(String value) {
    final remaining = limit + 2048 - output.length;
    if (remaining <= 0) {
      truncated = true;
      return;
    }
    output.write(clipWebText(value, remaining));
    if (value.length > remaining) truncated = true;
  }

  void node(Node value, int depth) {
    if (truncated) return;
    if (++_visited > 100000 || depth > 80) {
      truncated = true;
      return;
    }
    if (value is Text) {
      add(value.data.replaceAll(RegExp(r'\s+'), ' '));
      return;
    }
    if (value is! Element) return;
    final tag = value.localName ?? '';
    if (tag == 'br') {
      add('\n');
      return;
    }
    if (tag == 'hr') {
      add('\n\n---\n\n');
      return;
    }
    if (tag == 'img') {
      final alt = value.attributes['alt'];
      if (alt != null && alt.isNotEmpty) add(alt);
      return;
    }
    if (tag == 'pre') {
      final code = value.text;
      final runs = RegExp(r'`+').allMatches(code);
      var fenceLength = 3;
      for (final run in runs) {
        if (run.end - run.start >= fenceLength) {
          fenceLength = run.end - run.start + 1;
        }
      }
      final fence = '`' * fenceLength;
      add('\n\n$fence\n$code\n$fence\n\n');
      return;
    }
    if (tag == 'table') {
      final rows = value.querySelectorAll('tr');
      for (final (index, row) in rows.indexed) {
        final cells = row.children
            .where((cell) => cell.localName == 'td' || cell.localName == 'th')
            .toList();
        if (cells.isEmpty) continue;
        add(
          '\n| ${cells.map((cell) => cell.text.trim().replaceAll(RegExp(r'\s+'), ' ').replaceAll('|', r'\|')).join(' | ')} |',
        );
        if (index == 0) {
          add('\n| ${List.filled(cells.length, '---').join(' | ')} |');
        }
      }
      add('\n\n');
      return;
    }
    if (tag == 'a') {
      final href = value.attributes['href'];
      final label = value.text
          .trim()
          .replaceAll(RegExp(r'\s+'), ' ')
          .replaceAll('[', r'\[')
          .replaceAll(']', r'\]');
      final target = href == null ? null : uri.resolve(href);
      if (target != null &&
          const {'https', 'http'}.contains(target.scheme) &&
          target.userInfo.isEmpty &&
          label.isNotEmpty) {
        add('[$label](<${target.toString().replaceAll('>', '%3E')}>)');
      } else {
        add(label);
      }
      return;
    }
    final block = const {
      'p',
      'div',
      'section',
      'article',
      'main',
      'ul',
      'ol',
      'blockquote',
      'dl',
      'dt',
      'dd',
    }.contains(tag);
    final heading = RegExp(r'^h[1-6]$').hasMatch(tag);
    if (block || heading) add('\n\n');
    if (heading) add('${'#' * int.parse(tag.substring(1))} ');
    if (tag == 'li') {
      final parent = value.parent;
      final ordinal =
          parent?.children
              .where((item) => item.localName == 'li')
              .toList()
              .indexOf(value) ??
          0;
      add(parent?.localName == 'ol' ? '\n${ordinal + 1}. ' : '\n- ');
    }
    if (tag == 'code') add('`');
    for (final child in value.nodes) {
      node(child, depth + 1);
      if (truncated) break;
    }
    if (tag == 'code') add('`');
    if (block || heading) add('\n\n');
  }
}
