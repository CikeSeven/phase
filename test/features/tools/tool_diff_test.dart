import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase/features/tools/tool_card.dart';
import 'package:phase/features/tools/tool_diff.dart';
import 'package:phase/features/tools/tool_diff_view.dart';

void main() {
  test('编辑 diff 对齐上下文、删除和新增，而非重复整段旧新文本', () {
    final diff = toolEditDiff([
      {'oldText': 'first\nold\nlast\n', 'newText': 'first\nnew\nlast\n'},
    ]);
    expect(diff.map((l) => (l.kind, l.text)), [
      (ToolDiffKind.context, 'first\n'),
      (ToolDiffKind.removed, 'old\n'),
      (ToolDiffKind.added, 'new\n'),
      (ToolDiffKind.context, 'last\n'),
    ]);
  });

  for (final (before, after) in [
    ('a\na\nb\n', 'a\nb\na\n'),
    ('a\nb\nc\n', 'a\nx\nb\ny\nc\n'),
    ('一\n二\n三', '一\n三'),
    ('', '新增\n'),
    ('删除\n', ''),
    ('空行\n\n', '空行\n'),
    ('final', 'final\n'),
    ('same\n', 'same\n'),
    ('原文\n' * 600, '新文\n' * 600),
  ]) {
    test('diff 保留完整两侧内容（${before.length}/${after.length}）', () {
      final diff = toolEditDiff([
        {'oldText': before, 'newText': after},
      ]);
      expect(
        diff
            .where((l) => l.kind != ToolDiffKind.added)
            .map((l) => l.text)
            .join(),
        before,
      );
      expect(
        diff
            .where((l) => l.kind != ToolDiffKind.removed)
            .map((l) => l.text)
            .join(),
        after,
      );
    });
  }

  test('新建内容全为新增，空内容不伪造一行', () {
    final diff = toolWriteDiff('第一行\n\n第三行\n');
    expect(diff.map((l) => (l.kind, l.text)), [
      (ToolDiffKind.added, '第一行\n'),
      (ToolDiffKind.added, '\n'),
      (ToolDiffKind.added, '第三行\n'),
    ]);
    expect(toolWriteDiff(''), isEmpty);
  });

  testWidgets('ToolDiffView 在指定语言下能正确生成语法高亮 span', (tester) async {
    final diff = toolWriteDiff('class Foo {\n  final int x = 1;\n}\n');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ToolDiffView(lines: diff, language: 'dart'),
        ),
      ),
    );
    final highlightedFinder = find.byType(HighlightedCodeText);
    expect(highlightedFinder, findsWidgets);
    final widget = tester.widget<HighlightedCodeText>(highlightedFinder.first);
    expect(widget.highlightSpan, isA<TextSpan>());
    final span = widget.highlightSpan as TextSpan;
    expect(span.children, isNotEmpty);
    final hasColor = span.children!.any((c) => c.style?.color != null);
    expect(hasColor, isTrue);
  });
}
