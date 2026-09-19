import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import 'tool_diff.dart';

/// 整行背景区分增删；同类连续行合并排版，长文件不创建逐行 Widget。
class ToolDiffView extends StatelessWidget {
  const ToolDiffView({required this.lines, super.key});

  final List<ToolDiffLine> lines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
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
                dark ? const Color(0xFF26332D) : const Color(0xFFEBF2ED),
              ToolDiffKind.removed =>
                dark ? const Color(0xFF382C2D) : const Color(0xFFF5EEEE),
              _ => Colors.transparent,
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s),
              child: Text(
                groups[i].text,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  color: theme.colorScheme.onSurface,
                  height: 1.6,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
