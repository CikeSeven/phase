import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

class TaskOutputPage {
  const TaskOutputPage({
    required this.text,
    required this.nextOffset,
    required this.oldestOffset,
    required this.totalBytes,
    required this.truncated,
    this.startOffset = 0,
  });
  final String text;
  final int nextOffset;
  final int oldestOffset;
  final int totalBytes;
  final bool truncated;
  final int startOffset;
  bool get hasMore => nextOffset < totalBytes;

  Map<String, dynamic> toJson() => {
    'text': text,
    'nextOffset': nextOffset,
    'oldestOffset': oldestOffset,
    'totalBytes': totalBytes,
    'truncated': truncated,
    'hasMore': hasMore,
    'offset': startOffset,
  };
}

/// Absolute byte cursors survive tail eviction; readers never consume each other's output.
class TaskOutputBuffer {
  TaskOutputBuffer({Uint8List? retained, this.totalBytes = 0}) {
    if (retained != null && retained.isNotEmpty) {
      _chunks.add(Uint8List.fromList(retained));
      _length = retained.length;
    }
  }
  static const retainBytes = 256 * 1024;
  final _chunks = ListQueue<Uint8List>();
  int totalBytes;
  int _length = 0;
  int get oldestOffset => totalBytes - _length;

  void add(Uint8List bytes) {
    if (bytes.isEmpty) return;
    _chunks.add(Uint8List.fromList(bytes));
    totalBytes += bytes.length;
    _length += bytes.length;
    while (_length > retainBytes) {
      final first = _chunks.removeFirst();
      final removed = (_length - retainBytes).clamp(0, first.length);
      _length -= removed;
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

  TaskOutputPage read({
    int? offset,
    int maxBytes = 12 * 1024,
    bool finalOutput = true,
  }) {
    final data = bytes;
    final requested = offset ?? (totalBytes - maxBytes).clamp(0, totalBytes);
    var start = (requested - oldestOffset).clamp(0, data.length);
    while (start < data.length && (data[start] & 0xc0) == 0x80) {
      start++;
    }
    var end = (start + maxBytes).clamp(start, data.length);
    while (end > start && end < data.length && (data[end] & 0xc0) == 0x80) {
      end--;
    }
    if (!finalOutput && end == data.length && end > start) {
      var lead = end - 1;
      while (lead > start && (data[lead] & 0xc0) == 0x80) {
        lead--;
      }
      final prefix = data[lead];
      final width = prefix & 0xf8 == 0xf0
          ? 4
          : prefix & 0xf0 == 0xe0
          ? 3
          : prefix & 0xe0 == 0xc0
          ? 2
          : 1;
      if (end - lead < width) end = lead;
    }
    return TaskOutputPage(
      text: utf8.decode(data.sublist(start, end), allowMalformed: true),
      nextOffset: oldestOffset + end,
      oldestOffset: oldestOffset,
      totalBytes: totalBytes,
      truncated: requested < oldestOffset || (offset == null && requested > 0),
      startOffset: oldestOffset + start,
    );
  }
}
