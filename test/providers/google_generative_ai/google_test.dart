import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/error/provider_error.dart';
import 'package:phase/data/models/chat_chunk.dart';
import 'package:phase/data/models/chat_message.dart';
import 'package:phase/data/models/chat_request.dart';
import 'package:phase/data/models/message_part.dart';
import 'package:phase/data/models/reasoning_effort.dart';
import 'package:phase/data/models/tool_policy.dart';
import 'package:phase/providers/google_generative_ai/google_decoder.dart';

void main() {
  ChatRequest request({
    ReasoningEffort effort = ReasoningEffort.off,
    String systemPrompt = '系统提示',
    List<ToolDefinition> tools = const [],
    List<ResolvedMessage>? messages,
  }) {
    return ChatRequest(
      modelId: 'gemini-2.5-pro',
      systemPrompt: systemPrompt,
      messages:
          messages ??
          const [
            ResolvedMessage(role: ChatRole.user, parts: [ResolvedText('你好')]),
            ResolvedMessage(
              role: ChatRole.assistant,
              parts: [ResolvedText('之前的回答')],
            ),
          ],
      tools: tools,
      reasoningEffort: effort,
    );
  }

  Stream<ChatChunk> decode(String sseText) {
    return GoogleSseDecoder.decode(Stream.value(utf8.encode(sseText)));
  }

  group('buildGooglePayload', () {
    test('assistant 映射 model 角色；systemPrompt 提取为 systemInstruction', () async {
      final payload = await buildGooglePayload(request());
      final contents = payload['contents'] as List;
      expect(contents, hasLength(2));
      expect(contents[0]['role'], 'user');
      expect(contents[1]['role'], 'model');
      expect(
        (payload['systemInstruction']['parts'] as List).first['text'],
        '系统提示',
      );
    });

    test('system 角色消息并入 systemInstruction，不进入 contents', () async {
      final payload = await buildGooglePayload(
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
      expect((payload['contents'] as List), hasLength(1));
      expect(
        (payload['systemInstruction']['parts'] as List).single['text'],
        '主提示\n\n补充规则',
      );
    });

    test('推理等级映射 thinkingBudget（off → 0）', () async {
      for (final (effort, budget) in [
        (ReasoningEffort.off, 0),
        (ReasoningEffort.low, 1024),
        (ReasoningEffort.medium, 8192),
        (ReasoningEffort.high, 24576),
        (ReasoningEffort.xhigh, 49152),
        (ReasoningEffort.max, 98304),
      ]) {
        final payload = await buildGooglePayload(request(effort: effort));
        expect(
          payload['generationConfig']['thinkingConfig']['thinkingBudget'],
          budget,
          reason: '$effort',
        );
      }
    });

    test('模型不支持推理时不下发 thinkingConfig', () async {
      final payload = await buildGooglePayload(
        request(effort: ReasoningEffort.high),
        supportsReasoning: false,
      );
      expect(
        (payload['generationConfig'] as Map).containsKey('thinkingConfig'),
        isFalse,
      );
    });

    test('未开放工具时不下发工具定义', () async {
      final payload = await buildGooglePayload(request());
      expect(payload.containsKey('tools'), isFalse);
    });

    test('工具定义使用 functionDeclarations', () async {
      final payload = await buildGooglePayload(
        request(tools: const [_weatherTool]),
      );
      expect(payload['tools'], [
        {
          'functionDeclarations': [
            {
              'name': 'get_weather',
              'description': '查天气',
              'parameters': {'type': 'object'},
            },
          ],
        },
      ]);
    });
  });

  group('buildGooglePayload 多轮回填', () {
    test('functionCall 回填参数与 thoughtSignature；结果按函数名配对', () async {
      final payload = await buildGooglePayload(
        request(
          messages: const [
            ResolvedMessage(role: ChatRole.user, parts: [ResolvedText('查天气')]),
            ResolvedMessage(
              role: ChatRole.assistant,
              parts: [
                ResolvedToolCall(
                  callId: 'tool_0',
                  toolName: 'get_weather',
                  arguments: {'city': '北京'},
                  providerData: {'thoughtSignature': 'sig-1'},
                ),
              ],
            ),
            ResolvedMessage(
              role: ChatRole.tool,
              parts: [ResolvedToolResult(callId: 'tool_0', content: '晴')],
            ),
          ],
        ),
      );
      final contents = (payload['contents'] as List)
          .cast<Map<String, dynamic>>();
      expect(contents[1]['parts'], [
        {
          'functionCall': {
            'name': 'get_weather',
            'args': {'city': '北京'},
            'thoughtSignature': 'sig-1',
          },
        },
      ]);
      // functionResponse 用函数名回填（协议没有调用 id）。
      expect(contents[2]['parts'], [
        {
          'functionResponse': {
            'name': 'get_weather',
            'response': {'result': '晴'},
          },
        },
      ]);
    });

    test('失败结果用 error 字段表达，不改写正文', () async {
      final payload = await buildGooglePayload(
        request(
          messages: const [
            ResolvedMessage(
              role: ChatRole.assistant,
              parts: [
                ResolvedToolCall(
                  callId: 'tool_0',
                  toolName: 'get_weather',
                  arguments: {},
                ),
              ],
            ),
            ResolvedMessage(
              role: ChatRole.tool,
              parts: [
                ResolvedToolResult(
                  callId: 'tool_0',
                  content: '超时',
                  isError: true,
                ),
              ],
            ),
          ],
        ),
      );
      final contents = (payload['contents'] as List)
          .cast<Map<String, dynamic>>();
      expect(contents[1]['parts'], [
        {
          'functionResponse': {
            'name': 'get_weather',
            'response': {'error': '超时'},
          },
        },
      ]);
    });
  });

  group('GoogleSseDecoder', () {
    test('普通 part → 正文', () async {
      final chunks = await decode(
        'data: {"candidates":[{"content":{"role":"model","parts":'
        '[{"text":"你好"}]}}]}\n\n',
      ).toList();
      expect(chunks.whereType<TextDelta>().single.text, '你好');
      expect(chunks.whereType<PartStart>().single.partId, 'text_0');
    });

    test('thought:true 的 part → 思考，与正文同帧分离', () async {
      final chunks = await decode(
        'data: {"candidates":[{"content":{"role":"model","parts":'
        '[{"text":"在想","thought":true},{"text":"答案"}]}}]}\n\n',
      ).toList();
      expect(chunks.whereType<ReasoningDelta>().single.text, '在想');
      expect(chunks.whereType<TextDelta>().single.text, '答案');
      expect(chunks.whereType<PartStart>().map((start) => start.kind), [
        PartKind.reasoning,
        PartKind.text,
      ]);
    });

    test('functionCall 一次给全参数，thoughtSignature 挂在调用上', () async {
      final chunks = await decode(
        'data: {"candidates":[{"content":{"role":"model","parts":'
        '[{"functionCall":{"name":"get_weather","args":{"city":"北京"}},'
        '"thoughtSignature":"sig-1"}]}}]}\n\n'
        'data: {"candidates":[{"content":{"role":"model","parts":[]},'
        '"finishReason":"STOP"}]}\n\n',
      ).toList();
      final delta = chunks.whereType<ToolCallDelta>().single;
      expect(delta.partId, 'tool_0');
      // 协议不给调用 id，用 partId 作为块标识。
      expect(delta.callId, isNull);
      expect(delta.toolName, 'get_weather');
      expect(delta.argumentsFragment, '{"city":"北京"}');
      // 协议状态随这次调用一起交付，不再另开内容块。
      expect(delta.providerData, {'thoughtSignature': 'sig-1'});
      final toolPart = chunks
          .whereType<PartEnd>()
          .map((end) => end.part)
          .whereType<ToolCallPart>()
          .single;
      expect(toolPart.toolCallId, 'tool_0');
      expect(toolPart.providerData, {'thoughtSignature': 'sig-1'});
      // signature 只作为协议状态，不能显示为思考。
      expect(chunks.whereType<ReasoningDelta>(), isEmpty);
    });

    test('finishReason 终态 + usageMetadata', () async {
      final chunks = await decode(
        'data: {"candidates":[{"content":{"role":"model","parts":[]},'
        '"finishReason":"STOP"}],"usageMetadata":{"promptTokenCount":5,'
        '"candidatesTokenCount":7,"totalTokenCount":12,'
        '"thoughtsTokenCount":3,"cachedContentTokenCount":2}}\n\n',
      ).toList();
      final usage = chunks.whereType<UsageChunk>().single.usage;
      expect(usage.inputTokens, 5);
      expect(usage.outputTokens, 7);
      expect(usage.reasoningTokens, 3);
      expect(usage.cachedInputTokens, 2);
      expect(chunks.last, isA<ResponseEnd>());
      expect((chunks.last as ResponseEnd).hasVisibleContent, isFalse);
    });

    test('error 块按协议错误字段分类', () async {
      final chunks = await decode(
        'data: {"error":{"code":503,"message":"过载","status":"UNAVAILABLE"}}\n\n',
      ).toList();
      final error = chunks.whereType<ResponseError>().single.error;
      expect(error.category, ProviderErrorCategory.providerError);
      expect(error.message, '过载');
      expect(chunks.whereType<ResponseEnd>(), isEmpty);
    });

    test('上下文超限按 INVALID_ARGUMENT 之外的状态字段区分', () async {
      final chunks = await decode(
        'data: {"error":{"code":400,"message":"太长","status":"INVALID_ARGUMENT"}}\n\n',
      ).toList();
      expect(
        chunks.whereType<ResponseError>().single.error.category,
        ProviderErrorCategory.invalidRequest,
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
