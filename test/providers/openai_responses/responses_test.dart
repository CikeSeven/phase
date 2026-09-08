import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/error/failure.dart';
import 'package:phase/data/models/chat_chunk.dart';
import 'package:phase/data/models/chat_message.dart';
import 'package:phase/data/models/chat_request.dart';
import 'package:phase/data/models/reasoning_effort.dart';
import 'package:phase/providers/openai_responses/responses_decoder.dart';

void main() {
  ChatRequest request({ReasoningEffort? effort}) {
    return ChatRequest(
      model: 'gpt-5',
      messages: const [
        ChatMessage(role: ChatRole.system, content: '系统提示'),
        ChatMessage(role: ChatRole.user, content: '你好'),
        ChatMessage(role: ChatRole.assistant, content: '之前的回答'),
      ],
      reasoningEffort: effort,
    );
  }

  Stream<ChatChunk> decode(String sseText) {
    return ResponsesSseDecoder.decode(Stream.value(utf8.encode(sseText)));
  }

  group('buildResponsesPayload', () {
    test('system 置首条 developer + input_text，assistant 用 output_text', () {
      final payload = buildResponsesPayload(request());
      final input = payload['input'] as List;
      expect(input[0]['role'], 'developer');
      expect(input[0]['content'][0]['type'], 'input_text');
      expect(input[1]['role'], 'user');
      expect(input[2]['role'], 'assistant');
      expect(input[2]['content'][0]['type'], 'output_text');
      expect(payload['stream'], isTrue);
    });

    test('推理等级映射 reasoning.effort + summary auto', () {
      for (final effort in [
        ReasoningEffort.low,
        ReasoningEffort.medium,
        ReasoningEffort.high,
      ]) {
        final payload = buildResponsesPayload(request(effort: effort));
        expect(payload['reasoning'], {
          'effort': effort.name,
          'summary': 'auto',
        });
      }
    });

    test('off → reasoning.effort none；null → 不下发', () {
      final off = buildResponsesPayload(
        request(effort: ReasoningEffort.off),
      );
      expect(off['reasoning'], {'effort': 'none'});
      final none = buildResponsesPayload(request());
      expect(none.containsKey('reasoning'), isFalse);
    });
  });

  group('ResponsesSseDecoder', () {
    test('正文增量', () async {
      final chunks = await decode(
        'data: {"type":"response.output_text.delta","delta":"你好"}\n\n',
      ).toList();
      expect(chunks.single.delta, '你好');
      expect(chunks.single.done, isFalse);
    });

    test('思考增量（summary 与 text 两种事件）', () async {
      final chunks = await decode(
        'data: {"type":"response.reasoning_summary_text.delta","delta":"想"}\n\n'
        'data: {"type":"response.reasoning_text.delta","delta":"答"}\n\n',
      ).toList();
      expect(chunks[0].reasoningDelta, '想');
      expect(chunks[1].reasoningDelta, '答');
      expect(chunks[1].delta, isEmpty);
    });

    test('completed 终态带 usage', () async {
      final chunks = await decode(
        'data: {"type":"response.completed","response":{"usage":'
        '{"input_tokens":10,"output_tokens":20,"total_tokens":30}}}\n\n',
      ).toList();
      expect(chunks.single.done, isTrue);
      expect(chunks.single.usage?.promptTokens, 10);
      expect(chunks.single.usage?.completionTokens, 20);
      expect(chunks.single.usage?.totalTokens, 30);
    });

    test('incomplete 也视为终态', () async {
      final chunks = await decode(
        'data: {"type":"response.incomplete","response":{"usage":'
        '{"input_tokens":1,"output_tokens":2,"total_tokens":3}}}\n\n',
      ).toList();
      expect(chunks.single.done, isTrue);
    });

    test('response.failed 抛 ServerFailure', () async {
      expect(
        () => decode(
          'data: {"type":"response.failed","response":{"error":'
          '{"message":"模型过载"}}}\n\n',
        ).toList(),
        throwsA(isA<ServerFailure>()),
      );
    });

    test('error 事件抛 ServerFailure', () async {
      expect(
        () => decode(
          'data: {"type":"error","error":{"message":"bad"}}\n\n',
        ).toList(),
        throwsA(isA<ServerFailure>()),
      );
    });

    test('无关事件与格式异常行被忽略', () async {
      final chunks = await decode(
        'data: {"type":"response.created"}\n\n'
        'data: {not json}\n\n'
        'data: {"type":"response.output_text.delta","delta":"好"}\n\n',
      ).toList();
      expect(chunks.single.delta, '好');
    });
  });
}
