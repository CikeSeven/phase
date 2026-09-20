import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/error/provider_error.dart';
import 'package:phase/data/models/chat_chunk.dart';
import 'package:phase/data/models/chat_message.dart';
import 'package:phase/data/models/chat_request.dart';
import 'package:phase/data/models/message_part.dart';
import 'package:phase/data/models/reasoning_effort.dart';
import 'package:phase/data/models/tool_policy.dart';
import 'package:phase/providers/openai_responses/responses_decoder.dart';

void main() {
  ChatRequest request({
    ReasoningEffort effort = ReasoningEffort.off,
    String systemPrompt = '系统提示',
    List<ToolDefinition> tools = const [],
    List<ResolvedMessage>? messages,
  }) {
    return ChatRequest(
      modelId: 'gpt-5',
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
    return ResponsesSseDecoder.decode(Stream.value(utf8.encode(sseText)));
  }

  group('buildResponsesPayload', () {
    test('systemPrompt 置首条 developer 字符串，assistant 用 output_text', () async {
      final payload = await buildResponsesPayload(request());
      final input = (payload['input'] as List).cast<Map<String, dynamic>>();
      expect(input[0]['role'], 'developer');
      expect(input[0]['content'], '系统提示');
      expect(input[1]['role'], 'user');
      expect(input[2]['role'], 'assistant');
      expect(input[2]['content'][0]['type'], 'output_text');
      expect(payload['stream'], isTrue);
      expect(payload['store'], isFalse);
    });

    test('推理等级映射 reasoning.effort + summary auto', () async {
      for (final effort in [
        ReasoningEffort.low,
        ReasoningEffort.medium,
        ReasoningEffort.high,
      ]) {
        final payload = await buildResponsesPayload(request(effort: effort));
        expect(payload['reasoning'], {
          'effort': effort.name,
          'summary': 'auto',
        });
      }
    });

    test('off → reasoning.effort none；模型不支持推理 → 不下发', () async {
      final off = await buildResponsesPayload(
        request(effort: ReasoningEffort.off),
      );
      expect(off['reasoning'], {'effort': 'none'});
      final unsupported = await buildResponsesPayload(
        request(effort: ReasoningEffort.high),
        supportsReasoning: false,
      );
      expect(unsupported.containsKey('reasoning'), isFalse);
    });

    test('未开放工具时不下发工具定义', () async {
      final payload = await buildResponsesPayload(request());
      expect(payload.containsKey('tools'), isFalse);
    });

    test('工具定义是扁平的 function item', () async {
      final payload = await buildResponsesPayload(
        request(tools: const [_weatherTool]),
      );
      expect(payload['tools'], [
        {
          'type': 'function',
          'name': 'get_weather',
          'description': '查天气',
          'parameters': {'type': 'object'},
          'strict': false,
        },
      ]);
    });
  });

  group('buildResponsesPayload 多轮回填', () {
    test('推理 item 原样回放，位次在这一轮的正文与调用之前', () async {
      final payload = await buildResponsesPayload(
        request(
          systemPrompt: '',
          messages: const [
            ResolvedMessage(role: ChatRole.user, parts: [ResolvedText('查天气')]),
            ResolvedMessage(
              role: ChatRole.assistant,
              parts: [
                ResolvedReasoning(
                  '内部推理',
                  providerData: {
                    'item': {
                      'type': 'reasoning',
                      'id': 'rs_1',
                      'summary': [
                        {'type': 'summary_text', 'text': '内部推理'},
                      ],
                      'encrypted_content': 'cipher',
                    },
                  },
                ),
                ResolvedText('我查一下'),
                ResolvedToolCall(
                  callId: 'call_1',
                  toolName: 'get_weather',
                  arguments: {'city': '北京'},
                ),
              ],
            ),
            ResolvedMessage(
              role: ChatRole.tool,
              parts: [ResolvedToolResult(callId: 'call_1', content: '晴')],
            ),
          ],
        ),
      );
      final input = (payload['input'] as List).cast<Map<String, dynamic>>();
      // 服务端按 rs_* ↔ fc_* 校验配对：缺了推理 item 就报
      // "function_call without required reasoning item"。
      expect(input[1]['type'], 'reasoning');
      expect(input[1]['id'], 'rs_1');
      expect(input[1]['encrypted_content'], 'cipher');
      expect(input[2]['role'], 'assistant');
      expect(input[3]['type'], 'function_call');
    });

    test('跨模型的推理 item 不回放', () async {
      final payload = await buildResponsesPayload(
        request(
          systemPrompt: '',
          messages: const [
            ResolvedMessage(
              role: ChatRole.assistant,
              sameModel: false,
              parts: [
                ResolvedReasoning(
                  '内部推理',
                  providerData: {
                    'item': {'type': 'reasoning', 'id': 'rs_1'},
                  },
                ),
                ResolvedText('回答'),
              ],
            ),
          ],
        ),
      );
      final input = (payload['input'] as List).cast<Map<String, dynamic>>();
      // 推理 item 不回放，思考文本降级成正文，位置不变。
      expect(input.single['role'], 'assistant');
      expect(input.single['content'], [
        {'type': 'output_text', 'text': '内部推理'},
        {'type': 'output_text', 'text': '回答'},
      ]);
    });

    test('仅在模型支持且开启推理时请求回放载荷，不绑定服务商域名', () async {
      for (final effort in ReasoningEffort.values) {
        for (final supported in [true, false]) {
          final payload = await buildResponsesPayload(
            request(effort: effort),
            supportsReasoning: supported,
          );
          if (supported && effort != ReasoningEffort.off) {
            expect(payload['include'], ['reasoning.encrypted_content']);
          } else {
            expect(payload.containsKey('include'), isFalse);
          }
          expect(payload['store'], isFalse);
        }
      }
    });

    test('函数调用与结果作为顶层 item，缺协议状态的思考不回传', () async {
      final payload = await buildResponsesPayload(
        request(
          systemPrompt: '',
          messages: const [
            ResolvedMessage(role: ChatRole.user, parts: [ResolvedText('查天气')]),
            ResolvedMessage(
              role: ChatRole.assistant,
              parts: [
                ResolvedText('我查一下'),
                ResolvedReasoning('内部推理'),
                ResolvedToolCall(
                  callId: 'call_1',
                  toolName: 'get_weather',
                  arguments: {'city': '北京'},
                ),
              ],
            ),
            ResolvedMessage(
              role: ChatRole.tool,
              parts: [ResolvedToolResult(callId: 'call_1', content: '晴')],
            ),
          ],
        ),
      );
      final input = (payload['input'] as List).cast<Map<String, dynamic>>();
      expect(input[1], {
        'role': 'assistant',
        'content': [
          {'type': 'output_text', 'text': '我查一下'},
        ],
      });
      expect(input[2], {
        'type': 'function_call',
        'call_id': 'call_1',
        'name': 'get_weather',
        'arguments': '{"city":"北京"}',
      });
      expect(input[3], {
        'type': 'function_call_output',
        'call_id': 'call_1',
        'output': '晴',
      });
      // 工具结果是顶层 item，不再包一层 message；Responses 的角色里没有 tool。
      expect(input, hasLength(4));
      expect(
        input.map((item) => item['role']).whereType<String>(),
        everyElement(isNot('tool')),
      );
      expect(payload.toString().contains('内部推理'), isFalse);
    });
  });

  group('ResponsesSseDecoder', () {
    test('正文增量', () async {
      final chunks = await decode(
        'data: {"type":"response.output_text.delta","delta":"你好"}\n\n',
      ).toList();
      expect(chunks.whereType<TextDelta>().single.text, '你好');
      expect(chunks.whereType<PartStart>().single.partId, 'text_0');
      // 增量与快照都不提前结束响应，收口只在流末尾发生一次。
      expect(chunks.whereType<ResponseEnd>(), hasLength(1));
      expect(chunks.last, isA<ResponseEnd>());
    });

    test('思考增量（summary 与 text 两种事件）', () async {
      final chunks = await decode(
        'data: {"type":"response.reasoning_summary_text.delta","delta":"想"}\n\n'
        'data: {"type":"response.reasoning_text.delta","delta":"答"}\n\n',
      ).toList();
      final deltas = chunks.whereType<ReasoningDelta>().toList();
      expect(deltas[0].text, '想');
      expect(deltas[1].text, '答');
      expect(chunks.whereType<TextDelta>(), isEmpty);
    });

    test('completed 终态带 usage', () async {
      final chunks = await decode(
        'data: {"type":"response.completed","response":{"usage":'
        '{"input_tokens":10,"output_tokens":20,"total_tokens":30,'
        '"output_tokens_details":{"reasoning_tokens":4},'
        '"input_tokens_details":{"cached_tokens":6}}}}\n\n',
      ).toList();
      final usage = chunks.whereType<UsageChunk>().single.usage;
      expect(usage.inputTokens, 10);
      expect(usage.outputTokens, 20);
      expect(usage.reasoningTokens, 4);
      expect(usage.cachedInputTokens, 6);
      expect(chunks.last, isA<ResponseEnd>());
    });

    test('incomplete 也视为终态', () async {
      final chunks = await decode(
        'data: {"type":"response.incomplete","response":{"usage":'
        '{"input_tokens":1,"output_tokens":2,"total_tokens":3}}}\n\n',
      ).toList();
      expect(chunks.whereType<ResponseEnd>(), hasLength(1));
    });

    test('response.failed 作为流内错误事件', () async {
      final chunks = await decode(
        'data: {"type":"response.failed","response":{"error":'
        '{"message":"模型过载"}}}\n\n',
      ).toList();
      final error = chunks.whereType<ResponseError>().single.error;
      expect(error.message, '模型过载');
      expect(error.category, ProviderErrorCategory.providerError);
      expect(chunks.whereType<ResponseEnd>(), isEmpty);
    });

    test('error 事件带明确错误码时按码分类', () async {
      final chunks = await decode(
        'data: {"type":"error","error":{"code":"rate_limit_exceeded",'
        '"message":"太快"}}\n\n',
      ).toList();
      final error = chunks.whereType<ResponseError>().single.error;
      expect(error.category, ProviderErrorCategory.rateLimit);
      expect(error.message, '太快');
    });

    test('无关事件与格式异常行被忽略', () async {
      final chunks = await decode(
        'data: {"type":"response.created"}\n\n'
        'data: {not json}\n\n'
        'data: {"type":"response.output_text.delta","delta":"好"}\n\n',
      ).toList();
      expect(chunks.whereType<TextDelta>().single.text, '好');
    });

    test('[DONE] 收口', () async {
      final chunks = await decode(
        'data: {"type":"response.output_text.delta","delta":"好"}\n\n'
        'data: [DONE]\n\n',
      ).toList();
      expect(chunks.whereType<TextDelta>().single.text, '好');
      expect(chunks.whereType<ResponseEnd>(), hasLength(1));
      expect(chunks.last, isA<ResponseEnd>());
    });
  });

  group('Responses 流式工具调用组装', () {
    test('参数增量累积，完整快照只补缺失后缀', () async {
      final chunks = await decode(
        _sse([
          {
            'type': 'response.output_item.added',
            'output_index': 0,
            'item': {
              'id': 'fc_1',
              'type': 'function_call',
              'call_id': 'call_1',
              'name': 'get_weather',
              'arguments': '',
            },
          },
          {
            'type': 'response.function_call_arguments.delta',
            'item_id': 'fc_1',
            'delta': '{"city":',
          },
          {
            'type': 'response.function_call_arguments.done',
            'item_id': 'fc_1',
            'arguments': '{"city":"北京"}',
          },
          {
            'type': 'response.output_item.done',
            'output_index': 0,
            'item': {
              'id': 'fc_1',
              'type': 'function_call',
              'call_id': 'call_1',
              'name': 'get_weather',
              'arguments': '{"city":"北京"}',
            },
          },
          {
            'type': 'response.completed',
            'response': {
              'output': [
                {
                  'id': 'fc_1',
                  'type': 'function_call',
                  'call_id': 'call_1',
                  'name': 'get_weather',
                  'arguments': '{"city":"北京"}',
                },
              ],
            },
          },
        ]),
      ).toList();

      final deltas = chunks.whereType<ToolCallDelta>().toList();
      expect(chunks.whereType<PartStart>().single.partId, 'tool_0');
      expect(chunks.whereType<PartStart>().single.kind, PartKind.toolCall);
      expect(deltas.first.callId, 'call_1');
      expect(deltas.first.toolName, 'get_weather');
      // 完整快照只补缺失后缀：参数不重复追加。
      expect(
        deltas.map((delta) => delta.argumentsFragment ?? '').join(),
        '{"city":"北京"}',
      );
      expect(
        chunks.whereType<PartEnd>().single.part,
        isA<ToolCallPart>().having(
          (part) => part.toolCallId,
          'toolCallId',
          'call_1',
        ),
      );
      expect(chunks.whereType<TextDelta>(), isEmpty);
      expect(chunks.last, isA<ResponseEnd>());
      expect((chunks.last as ResponseEnd).hasVisibleContent, isTrue);
    });
  });
}

String _sse(List<Map<String, dynamic>> events) =>
    events.map((event) => 'data:${jsonEncode(event)}\n\n').join();

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
