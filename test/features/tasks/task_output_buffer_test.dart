import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:phase/features/tasks/task_output_buffer.dart';

void main() {
  test('absolute cursors resume both before and after tail eviction', () {
    final buffer = TaskOutputBuffer();
    buffer.add(Uint8List.fromList(utf8.encode('abcdef')));
    final first = buffer.read(offset: 0, maxBytes: 3);
    expect(first.text, 'abc');
    expect(first.nextOffset, 3);
    expect(buffer.read(offset: first.nextOffset, maxBytes: 3).text, 'def');
    expect(buffer.read(offset: 0, maxBytes: 3).text, 'abc');
    buffer.add(
      Uint8List.fromList(List.filled(TaskOutputBuffer.retainBytes, 120)),
    );
    final old = buffer.read(offset: 0, maxBytes: 10);
    expect(old.oldestOffset, 6);
    expect(old.truncated, isTrue);
    expect(old.text, 'xxxxxxxxxx');
    expect(old.nextOffset, 16);
    final tail = buffer.read(maxBytes: 5);
    expect(tail.text, 'xxxxx');
    expect(tail.nextOffset, buffer.totalBytes);
    expect(tail.hasMore, isFalse);
    expect(buffer.bytes.length, TaskOutputBuffer.retainBytes);
  });

  test(
    'UTF-8 pages neither split a complete character nor skip unread bytes',
    () {
      final buffer = TaskOutputBuffer();
      buffer.add(Uint8List.fromList(utf8.encode('a月b')));
      final first = buffer.read(offset: 0, maxBytes: 3);
      expect(first.text, 'a');
      expect(first.nextOffset, 1);
      final second = buffer.read(offset: first.nextOffset, maxBytes: 3);
      expect(second.text, '月');
      expect(second.nextOffset, 4);
      expect(buffer.read(offset: second.nextOffset, maxBytes: 3).text, 'b');
      final restored = TaskOutputBuffer(
        retained: buffer.bytes,
        totalBytes: buffer.totalBytes,
      );
      expect(restored.read(offset: 1, maxBytes: 3).text, second.text);
    },
  );

  test('eviction inside a UTF-8 character advances to the first retained character', () {
    final buffer = TaskOutputBuffer();
    buffer.add(Uint8List.fromList(utf8.encode('月' * 90000)));
    final page = buffer.read(offset: 0, maxBytes: 12);
    expect(page.truncated, isTrue);
    expect(page.text, '月月月月');
    expect(page.text, isNot(contains('\uFFFD')));
    expect(page.nextOffset % 3, 0);
  });

  test(
    'live cursors wait for a multibyte character split across process events',
    () {
      final buffer = TaskOutputBuffer();
      final bytes = utf8.encode('月');
      buffer.add(Uint8List.fromList(bytes.sublist(0, 2)));
      final partial = buffer.read(offset: 0, finalOutput: false);
      expect(partial.text, isEmpty);
      expect(partial.nextOffset, 0);
      buffer.add(Uint8List.fromList(bytes.sublist(2)));
      final completed = buffer.read(
        offset: partial.nextOffset,
        finalOutput: false,
      );
      expect(completed.text, '月');
      expect(completed.nextOffset, 3);
    },
  );
}
