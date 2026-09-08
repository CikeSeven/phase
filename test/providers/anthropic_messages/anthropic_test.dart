import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/error/failure.dart';
import 'package:phase/data/models/chat_chunk.dart';
import 'package:phase/data/models/chat_message.dart';
import 'package:phase/data/models/chat_request.dart';
import 'package:phase/data/models/reasoning_effort.dart';
import 'package:phase/providers/anthropic_messages/anthropic_decoder.dart';

void main() {
  ChatRequest request({ReasoningEffort? effort, int? maxTokens}) {
    return ChatRequest(
      model: 'claude-sonnet-4',
      messages: const [
        ChatMessage(role: ChatRole.system, content: '系统提示'),
        ChatMessage(role: ChatRole.user, content: '你好'),
      ],
      reasoningEffort: effort,
      maxTokens: maxTokens,
    );
  }

  Stream<ChatChunk> decode(String sseText) {
    return AnthropicSseDecoder.decode(Stream.value(utf8.encode(sseText)));
  }

  group('buildAnthropicPayload', () {
    test('system 独立字段，messages 不含 system；默认 max_tokens 8192', () {
      final payload = buildAnthropicPayload(request());
      expect(payload['system'], '系统提示');
      expect((payload['messages'] as List), hasLength(1));
      expect(payload['max_tokens'], 8192);
      expect(payload['stream'], isTrue);
      expect(payload.containsKey('thinking'), isFalse);
    });

    test('推理等级映射 thinking.budget_tokens（low/medium/high）', () {
      for (final (effort, budget) in [
        (ReasoningEffort.low, 1024),
        (ReasoningEffort.medium, 4096),
        (ReasoningEffort.high, 16384),
      ]) {
        final payload = buildAnthropicPayload(request(effort: effort));
        expect(payload['thinking'], {
          'type': 'enabled',
          'budget_tokens': budget,
        });
      }
    });

    test('off → thinking disabled', () {
      final payload = buildAnthropicPayload(
        request(effort: ReasoningEffort.off),
      );
      expect(payload['thinking'], {'type': 'disabled'});
    });

    test('budget + 1024 超过 max_tokens 时抬升 max_tokens', () {
      final payload = buildAnthropicPayload(
        request(effort: ReasoningEffort.high),
      );
      expect(payload['max_tokens'], 16384 + 1024);
      // 显式 maxTokens 足够时不抬。
      final enough = buildAnthropicPayload(
        request(effort: ReasoningEffort.low, maxTokens: 8192),
      );
      expect(enough['max_tokens'], 8192);
    });
  });

  group('AnthropicSseDecoder', () {
    test('text_delta → 正文', () async {
      final chunks = await decode(
        'data: {"type":"content_block_delta","index":0,'
        '"delta":{"type":"text_delta","text":"你好"}}\n\n',
      ).toList();
      expect(chunks.single.delta, '你好');
    });

    test('thinking_delta → 思考', () async {
      final chunks = await decode(
        'data: {"type":"content_block_delta","index":0,'
        '"delta":{"type":"thinking_delta","thinking":"在想"}}\n\n',
      ).toList();
      expect(chunks.single.reasoningDelta, '在想');
      expect(chunks.single.delta, isEmpty);
    });

    test('message_delta 终态并合成 usage（并入 message_start 的 input_tokens）', () async {
      final chunks = await decode(
        'data: {"type":"message_start","message":{"usage":{"input_tokens":42}}}\n\n'
        'data: {"type":"message_delta","delta":{"stop_reason":"end_turn"},'
        '"usage":{"output_tokens":8}}\n\n',
      ).toList();
      expect(chunks.single.done, isTrue);
      expect(chunks.single.usage?.promptTokens, 42);
      expect(chunks.single.usage?.completionTokens, 8);
      expect(chunks.single.usage?.totalTokens, 50);
    });

    test('message_stop 终态', () async {
      final chunks = await decode(
        'data: {"type":"message_stop"}\n\n',
      ).toList();
      expect(chunks.single.done, isTrue);
    });

    test('error 事件抛 ServerFailure', () async {
      expect(
        () => decode(
          'data: {"type":"error","error":{"type":"overloaded_error",'
          '"message":"超载"}}\n\n',
        ).toList(),
        throwsA(isA<ServerFailure>()),
      );
    });

    test('content_block_start 与 ping 被忽略', () async {
      final chunks = await decode(
        'data: {"type":"content_block_start","index":0,'
        '"content_block":{"type":"text","text":""}}\n\n'
        'data: {"type":"ping"}\n\n'
        'data: {"type":"content_block_delta","index":0,'
        '"delta":{"type":"text_delta","text":"好"}}\n\n',
      ).toList();
      expect(chunks.single.delta, '好');
    });
  });
}
