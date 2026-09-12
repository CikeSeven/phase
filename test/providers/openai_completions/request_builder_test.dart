import 'package:flutter_test/flutter_test.dart';
import 'package:phase/data/models/chat_message.dart';
import 'package:phase/data/models/chat_request.dart';
import 'package:phase/data/models/openai_compat.dart';
import 'package:phase/data/models/reasoning_effort.dart';
import 'package:phase/data/models/tool_policy.dart';
import 'package:phase/providers/openai_completions/openai_completions_provider.dart';

void main() {
  ChatRequest request({
    ReasoningEffort effort = ReasoningEffort.off,
    int? maxTokens,
    String systemPrompt = '系统提示',
    List<ToolDefinition> tools = const [],
    List<ResolvedMessage>? messages,
  }) {
    return ChatRequest(
      modelId: 'test-model',
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

  group('OpenAiCompat.sniff', () {
    test('api.deepseek.com → deepseek 格式 + max_tokens + 无 developer', () {
      final compat = OpenAiCompat.sniff('https://api.deepseek.com');
      expect(compat.thinkingFormat, ThinkingFormat.deepseek);
      expect(compat.maxTokensField, 'max_tokens');
      expect(compat.supportsDeveloperRole, isFalse);
    });

    test('openrouter.ai → openrouter 格式', () {
      final compat = OpenAiCompat.sniff('https://openrouter.ai/api/v1');
      expect(compat.thinkingFormat, ThinkingFormat.openrouter);
    });

    test('api.moonshot → openai 格式 + max_tokens', () {
      final compat = OpenAiCompat.sniff('https://api.moonshot.cn/v1');
      expect(compat.thinkingFormat, ThinkingFormat.openai);
      expect(compat.maxTokensField, 'max_tokens');
    });

    test('dashscope/阿里云 → qwen 格式', () {
      final compat = OpenAiCompat.sniff(
        'https://dashscope.aliyuncs.com/compatible-mode/v1',
      );
      expect(compat.thinkingFormat, ThinkingFormat.qwen);
    });

    test('未知地址 → openai 默认', () {
      final compat = OpenAiCompat.sniff('http://localhost:11434/v1');
      expect(compat.thinkingFormat, ThinkingFormat.openai);
      expect(compat.maxTokensField, 'max_completion_tokens');
      expect(compat.supportsDeveloperRole, isTrue);
    });

    test('profile 覆盖优先于嗅探', () {
      final resolved = OpenAiCompat.resolve(
        'https://api.deepseek.com',
        const OpenAiCompat(thinkingFormat: ThinkingFormat.openrouter),
      );
      expect(resolved.thinkingFormat, ThinkingFormat.openrouter);
    });
  });

  group('buildCompletionsPayload 推理等级映射', () {
    test('openai 格式：顶层 reasoning_effort，off 不下发', () async {
      const compat = OpenAiCompat(thinkingFormat: ThinkingFormat.openai);
      for (final effort in ReasoningEffort.levels) {
        final payload = await buildCompletionsPayload(
          request(effort: effort),
          compat: compat,
        );
        expect(payload['reasoning_effort'], effort.name);
      }
      final off = await buildCompletionsPayload(
        request(effort: ReasoningEffort.off),
        compat: compat,
      );
      expect(off.containsKey('reasoning_effort'), isFalse);
    });

    test('openrouter 格式：reasoning.effort，off → none', () async {
      const compat = OpenAiCompat(thinkingFormat: ThinkingFormat.openrouter);
      final payload = await buildCompletionsPayload(
        request(effort: ReasoningEffort.high),
        compat: compat,
      );
      expect(payload['reasoning'], {'effort': 'high'});
      final off = await buildCompletionsPayload(
        request(effort: ReasoningEffort.off),
        compat: compat,
      );
      expect(off['reasoning'], {'effort': 'none'});
    });

    test('deepseek 格式：thinking.type enabled/disabled', () async {
      const compat = OpenAiCompat(thinkingFormat: ThinkingFormat.deepseek);
      final payload = await buildCompletionsPayload(
        request(effort: ReasoningEffort.medium),
        compat: compat,
      );
      expect(payload['thinking'], {'type': 'enabled'});
      final off = await buildCompletionsPayload(
        request(effort: ReasoningEffort.off),
        compat: compat,
      );
      expect(off['thinking'], {'type': 'disabled'});
    });

    test('qwen 格式：enable_thinking（off/low → false，其余 true）', () async {
      const compat = OpenAiCompat(thinkingFormat: ThinkingFormat.qwen);
      for (final (effort, expected) in [
        (ReasoningEffort.off, false),
        (ReasoningEffort.low, false),
        (ReasoningEffort.medium, true),
        (ReasoningEffort.high, true),
        (ReasoningEffort.xhigh, true),
        (ReasoningEffort.max, true),
      ]) {
        final payload = await buildCompletionsPayload(
          request(effort: effort),
          compat: compat,
        );
        expect(payload['enable_thinking'], expected, reason: '$effort');
      }
    });

    test('模型不支持推理时任何等级都不下发推理字段', () async {
      for (final format in ThinkingFormat.values) {
        final payload = await buildCompletionsPayload(
          request(effort: ReasoningEffort.high),
          compat: OpenAiCompat(thinkingFormat: format),
          supportsReasoning: false,
        );
        expect(payload.containsKey('thinking'), isFalse, reason: '$format');
        expect(payload.containsKey('reasoning_effort'), isFalse);
        expect(payload.containsKey('reasoning'), isFalse);
        expect(payload.containsKey('enable_thinking'), isFalse);
      }
    });
  });

  group('思考回传（对齐 pi）', () {
    const compat = OpenAiCompat(
      thinkingFormat: ThinkingFormat.openai,
      supportsDeveloperRole: true,
    );
    Future<Map<String, dynamic>> assistantMessage({
      required List<ResolvedPart> parts,
      bool sameModel = true,
    }) async {
      final payload = await buildCompletionsPayload(
        request(
          systemPrompt: '',
          messages: [
            ResolvedMessage(
              role: ChatRole.assistant,
              parts: parts,
              sameModel: sameModel,
            ),
          ],
        ),
        compat: compat,
      );
      return ((payload['messages'] as List).cast<Map<String, dynamic>>())
          .single;
    }

    test('带工具调用的一轮按来源字段回传 reasoning_content', () async {
      final message = await assistantMessage(
        parts: const [
          ResolvedReasoning('先想', providerData: {'field': 'reasoning_content'}),
          ResolvedToolCall(
            callId: 'call_1',
            toolName: 'get_weather',
            arguments: {'city': '北京'},
          ),
        ],
      );
      expect(message['reasoning_content'], '先想');
      expect(message['tool_calls'], hasLength(1));
    });

    test('普通轮次不回传：端点不认的字段会直接报错', () async {
      final message = await assistantMessage(
        parts: const [
          ResolvedReasoning('先想', providerData: {'field': 'reasoning_content'}),
          ResolvedText('答案'),
        ],
      );
      expect(message.containsKey('reasoning_content'), isFalse);
    });

    test('结构化明细原样回传，带不带工具调用都一样', () async {
      final message = await assistantMessage(
        parts: const [
          ResolvedReasoning(
            '先想',
            providerData: {
              'details': [
                {'type': 'reasoning.text', 'text': '先想', 'signature': 'sig'},
              ],
            },
          ),
          ResolvedText('答案'),
        ],
      );
      expect(message['reasoning_details'], [
        {'type': 'reasoning.text', 'text': '先想', 'signature': 'sig'},
      ]);
    });

    test('跨模型不回传任何思考字段', () async {
      final message = await assistantMessage(
        sameModel: false,
        parts: const [
          ResolvedReasoning('先想', providerData: {'field': 'reasoning_content'}),
          ResolvedToolCall(
            callId: 'call_1',
            toolName: 'get_weather',
            arguments: {'city': '北京'},
          ),
        ],
      );
      expect(message.containsKey('reasoning_content'), isFalse);
    });
  });

  group('buildCompletionsPayload 其余字段', () {
    test('systemPrompt 置首条消息，supportsDeveloperRole 决定角色', () async {
      final payload = await buildCompletionsPayload(
        request(),
        compat: const OpenAiCompat(),
      );
      final messages = payload['messages'] as List;
      expect(messages.first['role'], 'developer');
      expect(messages.first['content'], '系统提示');
      expect(messages[1]['role'], 'user');

      final legacy = await buildCompletionsPayload(
        request(),
        compat: const OpenAiCompat(supportsDeveloperRole: false),
      );
      expect((legacy['messages'] as List).first['role'], 'system');
    });

    test('systemPrompt 为空时不产生系统消息', () async {
      final payload = await buildCompletionsPayload(
        request(systemPrompt: ''),
        compat: const OpenAiCompat(),
      );
      expect((payload['messages'] as List).single['role'], 'user');
    });

    test('maxOutputTokens 按 maxTokensField 下发', () async {
      final payload = await buildCompletionsPayload(
        request(maxTokens: 2048),
        compat: const OpenAiCompat(maxTokensField: 'max_tokens'),
      );
      expect(payload['max_tokens'], 2048);
      expect(payload.containsKey('max_completion_tokens'), isFalse);
    });

    test('stream 固定为 true', () async {
      final payload = await buildCompletionsPayload(
        request(),
        compat: const OpenAiCompat(),
      );
      expect(payload['stream'], isTrue);
    });

    test('未开放工具时不下发工具定义', () async {
      final payload = await buildCompletionsPayload(
        request(),
        compat: const OpenAiCompat(),
      );
      expect(payload.containsKey('tools'), isFalse);
    });

    test('工具定义按 function 形状下发', () async {
      final payload = await buildCompletionsPayload(
        request(tools: [_weatherTool]),
        compat: const OpenAiCompat(),
      );
      expect(payload['tools'], [
        {
          'type': 'function',
          'function': {
            'name': 'get_weather',
            'description': '查天气',
            'parameters': {'type': 'object'},
          },
        },
      ]);
    });
  });

  group('buildCompletionsPayload 多轮回填', () {
    test('思考块不进入请求，工具调用与结果按调用 ID 配对', () async {
      final payload = await buildCompletionsPayload(
        request(
          messages: [
            const ResolvedMessage(
              role: ChatRole.user,
              parts: [ResolvedText('北京天气')],
            ),
            const ResolvedMessage(
              role: ChatRole.assistant,
              parts: [
                ResolvedReasoning('需要查天气', providerData: {'signature': 's'}),
                ResolvedToolCall(
                  callId: 'call_1',
                  toolName: 'get_weather',
                  arguments: {'city': '北京'},
                ),
              ],
            ),
            const ResolvedMessage(
              role: ChatRole.tool,
              parts: [ResolvedToolResult(callId: 'call_1', content: '晴')],
            ),
          ],
        ),
        compat: const OpenAiCompat(),
      );
      final messages = (payload['messages'] as List)
          .cast<Map<String, dynamic>>();
      expect(messages[1]['role'], 'user');
      final assistant = messages[2];
      expect(assistant['role'], 'assistant');
      expect(assistant['tool_calls'], [
        {
          'id': 'call_1',
          'type': 'function',
          'function': {'name': 'get_weather', 'arguments': '{"city":"北京"}'},
        },
      ]);
      expect(messages[3], {
        'role': 'tool',
        'tool_call_id': 'call_1',
        'content': '晴',
      });
      // 公开思考不进入 OpenAI 兼容协议的请求。
      expect(payload.toString().contains('需要查天气'), isFalse);
    });

    test('system 角色消息按 developer 角色保留在 messages 中', () async {
      final payload = await buildCompletionsPayload(
        request(
          systemPrompt: '',
          messages: const [
            ResolvedMessage(
              role: ChatRole.system,
              parts: [ResolvedText('补充规则')],
            ),
            ResolvedMessage(role: ChatRole.user, parts: [ResolvedText('你好')]),
          ],
        ),
        compat: const OpenAiCompat(),
      );
      final messages = (payload['messages'] as List)
          .cast<Map<String, dynamic>>();
      expect(messages.first['role'], 'developer');
      expect(messages.first['content'], '补充规则');
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
