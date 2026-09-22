import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:phase/data/models/api_protocol.dart';
import 'package:phase/data/models/chat_chunk.dart';
import 'package:phase/data/models/token_usage.dart';
import 'package:phase/providers/usage_decoder.dart';
import 'package:phase/providers/anthropic_messages/anthropic_decoder.dart';
import 'package:phase/providers/openai_completions/sse_decoder.dart';
import 'package:phase/providers/openai_responses/responses_decoder.dart';

String event(Object data) => 'data: ${jsonEncode(data)}\n\n';
Stream<List<int>> fragments(String data) =>
    Stream.fromIterable(utf8.encode(data).map((b) => [b]));

void main() {
  test('Chat 累计快照省略保留、向下修订、不累加、终态后无效', () async {
    final chunks = await OpenAiSseDecoder.decode(
      fragments(
        '${event({
          'usage': {
            'prompt_tokens': 100,
            'prompt_tokens_details': {'cached_tokens': 80},
            'completion_tokens': 10,
          },
        })}${event({
          'usage': {
            'completion_tokens': 7,
            'completion_tokens_details': {'reasoning_tokens': 3},
            'total_tokens': 107,
          },
        })}data: [DONE]\n\n${event({
          'usage': {'completion_tokens': 999},
        })}',
      ),
    ).toList();
    final usage = chunks.whereType<UsageChunk>().last.usage;
    expect(usage.promptTokens, 100);
    expect(usage.outputTokens, 7);
    expect(usage.cacheReadTokens, 80);
    expect(usage.uncachedInputTokens, 20);
    expect(usage.totalTokens, 107);
    expect(usage.reasoningTokens, 3);
    expect(chunks.whereType<UsageChunk>(), hasLength(2));
    expect(usage.source(UsageField.totalTokens), UsageSource.reported);
  });

  test('缓存数不能充当输入，零值与缺失保持区别', () {
    final decoder = UsageDecoder(ApiProtocol.openaiCompletions);
    var usage = decoder.add({
      'prompt_tokens_details': {'cached_tokens': 10},
    })!;
    expect(usage.promptTokens, isNull);
    expect(usage.cacheHitRate, isNull);
    usage = decoder.add({
      'prompt_tokens': 10,
      'prompt_tokens_details': {'cached_tokens': 0},
    })!;
    expect(usage.cacheHitRate, 0);
    expect(usage.cacheWriteTokens, isNull);
    expect(decoder.add({'prompt_tokens': 0})!.cacheHitRate, isNull);
  });

  test('异常指标不损坏独立计数，后续修订可纠正', () {
    final decoder = UsageDecoder(ApiProtocol.openaiCompletions);
    final bad = decoder.add({
      'prompt_tokens': 10,
      'completion_tokens': 2,
      'total_tokens': 99,
      'prompt_tokens_details': {'cached_tokens': 11},
      'completion_tokens_details': {'reasoning_tokens': 3},
    })!;
    expect(bad.promptTokens, 10);
    expect(bad.outputTokens, 2);
    expect(bad.cacheReadTokens, isNull);
    expect(bad.reasoningTokens, isNull);
    expect(bad.totalTokens, isNull);
    expect(bad.invalidFields, {
      UsageField.cacheReadTokens,
      UsageField.reasoningTokens,
      UsageField.totalTokens,
    });
    final fixed = decoder.add({
      'total_tokens': 12,
      'prompt_tokens_details': {'cached_tokens': 0},
      'completion_tokens_details': {'reasoning_tokens': 0},
    })!;
    expect(fixed.invalidFields, isEmpty);
    final invalid = decoder.add({
      'prompt_tokens': -1,
      'completion_tokens': 1e30,
    })!;
    expect(invalid.promptTokens, isNull);
    expect(invalid.outputTokens, isNull);
    expect(
      TokenUsage.fromJson(invalid.toJson()).invalidFields,
      invalid.invalidFields,
    );
  });

  test('DeepSeek 显式读/未命中桶遵循统一总输入，不改变协议', () {
    final usage = UsageDecoder(ApiProtocol.openaiCompletions).add({
      'prompt_tokens': 100,
      'prompt_cache_hit_tokens': 80,
      'prompt_cache_miss_tokens': 20,
      'completion_tokens': 10,
    })!;
    expect(usage.totalTokens, 110);
    expect(usage.cacheHitRate, .8);
  });

  test('Anthropic 首帧即输出用量，错误也保留已报告缓存写入', () async {
    final chunks = await AnthropicSseDecoder.decode(
      fragments(
        event({
              'type': 'message_start',
              'message': {
                'usage': {
                  'input_tokens': 20,
                  'cache_read_input_tokens': 60,
                  'cache_creation_input_tokens': 20,
                  'output_tokens': 1,
                },
              },
            }) +
            event({
              'type': 'message_delta',
              'usage': {'output_tokens': 5},
            }) +
            event({
              'type': 'error',
              'error': {'type': 'api_error'},
            }),
      ),
    ).toList();
    final usage = chunks.whereType<UsageChunk>().last.usage;
    expect(usage.promptTokens, 100);
    expect(usage.totalTokens, 105);
    expect(usage.cacheWriteTokens, 20);
    expect(usage.cacheHitRate, .6);
    expect(chunks.last, isA<ResponseError>());
    expect(
      UsageDecoder(ApiProtocol.anthropicMessages)
          .add({'input_tokens': 20})!
          .promptTokens,
      isNull,
    );
  });

  test('Responses 完成帧只改报告字段，encrypted 内容不当思考计数', () async {
    final chunks = await ResponsesSseDecoder.decode(
      fragments(
        event({
              'type': 'response.created',
              'response': {
                'model': 'actual',
                'usage': {
                  'input_tokens': 10,
                  'input_tokens_details': {'cached_tokens': 6},
                },
              },
            }) +
            event({
              'type': 'response.completed',
              'response': {
                'usage': {'output_tokens': 4},
                'output': [],
              },
            }),
      ),
    ).toList();
    final usage = chunks.whereType<UsageChunk>().last.usage;
    expect(usage.promptTokens, 10);
    expect(usage.cacheReadTokens, 6);
    expect(usage.reasoningTokens, isNull);
    expect(usage.totalTokens, 14);
    expect(chunks.whereType<ResponseModel>().single.modelId, 'actual');
  });

  test('Google candidates 加 thoughts 一次，总数有额外分项时不猜差额', () {
    final usage = UsageDecoder(ApiProtocol.googleGenerativeAi).add({
      'promptTokenCount': 10,
      'candidatesTokenCount': 5,
      'thoughtsTokenCount': 3,
      'totalTokenCount': 18,
    })!;
    expect(usage.outputTokens, 8);
    expect(usage.totalTokens, 18);
    final partial = UsageDecoder(ApiProtocol.googleGenerativeAi).add({
      'promptTokenCount': 10,
      'candidatesTokenCount': 5,
      'totalTokenCount': 21,
    })!;
    expect(partial.totalTokens, 21);
    expect(partial.outputTokens, isNull);
    expect(partial.reasoningTokens, isNull);
    expect(partial.hasUnexplainedTotal, isTrue);
    final contradictory = UsageDecoder(ApiProtocol.googleGenerativeAi).add({
      'promptTokenCount': 10,
      'candidatesTokenCount': 5,
      'thoughtsTokenCount': 3,
      'totalTokenCount': 15,
    })!;
    expect(contradictory.totalTokens, isNull);
    expect(contradictory.invalidFields, contains(UsageField.totalTokens));
  });
}
