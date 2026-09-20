import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:phase/data/models/chat_message.dart';
import 'package:phase/data/models/chat_request.dart';
import 'package:phase/data/models/reasoning_effort.dart';
import 'package:phase/data/models/tool_policy.dart';
import 'package:phase/providers/openai_responses/responses_decoder.dart';

void main() {
  test('普通 Responses 首轮完整请求与 pi 的同参构造结果一致', () async {
    // fixture 由 pi 6160683a4a8012f0d1cd30c145df18b4ca6f5176 的
    // openai-responses.ts::buildParams + convertResponsesMessages/Tools 生成。
    // 纯本地构造：没有联网、凭据或历史消息；包含 pi streamSimple 从
    // fixture 模型元数据取得的 128000 上限，并显式配置
    // compat.supportsStrictMode=true，使 pi 发送 strict:false 保留可选参数。
    // 相月需显式提供相同参数，
    // 不能用此用例声称两者的默认模型参数/完整 Agent 行为相同。
    final expected = jsonDecode(
      File('test/fixtures/providers/pi_responses_first_turn.json')
          .readAsStringSync(),
    );
    final actual = await buildResponsesPayload(
      const ChatRequest(
        modelId: 'gpt-6-astra',
        systemPrompt: 'fixture system',
        messages: [
          ResolvedMessage(
            role: ChatRole.user,
            parts: [ResolvedText('fixture user')],
          ),
        ],
        tools: [_FixtureTool()],
        reasoningEffort: ReasoningEffort.high,
        maxOutputTokens: 128000,
      ),
    );
    expect(actual, expected);
  });
}

class _FixtureTool implements ToolDefinition {
  const _FixtureTool();

  @override
  String get name => 'fixture_tool';

  @override
  String get description => 'fixture description';

  @override
  Map<String, dynamic> get inputSchema => {
    'type': 'object',
    'properties': <String, dynamic>{},
  };

  @override
  Set<String> get requiredCapabilities => const {};

  @override
  ToolPolicy get defaultPolicy => ToolPolicy.allow;

  @override
  String describeAction(Map<String, dynamic> arguments) => name;
}
