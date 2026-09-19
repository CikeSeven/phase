import 'dart:typed_data';

enum ToolDiffKind { context, added, removed, separator }

class ToolDiffLine {
  const ToolDiffLine(this.kind, this.text);

  final ToolDiffKind kind;
  final String text;

  String get display =>
      '${switch (kind) {
        ToolDiffKind.added => '+ ',
        ToolDiffKind.removed => '- ',
        ToolDiffKind.context => '  ',
        ToolDiffKind.separator => '',
      }}${text.endsWith('\n') ? text.substring(0, text.length - 1) : text}';
}

/// 调用记录只包含替换片段，不虚构它们在文件中的绝对行号。
List<ToolDiffLine> toolEditDiff(List<Map<String, dynamic>> edits) => [
  for (var i = 0; i < edits.length; i++) ...[
    if (i > 0) const ToolDiffLine(ToolDiffKind.separator, '⋯'),
    ..._diff(edits[i]['oldText'] as String, edits[i]['newText'] as String),
  ],
];

List<ToolDiffLine> toolWriteDiff(String content) => [
  for (final line in _lines(content)) ToolDiffLine(ToolDiffKind.added, line),
];

List<String> _lines(String text) {
  if (text.isEmpty) return const [];
  final lines = text.replaceAll('\r\n', '\n').split('\n');
  return [
    for (var i = 0; i < lines.length; i++)
      if (i < lines.length - 1)
        '${lines[i]}\n'
      else if (lines[i].isNotEmpty)
        lines[i],
  ];
}

List<ToolDiffLine> _diff(String before, String after) {
  final oldLines = _lines(before);
  final newLines = _lines(after);
  var start = 0;
  while (start < oldLines.length &&
      start < newLines.length &&
      oldLines[start] == newLines[start]) {
    start++;
  }
  var oldEnd = oldLines.length;
  var newEnd = newLines.length;
  while (oldEnd > start &&
      newEnd > start &&
      oldLines[oldEnd - 1] == newLines[newEnd - 1]) {
    oldEnd--;
    newEnd--;
  }
  final result = <ToolDiffLine>[
    for (var i = 0; i < start; i++)
      ToolDiffLine(ToolDiffKind.context, oldLines[i]),
  ];
  final oldCount = oldEnd - start;
  final newCount = newEnd - start;
  // 限制比较矩阵；大段替换保留完整删除/新增内容，避免阻塞聊天渲染。
  if ((oldCount + 1) * (newCount + 1) > 250000) {
    result.addAll([
      for (var i = start; i < oldEnd; i++)
        ToolDiffLine(ToolDiffKind.removed, oldLines[i]),
      for (var i = start; i < newEnd; i++)
        ToolDiffLine(ToolDiffKind.added, newLines[i]),
    ]);
  } else {
    final width = newCount + 1;
    final lengths = Uint32List((oldCount + 1) * width);
    for (var i = oldCount - 1; i >= 0; i--) {
      for (var j = newCount - 1; j >= 0; j--) {
        final down = lengths[(i + 1) * width + j];
        final right = lengths[i * width + j + 1];
        lengths[i * width + j] = oldLines[start + i] == newLines[start + j]
            ? lengths[(i + 1) * width + j + 1] + 1
            : (down > right ? down : right);
      }
    }
    var i = 0;
    var j = 0;
    while (i < oldCount || j < newCount) {
      if (i < oldCount &&
          j < newCount &&
          oldLines[start + i] == newLines[start + j]) {
        result.add(ToolDiffLine(ToolDiffKind.context, oldLines[start + i++]));
        j++;
      } else if (i < oldCount &&
          (j == newCount ||
              lengths[(i + 1) * width + j] >= lengths[i * width + j + 1])) {
        result.add(ToolDiffLine(ToolDiffKind.removed, oldLines[start + i++]));
      } else {
        result.add(ToolDiffLine(ToolDiffKind.added, newLines[start + j++]));
      }
    }
  }
  result.addAll([
    for (var i = oldEnd; i < oldLines.length; i++)
      ToolDiffLine(ToolDiffKind.context, oldLines[i]),
  ]);
  return result;
}
