import 'package:phase/data/models/token_usage.dart';

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:phase/data/models/chat_message.dart';
import 'package:phase/data/models/message_part.dart';
import 'package:phase/data/models/model_selection.dart';
import 'package:phase/data/models/reasoning_effort.dart';
import 'package:phase/data/models/tool_policy.dart';

/// 消息内容块与配置结构的读写契约。
void main() {
  group('MessagePart', () {
    test('各类型编码后可按原类型解码', () {
      final parts = <MessagePart>[
        const TextPart(text: '正文', partId: 'text_0'),
        ReasoningPart(
          publicText: '思考',
          providerData: const {'signature': 's'},
          startedAt: DateTime(2026, 9, 18, 12),
          durationMs: 1350,
        ),
        const ImagePart(attachmentId: 'a1'),
        const DocumentPart(attachmentId: 'a2'),
        const ToolCallPart(toolCallId: 'call_1'),
        const ToolResultPart(toolCallId: 'call_1'),
        const ProviderPart(
          protocol: 'anthropicMessages',
          modelId: 'claude-x',
          data: {'type': 'server_tool_use'},
        ),
      ];

      final json = jsonDecode(encodeMessageParts(parts)) as List;
      final decoded = decodeMessageParts(json);

      expect(decoded.map((part) => part.type), [
        'text',
        'reasoning',
        'image',
        'document',
        'toolCall',
        'toolResult',
        'provider',
      ]);
      expect((decoded[0] as TextPart).text, '正文');
      expect((decoded[1] as ReasoningPart).providerData, {'signature': 's'});
      expect(
        (decoded[1] as ReasoningPart).startedAt,
        DateTime(2026, 9, 18, 12),
      );
      expect((decoded[1] as ReasoningPart).durationMs, 1350);
      expect((decoded[4] as ToolCallPart).toolCallId, 'call_1');
      expect((decoded[5] as ToolResultPart).toolCallId, 'call_1');
    });

    test('思考与协议状态分开保存，协议块不当作思考', () {
      final parts = decodeMessageParts([
        {'type': 'reasoning', 'publicText': '公开摘要'},
        {
          'type': 'provider',
          'protocol': 'anthropicMessages',
          'modelId': 'claude-x',
          'data': {'encrypted': 'AAAA'},
        },
      ]);
      expect(parts.whereType<ReasoningPart>().single.publicText, '公开摘要');
      expect(parts.whereType<ReasoningPart>().single.providerData, isNull);
    });

    test('工具 Part 只引用记录 id，不复制参数与结果', () {
      final encoded = encodeMessageParts(const [
        ToolCallPart(toolCallId: 'c1'),
      ]);
      expect(encoded.contains('arguments'), isFalse);
      expect(encoded.contains('c1'), isTrue);
    });

    test('未定义类型与非法结构抛出 FormatException', () {
      expect(
        () => decodeMessageParts([
          {'type': 'audio', 'data': 'x'},
        ]),
        throwsFormatException,
      );
      expect(() => decodeMessageParts('not-a-list'), throwsFormatException);
    });
  });

  group('ChatMessage', () {
    ChatMessage build({List<MessagePart> parts = const []}) => ChatMessage(
      id: 'm1',
      conversationId: 'c1',
      role: ChatRole.user,
      parts: parts,
      createdAt: DateTime(2026, 9, 12),
    );

    test('正文取所有 TextPart 的顺序拼接', () {
      expect(
        build(
          parts: const [
            TextPart(text: '第一段'),
            ReasoningPart(publicText: '思考'),
            TextPart(text: '第二段'),
          ],
        ).text,
        '第一段第二段',
      );
    });

    test('可见内容判定：正文/思考/附件/工具引用都算内容', () {
      expect(build().hasVisibleContent, isFalse);
      expect(
        build(parts: const [TextPart(text: 'x')]).hasVisibleContent,
        isTrue,
      );
      expect(
        build(parts: const [ReasoningPart(publicText: 'x')]).hasVisibleContent,
        isTrue,
      );
      expect(
        build(parts: const [ImagePart(attachmentId: 'a1')]).hasVisibleContent,
        isTrue,
      );
      expect(
        build(parts: const [ToolCallPart(toolCallId: 'c1')]).hasVisibleContent,
        isTrue,
      );
      expect(
        build(
          parts: const [ProviderPart(protocol: 'p', modelId: 'm', data: {})],
        ).hasVisibleContent,
        isFalse,
      );
    });

    test('角色包含 system 与 tool', () {
      expect(ChatRole.values, [
        ChatRole.user,
        ChatRole.assistant,
        ChatRole.system,
        ChatRole.tool,
      ]);
    });
  });

  group('配置结构', () {
    test('ModelSelection 往返保留推理等级与参数', () {
      const selection = ModelSelection(
        profileId: 'p1',
        modelId: 'm1',
        reasoningEffort: ReasoningEffort.high,
        temperature: 0.3,
        maxOutputTokens: 2048,
      );
      final decoded = ModelSelection.fromJson(selection.toJson());
      expect(decoded.profileId, 'p1');
      expect(decoded.modelId, 'm1');
      expect(decoded.reasoningEffort, ReasoningEffort.high);
      expect(decoded.temperature, 0.3);
      expect(decoded.maxOutputTokens, 2048);
    });

    test('token 用量缺失时不写成零', () {
      final usage = TokenUsage.fromJson(const {});
      expect(usage.promptTokens, isNull);
      expect(usage.outputTokens, isNull);
      expect(usage.source(UsageField.promptTokens), isNull);
      expect(
        const TokenUsage(promptTokens: 5).source(UsageField.promptTokens),
        UsageSource.reported,
      );
    });

    test('工具策略默认按询问处理', () {
      expect(toolPolicyFromName(null), ToolPolicy.ask);
      expect(toolPolicyFromName('unknown'), ToolPolicy.ask);
      expect(toolPolicyFromName('allow'), ToolPolicy.allow);
    });
  });
}
