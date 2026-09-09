import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/error/failure.dart';
import 'package:phase/data/models/chat_chunk.dart';
import 'package:phase/data/models/chat_message.dart';
import 'package:phase/data/models/chat_request.dart';
import 'package:phase/data/models/reasoning_effort.dart';
import 'package:phase/providers/google_generative_ai/google_decoder.dart';

void main() {
  ChatRequest request({ReasoningEffort? effort}) {
    return ChatRequest(
      model: 'gemini-2.5-pro',
      messages: const [
        ChatMessage(role: ChatRole.system, content: '系统提示'),
        ChatMessage(role: ChatRole.user, content: '你好'),
        ChatMessage(role: ChatRole.assistant, content: '之前的回答'),
      ],
      reasoningEffort: effort,
    );
  }

  Stream<ChatChunk> decode(String sseText) {
    return GoogleSseDecoder.decode(Stream.value(utf8.encode(sseText)));
  }

  group('buildGooglePayload', () {
    test('assistant 映射 model 角色；system 提取为 systemInstruction', () {
      final payload = buildGooglePayload(request());
      final contents = payload['contents'] as List;
      expect(contents, hasLength(2));
      expect(contents[0]['role'], 'user');
      expect(contents[1]['role'], 'model');
      expect(
        (payload['systemInstruction']['parts'] as List).first['text'],
        '系统提示',
      );
    });

    test('推理等级映射 thinkingBudget（off → 0）', () {
      for (final (effort, budget) in [
        (ReasoningEffort.off, 0),
        (ReasoningEffort.low, 1024),
        (ReasoningEffort.medium, 8192),
        (ReasoningEffort.high, 24576),
        (ReasoningEffort.xhigh, 49152),
        (ReasoningEffort.max, 98304),
      ]) {
        final payload = buildGooglePayload(request(effort: effort));
        expect(
          payload['generationConfig']['thinkingConfig']['thinkingBudget'],
          budget,
          reason: '$effort',
        );
      }
    });

    test('effort 为 null 时不下发 thinkingConfig', () {
      final payload = buildGooglePayload(request());
      expect(
        (payload['generationConfig'] as Map).containsKey('thinkingConfig'),
        isFalse,
      );
    });
  });

  group('GoogleSseDecoder', () {
    test('普通 part → 正文', () async {
      final chunks = await decode(
        'data: {"candidates":[{"content":{"role":"model","parts":'
        '[{"text":"你好"}]}}]}\n\n',
      ).toList();
      expect(chunks.single.delta, '你好');
    });

    test('thought:true 的 part → 思考，与正文同帧分离', () async {
      final chunks = await decode(
        'data: {"candidates":[{"content":{"role":"model","parts":'
        '[{"text":"在想","thought":true},{"text":"答案"}]}}]}\n\n',
      ).toList();
      expect(chunks.single.reasoningDelta, '在想');
      expect(chunks.single.delta, '答案');
    });

    test('finishReason 终态 + usageMetadata', () async {
      final chunks = await decode(
        'data: {"candidates":[{"content":{"role":"model","parts":[]},'
        '"finishReason":"STOP"}],"usageMetadata":{"promptTokenCount":5,'
        '"candidatesTokenCount":7,"totalTokenCount":12}}\n\n',
      ).toList();
      expect(chunks.single.done, isTrue);
      expect(chunks.single.usage?.promptTokens, 5);
      expect(chunks.single.usage?.completionTokens, 7);
      expect(chunks.single.usage?.totalTokens, 12);
    });

    test('error 块抛 ServerFailure', () async {
      expect(
        () => decode(
          'data: {"error":{"code":503,"message":"过载","status":"UNAVAILABLE"}}\n\n',
        ).toList(),
        throwsA(isA<ServerFailure>()),
      );
    });
  });
}
