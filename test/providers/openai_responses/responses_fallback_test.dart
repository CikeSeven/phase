import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/error/failure.dart';
import 'package:phase/data/models/chat_chunk.dart';
import 'package:phase/providers/openai_responses/responses_decoder.dart';

void main() {
  group('Responses 公开文本终态后备', () {
    for (final type in [
      'response.reasoning_summary_text.done',
      'response.reasoning_text.done',
    ]) {
      test('$type 没有 delta 也输出公开思考', () async {
        final chunks = await _decode([
          {'type': type, 'item_id': 'r1', 'output_index': 0, 'text': '公开摘要'},
        ]);
        expect(_reasoning(chunks), '公开摘要');
        expect(chunks.any((chunk) => chunk.done), isFalse);
        expect(
          ResponsesSseDecoder.parseEvent(
            jsonEncode({'type': type, 'text': '摘要'}),
          )?.reasoningDelta,
          '摘要',
        );
      });
    }

    test('reasoning_summary_part.done 没有 delta 也输出公开思考', () async {
      final chunks = await _decode([
        {
          'type': 'response.reasoning_summary_part.done',
          'item_id': 'r1',
          'output_index': 0,
          'summary_index': 0,
          'part': {'type': 'summary_text', 'text': '公开摘要'},
        },
      ]);
      expect(_reasoning(chunks), '公开摘要');
    });

    test('output_item.done 接收 summary 与公开 reasoning/text content', () async {
      final chunks = await _decode([
        {
          'type': 'response.output_item.done',
          'output_index': 0,
          'item': {
            'id': 'r1',
            'type': 'reasoning',
            'summary': [
              {'type': 'summary_text', 'text': '摘要一'},
              {'type': 'summary_text', 'text': '摘要二'},
            ],
            'content': [
              {'type': 'reasoning_text', 'text': '公开推理'},
              {'type': 'text', 'text': '公开补充'},
            ],
          },
        },
      ]);
      expect(_reasoning(chunks), '摘要一\n\n摘要二\n\n公开推理\n\n公开补充');
      expect(_body(chunks), isEmpty);
    });

    for (final type in ['response.completed', 'response.incomplete']) {
      test('$type 从 response.output 后备正文与思考并保留 usage', () async {
        final chunks = await _decode([
          {
            'type': type,
            'response': {
              'output': [
                {
                  'id': 'r1',
                  'type': 'reasoning',
                  'summary': [
                    {'type': 'summary_text', 'text': '公开摘要'},
                  ],
                },
                {
                  'id': 'm1',
                  'type': 'message',
                  'content': [
                    {'type': 'output_text', 'text': '正文'},
                    {'type': 'output_text', 'text': '第二段'},
                  ],
                },
              ],
              'usage': {
                'input_tokens': 2,
                'output_tokens': 3,
                'total_tokens': 5,
              },
            },
          },
        ]);
        expect(_reasoning(chunks), '公开摘要');
        expect(_body(chunks), '正文\n\n第二段');
        expect(chunks.last.done, isTrue);
        expect(chunks.last.usage?.totalTokens, 5);
      });
    }

    test('正文的 text.done 和 content_part.done 按相同前缀补齐', () async {
      final chunks = await _decode([
        {
          'type': 'response.output_text.delta',
          'item_id': 'm1',
          'output_index': 1,
          'content_index': 0,
          'delta': '正',
        },
        {
          'type': 'response.output_text.done',
          'item_id': 'm1',
          'content_index': 0,
          'text': '正文',
        },
        {
          'type': 'response.content_part.done',
          'output_index': 1,
          'content_index': 0,
          'part': {'type': 'output_text', 'text': '正文'},
        },
      ]);
      expect(_body(chunks), '正文');
    });
  });

  group('Responses 按 item、channel、part 去重', () {
    test('delta、text.done、part.done、item.done、completed 不重放已发前缀', () async {
      final item = {
        'id': 'r1',
        'type': 'reasoning',
        'summary': [
          {'type': 'summary_text', 'text': '先检查输入。'},
        ],
      };
      final chunks = await _decode([
        {
          'type': 'response.reasoning_summary_text.delta',
          'item_id': 'r1',
          'output_index': 0,
          'summary_index': 0,
          'delta': '先检查',
        },
        {
          'type': 'response.reasoning_summary_text.done',
          'item_id': 'r1',
          'summary_index': 0,
          'text': '先检查输入',
        },
        {
          'type': 'response.reasoning_summary_part.done',
          'output_index': 0,
          'summary_index': 0,
          'part': {'type': 'summary_text', 'text': '先检查输入。'},
        },
        {'type': 'response.output_item.done', 'output_index': 0, 'item': item},
        {
          'type': 'response.completed',
          'response': {
            'output': [item],
          },
        },
      ]);
      expect(_reasoning(chunks), '先检查输入。');
      expect(chunks.last.done, isTrue);
    });

    test('不同 item 通过 id 与 index 链接且不吞新的 summary parts', () async {
      final chunks = await _decode([
        {
          'type': 'response.reasoning_summary_text.delta',
          'output_index': 0,
          'summary_index': 0,
          'delta': '第一',
        },
        {
          'type': 'response.output_item.added',
          'output_index': 0,
          'item': {'id': 'r1', 'type': 'reasoning'},
        },
        {
          'type': 'response.reasoning_summary_text.done',
          'item_id': 'r1',
          'summary_index': 0,
          'text': '第一项',
        },
        {
          'type': 'response.reasoning_summary_text.done',
          'item_id': 'r1',
          'summary_index': 1,
          'text': '同项第二段',
        },
        {
          'type': 'response.reasoning_summary_text.delta',
          'item_id': 'r2',
          'summary_index': 0,
          'delta': '第二',
        },
        {
          'type': 'response.output_item.done',
          'output_index': 2,
          'item': {
            'id': 'r2',
            'type': 'reasoning',
            'summary': [
              {'type': 'summary_text', 'text': '第二项'},
            ],
          },
        },
        {
          'type': 'response.reasoning_summary_text.done',
          'output_index': 2,
          'summary_index': 0,
          'text': '第二项',
        },
      ]);
      expect(_reasoning(chunks), '第一项\n\n同项第二段\n\n第二项');
    });

    test('summary_index 与 content_index 不互相去重，正文独立', () async {
      final chunks = await _decode([
        {
          'type': 'response.reasoning_summary_text.delta',
          'item_id': 'r1',
          'output_index': 0,
          'summary_index': 0,
          'delta': '同文',
        },
        {
          'type': 'response.reasoning_text.done',
          'item_id': 'r1',
          'content_index': 0,
          'text': '同文',
        },
        {
          'type': 'response.output_text.done',
          'item_id': 'm1',
          'output_index': 1,
          'content_index': 0,
          'text': '同文',
        },
      ]);
      expect(_reasoning(chunks), '同文\n\n同文');
      expect(_body(chunks), '同文');
    });

    test('不一致和更短快照不被错误拼到增量后，新段依旧可见', () async {
      final chunks = await _decode([
        {
          'type': 'response.reasoning_summary_text.delta',
          'item_id': 'r1',
          'summary_index': 0,
          'delta': '原文',
        },
        {
          'type': 'response.reasoning_summary_text.done',
          'item_id': 'r1',
          'summary_index': 0,
          'text': '改写全文',
        },
        {
          'type': 'response.reasoning_summary_text.done',
          'item_id': 'r1',
          'summary_index': 0,
          'text': '原',
        },
        {
          'type': 'response.reasoning_summary_part.done',
          'item_id': 'r1',
          'summary_index': 1,
          'part': {'type': 'summary_text', 'text': '新段'},
        },
      ]);
      expect(_reasoning(chunks), '原文\n\n新段');
    });

    test('先到的高 index part 等待低 index 完成，保持段落顺序', () async {
      final chunks = await _decode([
        {
          'type': 'response.reasoning_summary_text.done',
          'item_id': 'r1',
          'summary_index': 1,
          'text': '第二段',
        },
        {
          'type': 'response.reasoning_summary_text.delta',
          'item_id': 'r1',
          'summary_index': 0,
          'delta': '第一',
        },
        {
          'type': 'response.reasoning_summary_text.done',
          'item_id': 'r1',
          'summary_index': 0,
          'text': '第一段',
        },
      ]);
      expect(_reasoning(chunks), '第一段\n\n第二段');
    });

    test('后到的 summary channel 与新 item 不会被已发 reasoning 吞掉', () async {
      final chunks = await _decode([
        {
          'type': 'response.reasoning_text.done',
          'item_id': 'r1',
          'output_index': 0,
          'content_index': 0,
          'text': '公开推理',
        },
        {
          'type': 'response.reasoning_summary_text.done',
          'item_id': 'r1',
          'summary_index': 0,
          'text': '后到摘要',
        },
        {
          'type': 'response.reasoning_summary_text.done',
          'item_id': 'r2',
          'output_index': 2,
          'summary_index': 0,
          'text': '另一项',
        },
      ]);
      expect(_reasoning(chunks), '公开推理\n\n后到摘要\n\n另一项');
    });

    test('只有部分身份的 metadata 后续链接到同一 item', () async {
      final chunks = await _decode([
        {'type': 'response.output_item.added', 'output_index': 0},
        {
          'type': 'response.reasoning_summary_text.delta',
          'item_id': 'r1',
          'summary_index': 0,
          'delta': '摘要',
        },
        {
          'type': 'response.output_item.done',
          'output_index': 0,
          'item': {
            'id': 'r1',
            'type': 'reasoning',
            'summary': [
              {'type': 'summary_text', 'text': '摘要全文'},
            ],
          },
        },
        {
          'type': 'response.reasoning_summary_text.done',
          'output_index': 0,
          'summary_index': 0,
          'text': '摘要全文',
        },
      ]);
      expect(_reasoning(chunks), '摘要全文');
    });

    test('更短旧快照后的一致全文仍可补齐缺失后缀', () async {
      final chunks = await _decode([
        {
          'type': 'response.reasoning_summary_text.delta',
          'item_id': 'r1',
          'summary_index': 0,
          'delta': '摘要',
        },
        {
          'type': 'response.reasoning_summary_text.done',
          'item_id': 'r1',
          'summary_index': 0,
          'text': '摘',
        },
        {
          'type': 'response.reasoning_summary_text.done',
          'item_id': 'r1',
          'summary_index': 0,
          'text': '摘要全文',
        },
      ]);
      expect(_reasoning(chunks), '摘要全文');
    });

    test('旧段晚到的扩展快照不能错插到后续段后面，新段仍可追加', () async {
      final chunks = await _decode([
        {
          'type': 'response.reasoning_summary_text.done',
          'item_id': 'r1',
          'summary_index': 0,
          'text': '第一段',
        },
        {
          'type': 'response.reasoning_summary_text.done',
          'item_id': 'r1',
          'summary_index': 1,
          'text': '第二段',
        },
        {
          'type': 'response.output_item.done',
          'output_index': 0,
          'item': {
            'id': 'r1',
            'type': 'reasoning',
            'summary': [
              {'type': 'summary_text', 'text': '第一段的晚到修订'},
              {'type': 'summary_text', 'text': '第二段'},
              {'type': 'summary_text', 'text': '第三段'},
            ],
          },
        },
      ]);
      expect(_reasoning(chunks), '第一段\n\n第二段\n\n第三段');
    });

    test('同一 item id 在独立 decode 调用中不会残留状态', () async {
      final events = [
        {
          'type': 'response.reasoning_summary_text.done',
          'item_id': 'r1',
          'text': '公开摘要',
        },
      ];
      expect(_reasoning(await _decode(events)), '公开摘要');
      expect(_reasoning(await _decode(events)), '公开摘要');
    });
  });

  test('仅 metadata、encrypted_content、signature 与 token 数不生成思考', () async {
    final chunks = await _decode([
      {
        'type': 'response.output_item.done',
        'output_index': 0,
        'item': {
          'id': 'r1',
          'type': 'reasoning',
          'encrypted_content': 'not-public',
          'signature': 'not-text',
          'summary': [],
          'content': [
            {'type': 'encrypted_content', 'text': 'not-public'},
            {'type': 'signature', 'text': 'not-text'},
            {'type': 'reasoning_text', 'text': 42},
          ],
        },
      },
      {
        'type': 'response.completed',
        'response': {
          'output': [
            null,
            42,
            {'type': 'function_call', 'arguments': 'not-text'},
          ],
          'usage': {
            'input_tokens': 3,
            'output_tokens': 8,
            'output_tokens_details': {'reasoning_tokens': 7},
          },
        },
      },
    ]);
    expect(_reasoning(chunks), isEmpty);
    expect(_body(chunks), isEmpty);
    expect(chunks.last.done, isTrue);
    expect(chunks.last.usage?.completionTokens, 8);
  });

  test('无空格、多行 data、逐字节 UTF8 与畸形事件可容错', () async {
    const text =
        'data:{broken}\n\n'
        'data:{"type":"response.reasoning_summary_text.done",\r\n'
        'data:"item_id":"r1","summary_index":0,"text":"中文摘要"}\r\n\r\n'
        'data:{"type":"response.output_item.done","item":null}\n\n'
        'data:[DONE]\n\n';
    final chunks = await ResponsesSseDecoder.decode(
      Stream.fromIterable(utf8.encode(text).map((byte) => [byte])),
    ).toList();
    expect(_reasoning(chunks), '中文摘要');
    expect(chunks.last.done, isTrue);
  });

  test('补齐之前已发文本后，response.failed 仍然传递 ServerFailure', () async {
    final received = <ChatChunk>[];
    await expectLater(
      ResponsesSseDecoder.decode(
        Stream.value(
          utf8.encode(
            'data:{"type":"response.reasoning_summary_text.done","text":"摘要"}\n\n'
            'data:{"type":"response.failed","response":{"error":{"message":"过载"}}}\n\n',
          ),
        ),
      ).map((chunk) {
        received.add(chunk);
        return chunk;
      }).toList(),
      throwsA(
        isA<ServerFailure>().having(
          (error) => error.message,
          'message',
          contains('过载'),
        ),
      ),
    );
    expect(_reasoning(received), '摘要');
  });
}

Future<List<ChatChunk>> _decode(List<Map<String, dynamic>> events) {
  return ResponsesSseDecoder.decode(
    Stream.value(
      utf8.encode(
        events.map((event) => 'data:${jsonEncode(event)}\n\n').join(),
      ),
    ),
  ).toList();
}

String _reasoning(List<ChatChunk> chunks) =>
    chunks.map((chunk) => chunk.reasoningDelta ?? '').join();

String _body(List<ChatChunk> chunks) =>
    chunks.map((chunk) => chunk.delta).join();
