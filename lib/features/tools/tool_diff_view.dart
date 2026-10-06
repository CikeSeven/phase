import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import '../../../core/theme/app_spacing.dart';
import '../chat/chat_code_highlighter.dart';
import 'tool_card.dart';
import 'tool_diff.dart';

/// 整行背景区分增删；同类连续行合并排版，支持代码语法高亮。
class ToolDiffView extends StatelessWidget {
  const ToolDiffView({required this.lines, this.language, super.key});

  final List<ToolDiffLine> lines;
  final String? language;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final colors = theme.colorScheme;
    final groups = <({ToolDiffKind kind, String text})>[];
    for (var i = 0; i < lines.length;) {
      final kind = lines[i].kind;
      final text = <String>[];
      do {
        final line = lines[i++];
        text.add(line.display);
        if (kind != ToolDiffKind.separator && !line.text.endsWith('\n')) {
          text.add(r'\ 无末尾换行');
        }
      } while (i < lines.length && lines[i].kind == kind);
      groups.add((kind: kind, text: text.join('\n')));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < groups.length; i++)
          ColoredBox(
            key: ValueKey('diff-${groups[i].kind.name}-$i'),
            color: switch (groups[i].kind) {
              ToolDiffKind.added =>
                dark ? const Color(0xFF10281B) : const Color(0xFFE6F6ED),
              ToolDiffKind.removed =>
                dark ? const Color(0xFF331419) : const Color(0xFFFDE8E8),
              _ => Colors.transparent,
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s,
                vertical: 2,
              ),
              child: () {
                final groupText = groups[i].text;
                final baseColor = switch (groups[i].kind) {
                  ToolDiffKind.added =>
                    dark ? const Color(0xFF7EE787) : const Color(0xFF146C36),
                  ToolDiffKind.removed =>
                    dark ? const Color(0xFFFFA198) : const Color(0xFF991B1B),
                  _ => colors.onSurface,
                };
                final baseStyle = theme.textTheme.bodySmall?.copyWith(
                  fontFamily: kGptMarkdownMonoFontFamily,
                  package: kGptMarkdownFontPackage,
                  fontSize: 13,
                  fontWeight: groups[i].kind != ToolDiffKind.context
                      ? FontWeight.w500
                      : FontWeight.w400,
                  color: baseColor,
                  height: 1.6,
                );
                final parsed = ChatCodeHighlighter.parse(
                  language ?? 'diff',
                  groupText,
                );
                final span = ChatCodeHighlighter.render(
                  context,
                  parsed,
                  groupText,
                  baseStyle!,
                );
                return HighlightedCodeText(
                  groupText,
                  highlightSpan: span,
                  style: baseStyle,
                );
              }(),
            ),
          ),
      ],
    );
  }
}
