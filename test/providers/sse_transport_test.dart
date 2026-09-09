import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:phase/providers/sse_transport.dart';

void main() {
  test('多行 data 按 SSE event 合并，忽略注释与 event/id/retry', () async {
    const text =
        ': keep-alive\r\n'
        'event: response.completed\r\n'
        'id: 10\r\n'
        'retry: 1000\r\n'
        'data: {"type":"response.completed",\r\n'
        ': comment inside event\r\n'
        'data:  "response":{"output":[]}}\r\n\r\n';
    expect(await _decode(text), [
      '{"type":"response.completed",\n "response":{"output":[]}}',
    ]);
  });

  test('接受无空格 data 和无空行但完整 JSON 的旧式事件', () async {
    expect(await _decode('data:{"a":1}\ndata: {"b":2}\ndata:[DONE]\n'), [
      '{"a":1}',
      '{"b":2}',
      '[DONE]',
    ]);
  });

  test('合法多行嵌套 JSON 的末行独立有效也不能被拆为另一事件', () async {
    expect(await _decode('data:{"response":\ndata:{"output":[]}\ndata:}\n\n'), [
      '{"response":\n{"output":[]}\n}',
    ]);
  });

  test('畸形截断事件后仍识别 DONE，而不是把终止标记拼进 JSON', () async {
    expect(await _decode('data:{"unfinished":\ndata:[DONE]\n\n'), [
      '{"unfinished":',
      '[DONE]',
    ]);
  });

  test('逐字节 UTF8 网络分片不能成为事件边界', () async {
    const text =
        'data:{"text":"中文🌙",\n'
        'data:"done":true}\n\n';
    expect(
      await decodeSseDataLines(
        Stream.fromIterable(utf8.encode(text).map((byte) => [byte])),
      ).toList(),
      ['{"text":"中文🌙",\n"done":true}'],
    );
  });

  test('EOF 保留最后事件，畸形 data 不吞后续完整事件', () async {
    expect(await _decode('data:{broken}\ndata:{"ok":true}'), [
      '{broken}',
      '{"ok":true}',
    ]);
  });

  test('不等待网络流关闭即可交付完整 data 行，取消继续传回源流', () async {
    var cancelled = false;
    final source = StreamController<List<int>>(
      onCancel: () => cancelled = true,
    );
    final received = Completer<String>();
    final subscription = decodeSseDataLines(source.stream)
        .listen(received.complete);
    source.add(utf8.encode('data:{"text":"即时"}\n'));
    expect(await received.future, '{"text":"即时"}');
    await subscription.cancel();
    expect(cancelled, isTrue);
    await source.close();
  });
}

Future<List<String>> _decode(String text) =>
    decodeSseDataLines(Stream.value(utf8.encode(text))).toList();
