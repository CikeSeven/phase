import 'package:flutter_test/flutter_test.dart';
import 'package:phase/data/models/chat_message.dart';
import 'package:phase/data/models/chat_request.dart';
import 'package:phase/data/models/openai_compat.dart';
import 'package:phase/data/models/reasoning_effort.dart';
import 'package:phase/providers/openai_completions/openai_completions_provider.dart';

void main() {
  ChatRequest request({ReasoningEffort? effort, int? maxTokens}) {
    return ChatRequest(
      model: 'test-model',
      messages: const [
        ChatMessage(role: ChatRole.system, content: '系统提示'),
        ChatMessage(role: ChatRole.user, content: '你好'),
      ],
      reasoningEffort: effort,
      maxTokens: maxTokens,
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
    test('openai 格式：顶层 reasoning_effort，off 不下发', () {
      const compat = OpenAiCompat(thinkingFormat: ThinkingFormat.openai);
      for (final effort in [
        ReasoningEffort.low,
        ReasoningEffort.medium,
        ReasoningEffort.high,
      ]) {
        final payload = buildCompletionsPayload(
          request: request(effort: effort),
          compat: compat,
        );
        expect(payload['reasoning_effort'], effort.name);
      }
      final off = buildCompletionsPayload(
        request: request(effort: ReasoningEffort.off),
        compat: compat,
      );
      expect(off.containsKey('reasoning_effort'), isFalse);
    });

    test('openrouter 格式：reasoning.effort，off → none', () {
      const compat = OpenAiCompat(thinkingFormat: ThinkingFormat.openrouter);
      final payload = buildCompletionsPayload(
        request: request(effort: ReasoningEffort.high),
        compat: compat,
      );
      expect(payload['reasoning'], {'effort': 'high'});
      final off = buildCompletionsPayload(
        request: request(effort: ReasoningEffort.off),
        compat: compat,
      );
      expect(off['reasoning'], {'effort': 'none'});
    });

    test('deepseek 格式：thinking.type enabled/disabled', () {
      const compat = OpenAiCompat(thinkingFormat: ThinkingFormat.deepseek);
      final payload = buildCompletionsPayload(
        request: request(effort: ReasoningEffort.medium),
        compat: compat,
      );
      expect(payload['thinking'], {'type': 'enabled'});
      final off = buildCompletionsPayload(
        request: request(effort: ReasoningEffort.off),
        compat: compat,
      );
      expect(off['thinking'], {'type': 'disabled'});
    });

    test('qwen 格式：enable_thinking（off/low → false，其余 true）', () {
      const compat = OpenAiCompat(thinkingFormat: ThinkingFormat.qwen);
      for (final (effort, expected) in [
        (ReasoningEffort.off, false),
        (ReasoningEffort.low, false),
        (ReasoningEffort.medium, true),
        (ReasoningEffort.high, true),
      ]) {
        final payload = buildCompletionsPayload(
          request: request(effort: effort),
          compat: compat,
        );
        expect(payload['enable_thinking'], expected, reason: '$effort');
      }
    });

    test('effort 为 null 时不下发任何推理字段', () {
      const compat = OpenAiCompat(thinkingFormat: ThinkingFormat.deepseek);
      final payload = buildCompletionsPayload(
        request: request(),
        compat: compat,
      );
      expect(payload.containsKey('thinking'), isFalse);
      expect(payload.containsKey('reasoning_effort'), isFalse);
      expect(payload.containsKey('reasoning'), isFalse);
      expect(payload.containsKey('enable_thinking'), isFalse);
    });
  });

  group('buildCompletionsPayload 其余字段', () {
    test('supportsDeveloperRole 时 system 映射为 developer', () {
      final payload = buildCompletionsPayload(
        request: request(),
        compat: const OpenAiCompat(),
      );
      expect((payload['messages'] as List).first['role'], 'developer');
    });

    test('不支持 developer 时保持 system', () {
      final payload = buildCompletionsPayload(
        request: request(),
        compat: const OpenAiCompat(supportsDeveloperRole: false),
      );
      expect((payload['messages'] as List).first['role'], 'system');
    });

    test('maxTokens 按 maxTokensField 下发', () {
      final payload = buildCompletionsPayload(
        request: request(maxTokens: 2048),
        compat: const OpenAiCompat(maxTokensField: 'max_tokens'),
      );
      expect(payload['max_tokens'], 2048);
      expect(payload.containsKey('max_completion_tokens'), isFalse);
    });

    test('stream 固定为 true', () {
      final payload = buildCompletionsPayload(
        request: request(),
        compat: const OpenAiCompat(),
      );
      expect(payload['stream'], isTrue);
    });
  });
}
