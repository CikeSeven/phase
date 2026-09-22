import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/error/provider_error.dart';
import 'package:phase/data/models/chat_chunk.dart';
import 'package:phase/data/models/chat_message.dart';
import 'package:phase/data/models/chat_request.dart';
import 'package:phase/data/models/message_part.dart';
import 'package:phase/data/models/reasoning_effort.dart';
import 'package:phase/data/models/tool_policy.dart';
import 'package:phase/providers/anthropic_messages/anthropic_decoder.dart';

void main() {
  ChatRequest request({
    ReasoningEffort effort = ReasoningEffort.off,
    int? maxTokens,
    String systemPrompt = '系统提示',
    List<ToolDefinition> tools = const [],
    List<ResolvedMessage>? messages,
  }) {
    return ChatRequest(
      modelId: 'claude-sonnet-4',
      systemPrompt: systemPrompt,
      messages:
          messages ??
          const [
            ResolvedMessage(role: ChatRole.user, parts: [ResolvedText('你好')]),
          ],
      tools: tools,
      reasoningEffort: effort,
      maxOutputTokens: maxTokens,
    );
  }

  Stream<ChatChunk> decode(String sseText) {
    return AnthropicSseDecoder.decode(Stream.value(utf8.encode(sseText)));
  }

  group('buildAnthropicPayload', () {
    test('systemPrompt 独立字段，messages 不含 system；默认 max_tokens 8192', () async {
      final payload = await buildAnthropicPayload(request());
      expect(payload['system'], '系统提示');
      expect((payload['messages'] as List), hasLength(1));
      expect(payload['max_tokens'], 8192);
      expect(payload['stream'], isTrue);
      // off 在 Anthropic 的关闭语义是 thinking.type=disabled。
      expect(payload['thinking'], {'type': 'disabled'});
    });

    test('system 角色消息并入顶层 system 字段', () async {
      final payload = await buildAnthropicPayload(
        request(
          systemPrompt: '主提示',
          messages: const [
            ResolvedMessage(
              role: ChatRole.system,
              parts: [ResolvedText('补充规则')],
            ),
            ResolvedMessage(role: ChatRole.user, parts: [ResolvedText('你好')]),
          ],
        ),
      );
      expect(payload['system'], '主提示\n\n补充规则');
      expect((payload['messages'] as List), hasLength(1));
    });

    test('推理等级映射 thinking.budget_tokens（low 到 max）', () async {
      for (final (effort, budget) in [
        (ReasoningEffort.low, 1024),
        (ReasoningEffort.medium, 4096),
        (ReasoningEffort.high, 16384),
        (ReasoningEffort.xhigh, 32768),
        (ReasoningEffort.max, 65536),
      ]) {
        final payload = await buildAnthropicPayload(request(effort: effort));
        expect(payload['thinking'], {
          'type': 'enabled',
          'budget_tokens': budget,
        });
      }
    });

    test('模型不支持推理时不下发 thinking 字段', () async {
      final payload = await buildAnthropicPayload(
        request(effort: ReasoningEffort.high),
        supportsReasoning: false,
      );
      expect(payload.containsKey('thinking'), isFalse);
    });

    test('budget + 1024 超过 max_tokens 时抬升 max_tokens', () async {
      final payload = await buildAnthropicPayload(
        request(effort: ReasoningEffort.high),
      );
      expect(payload['max_tokens'], 16384 + 1024);
      // 显式 maxTokens 足够时不抬。
      final enough = await buildAnthropicPayload(
        request(effort: ReasoningEffort.low, maxTokens: 8192),
      );
      expect(enough['max_tokens'], 8192);
    });

    test('未开放工具时不下发工具定义', () async {
      final payload = await buildAnthropicPayload(request());
      expect(payload.containsKey('tools'), isFalse);
    });

    test('工具定义使用 input_schema 字段', () async {
      final payload = await buildAnthropicPayload(
        request(tools: const [_weatherTool]),
      );
      expect(payload['tools'], [
        {
          'name': 'get_weather',
          'description': '查天气',
          'input_schema': {'type': 'object'},
        },
      ]);
    });
  });

  group('buildAnthropicPayload 多轮回填', () {
    test('思考块带签名回传，工具调用与结果按协议配对', () async {
      final payload = await buildAnthropicPayload(
        request(
          systemPrompt: '',
          messages: const [
            ResolvedMessage(role: ChatRole.user, parts: [ResolvedText('查天气')]),
            ResolvedMessage(
              role: ChatRole.assistant,
              parts: [
                ResolvedReasoning('我要查', providerData: {'signature': 'sig-1'}),
                ResolvedToolCall(
                  callId: 'toolu_1',
                  toolName: 'get_weather',
                  arguments: {'city': '北京'},
                ),
              ],
            ),
            ResolvedMessage(
              role: ChatRole.tool,
              parts: [
                ResolvedToolResult(callId: 'toolu_1', content: '晴'),
                ResolvedToolResult(
                  callId: 'toolu_2',
                  content: '失败',
                  isError: true,
                ),
              ],
            ),
          ],
        ),
      );
      final messages = (payload['messages'] as List)
          .cast<Map<String, dynamic>>();
      expect(messages[1], {
        'role': 'assistant',
        'content': [
          {'type': 'thinking', 'thinking': '我要查', 'signature': 'sig-1'},
          {
            'type': 'tool_use',
            'id': 'toolu_1',
            'name': 'get_weather',
            'input': {'city': '北京'},
          },
        ],
      });
      // 连续工具结果留在同一条 user 消息里。
      expect(messages[2], {
        'role': 'user',
        'content': [
          {'type': 'tool_result', 'tool_use_id': 'toolu_1', 'content': '晴'},
          {
            'type': 'tool_result',
            'tool_use_id': 'toolu_2',
            'content': '失败',
            'is_error': true,
          },
        ],
      });
    });

    test('缺签名的思考块降级成正文，加密内容按 redacted_thinking 回传', () async {
      final payload = await buildAnthropicPayload(
        request(
          systemPrompt: '',
          messages: const [
            ResolvedMessage(
              role: ChatRole.assistant,
              parts: [
                ResolvedReasoning('没有签名'),
                ResolvedReasoning(
                  '',
                  providerData: {'type': 'redacted_thinking', 'data': 'cipher'},
                ),
              ],
            ),
          ],
        ),
      );
      final messages = (payload['messages'] as List)
          .cast<Map<String, dynamic>>();
      // 没有签名的思考不能当 thinking 送回（会被判非法），降级为普通文本；
      // 加密思考只能给同一个模型，同模型时原样回传。
      expect(messages.single['content'], [
        {'type': 'text', 'text': '没有签名'},
        {'type': 'redacted_thinking', 'data': 'cipher'},
      ]);
    });
  });

  group('AnthropicSseDecoder', () {
    test('text_delta → 正文，块结束补 PartEnd', () async {
      final chunks = await decode(
        'data: {"type":"content_block_start","index":0,'
        '"content_block":{"type":"text","text":""}}\n\n'
        'data: {"type":"content_block_delta","index":0,'
        '"delta":{"type":"text_delta","text":"你好"}}\n\n'
        'data: {"type":"content_block_stop","index":0}\n\n'
        'data: {"type":"message_stop"}\n\n',
      ).toList();
      expect(chunks.whereType<PartStart>().single.partId, 'text_0');
      expect(chunks.whereType<TextDelta>().single.text, '你好');
      expect(
        chunks.whereType<PartEnd>().single.part,
        isA<TextPart>().having((part) => part.text, 'text', '你好'),
      );
      expect(chunks.last, isA<ResponseEnd>());
    });

    test('thinking_delta → 思考，signature_delta 只作为协议状态', () async {
      final chunks = await decode(
        'data: {"type":"content_block_start","index":0,'
        '"content_block":{"type":"thinking","thinking":""}}\n\n'
        'data: {"type":"content_block_delta","index":0,'
        '"delta":{"type":"thinking_delta","thinking":"在想"}}\n\n'
        'data: {"type":"content_block_delta","index":0,'
        '"delta":{"type":"signature_delta","signature":"sig-9"}}\n\n'
        'data: {"type":"content_block_stop","index":0}\n\n'
        'data: {"type":"message_stop"}\n\n',
      ).toList();
      expect(chunks.whereType<ReasoningDelta>().single.text, '在想');
      expect(chunks.whereType<TextDelta>(), isEmpty);
      final part = chunks
          .whereType<PartEnd>()
          .map((chunk) => chunk.part)
          .whereType<ReasoningPart>()
          .single;
      expect(part.publicText, '在想');
      expect(part.providerData, {'signature': 'sig-9'});
    });

    test('redacted_thinking 不作为思考展示，只带协议状态', () async {
      final chunks = await decode(
        'data: {"type":"content_block_start","index":0,'
        '"content_block":{"type":"redacted_thinking","data":"cipher"}}\n\n'
        'data: {"type":"content_block_stop","index":0}\n\n'
        'data: {"type":"message_stop"}\n\n',
      ).toList();
      expect(chunks.whereType<ReasoningDelta>(), isEmpty);
      final part = chunks
          .whereType<PartEnd>()
          .map((chunk) => chunk.part)
          .whereType<ReasoningPart>()
          .single;
      expect(part.publicText, isEmpty);
      expect(part.providerData, {
        'type': 'redacted_thinking',
        'data': 'cipher',
      });
    });

    test('tool_use 的 input_json_delta 只累积参数片段', () async {
      final chunks = await decode(
        'data: {"type":"content_block_start","index":0,'
        '"content_block":{"type":"tool_use","id":"toolu_1","name":"get_weather",'
        '"input":{}}}\n\n'
        'data: {"type":"content_block_delta","index":0,'
        '"delta":{"type":"input_json_delta","partial_json":"{\\"city\\":"}}\n\n'
        'data: {"type":"content_block_delta","index":0,'
        '"delta":{"type":"input_json_delta","partial_json":"\\"北京\\"}"}}\n\n'
        'data: {"type":"content_block_stop","index":0}\n\n'
        'data: {"type":"message_stop"}\n\n',
      ).toList();
      final deltas = chunks.whereType<ToolCallDelta>().toList();
      expect(deltas.first.callId, 'toolu_1');
      expect(deltas.first.toolName, 'get_weather');
      expect(
        deltas.map((delta) => delta.argumentsFragment ?? '').join(),
        '{"city":"北京"}',
      );
      expect(chunks.whereType<PartStart>().single.partId, 'tool_0');
      expect(
        chunks.whereType<PartEnd>().single.part,
        isA<ToolCallPart>().having(
          (part) => part.toolCallId,
          'toolCallId',
          'toolu_1',
        ),
      );
      expect(chunks.last, isA<ResponseEnd>());
    });

    test('message_delta 合成 usage（并入 message_start 的 input_tokens）', () async {
      final chunks = await decode(
        'data: {"type":"message_start","message":{"usage":{"input_tokens":42,'
        '"cache_read_input_tokens":7,"cache_creation_input_tokens":0}}}\n\n'
        'data: {"type":"message_delta","delta":{"stop_reason":"end_turn"},'
        '"usage":{"output_tokens":8}}\n\n'
        'data: {"type":"message_stop"}\n\n',
      ).toList();
      final usage = chunks.whereType<UsageChunk>().last.usage;
      expect(usage.promptTokens, 49);
      expect(usage.uncachedInputTokens, 42);
      expect(usage.outputTokens, 8);
      expect(usage.cacheReadTokens, 7);
      expect(chunks.whereType<ResponseEnd>(), hasLength(1));
    });

    test('message_stop 终态', () async {
      final chunks = await decode('data: {"type":"message_stop"}\n\n').toList();
      expect(chunks.single, isA<ResponseEnd>());
      expect((chunks.single as ResponseEnd).hasVisibleContent, isFalse);
    });

    test('error 事件按协议错误字段分类', () async {
      final chunks = await decode(
        'data: {"type":"error","error":{"type":"overloaded_error",'
        '"message":"超载"}}\n\n',
      ).toList();
      final error = chunks.whereType<ResponseError>().single.error;
      expect(error.category, ProviderErrorCategory.providerError);
      expect(error.message, '超载');
      expect(chunks.whereType<ResponseEnd>(), isEmpty);
    });

    test('限流错误映射为 rateLimit', () async {
      final chunks = await decode(
        'data: {"type":"error","error":{"type":"rate_limit_error",'
        '"message":"慢一点"}}\n\n',
      ).toList();
      expect(
        chunks.whereType<ResponseError>().single.error.category,
        ProviderErrorCategory.rateLimit,
      );
    });

    test('content_block_start 与 ping 被忽略', () async {
      final chunks = await decode(
        'data: {"type":"content_block_start","index":0,'
        '"content_block":{"type":"text","text":""}}\n\n'
        'data: {"type":"ping"}\n\n'
        'data: {"type":"content_block_delta","index":0,'
        '"delta":{"type":"text_delta","text":"好"}}\n\n'
        'data: {"type":"message_stop"}\n\n',
      ).toList();
      expect(chunks.whereType<TextDelta>().single.text, '好');
      expect(chunks.whereType<PartStart>(), hasLength(1));
    });

    test('流被截断时在字节流结束时收口', () async {
      final chunks = await decode(
        'data: {"type":"content_block_delta","index":0,'
        '"delta":{"type":"text_delta","text":"半句"}}\n\n',
      ).toList();
      expect(chunks.whereType<TextDelta>().single.text, '半句');
      expect(chunks.last, isA<ResponseEnd>());
      expect(
        chunks.whereType<PartEnd>().single.part,
        isA<TextPart>().having((part) => part.text, 'text', '半句'),
      );
    });
  });
}

class _WeatherTool implements ToolDefinition {
  const _WeatherTool();

  @override
  String get name => 'get_weather';

  @override
  String get description => '查天气';

  @override
  Map<String, dynamic> get inputSchema => {'type': 'object'};

  @override
  Set<String> get requiredCapabilities => const {};

  @override
  ToolPolicy get defaultPolicy => ToolPolicy.allow;

  @override
  String describeAction(Map<String, dynamic> arguments) => '查天气 $arguments';
}

const _weatherTool = _WeatherTool();
