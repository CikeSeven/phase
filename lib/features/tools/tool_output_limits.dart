import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

abstract final class ToolOutputLimits {
  static const maxBytes = 50 * 1024;
  static const maxLines = 2000;
  static const grepLineCharacters = 500;
}

class ToolTextPreview {
  const ToolTextPreview(this.text, {required this.truncated});
  final String text;
  final bool truncated;
}

ToolTextPreview truncateToolText(
  String text, {
  bool tail = false,
  int maxBytes = ToolOutputLimits.maxBytes,
  int maxLines = ToolOutputLimits.maxLines,
}) {
  if (maxBytes <= 0 || maxLines <= 0) {
    return ToolTextPreview('', truncated: text.isNotEmpty);
  }
  final lines = text.split('\n');
  if (lines.last.isEmpty) lines.removeLast();
  if (lines.length <= maxLines && utf8.encode(text).length <= maxBytes) {
    return ToolTextPreview(text, truncated: false);
  }
  final selected = <String>[];
  var bytes = 0;
  for (final line in tail ? lines.reversed : lines) {
    final size = utf8.encode(line).length + (selected.isEmpty ? 0 : 1);
    if (selected.length == maxLines || bytes + size > maxBytes) break;
    selected.add(line);
    bytes += size;
  }
  if (selected.isEmpty && tail && lines.isNotEmpty) {
    final encoded = utf8.encode(lines.last);
    var start = (encoded.length - maxBytes).clamp(0, encoded.length);
    while (start < encoded.length && (encoded[start] & 0xc0) == 0x80) {
      start++;
    }
    return ToolTextPreview(
      utf8.decode(encoded.sublist(start)),
      truncated: true,
    );
  }
  return ToolTextPreview(
    (tail ? selected.reversed : selected).join('\n'),
    truncated: true,
  );
}

/// Keep the bounded tail in memory; callers persist overflow before appending.
class ToolOutputTail {
  final _chunks = ListQueue<Uint8List>();
  var _length = 0;
  var _startsMidLine = false;
  int totalBytes = 0;
  int totalLines = 0;
  int? _lastByte;
  int get lineCount =>
      totalLines + (_lastByte == null || _lastByte == 10 ? 0 : 1);

  void add(Uint8List bytes) {
    if (bytes.isEmpty) return;
    totalBytes += bytes.length;
    totalLines += bytes.where((byte) => byte == 10).length;
    _lastByte = bytes.last;
    _chunks.add(Uint8List.fromList(bytes));
    _length += bytes.length;
    var excess = _length - ToolOutputLimits.maxBytes;
    while (excess > 0) {
      final first = _chunks.removeFirst();
      final removed = excess.clamp(0, first.length);
      _startsMidLine = first[removed - 1] != 10;
      _length -= removed;
      excess -= removed;
      if (removed < first.length) {
        _chunks.addFirst(Uint8List.sublistView(first, removed));
      }
    }
  }

  Uint8List get bytes {
    final builder = BytesBuilder(copy: false);
    for (final chunk in _chunks) {
      builder.add(chunk);
    }
    return builder.takeBytes();
  }

  ToolTextPreview get preview {
    final buffered = bytes;
    var start = 0;
    while (start < buffered.length && (buffered[start] & 0xc0) == 0x80) {
      start++;
    }
    if (_startsMidLine) {
      final newline = buffered.indexOf(10, start);
      if (newline >= 0 && newline + 1 < buffered.length) start = newline + 1;
    }
    final text = utf8.decode(buffered.sublist(start), allowMalformed: true);
    final result = truncateToolText(text, tail: true);
    return ToolTextPreview(
      result.text,
      truncated:
          result.truncated ||
          totalBytes > buffered.length ||
          lineCount > ToolOutputLimits.maxLines,
    );
  }
}
