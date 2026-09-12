import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/error/provider_error.dart';
import 'package:phase/core/utils/id.dart';
import 'package:phase/data/models/chat_chunk.dart';
import 'package:phase/data/models/chat_message.dart';
import 'package:phase/data/models/chat_request.dart';
import 'package:phase/data/models/message_part.dart';
import 'package:phase/data/models/tool_call_record.dart';
import 'package:phase/data/models/tool_policy.dart';
import 'package:phase/features/tools/tool.dart';

import '../tools/tool_loop_harness.dart';

/// 请求上下文的组装规则（对齐 pi 的 transform-messages）：
/// 出错/中止的轮次整条不进上下文、孤儿调用补合成结果、
/// 跨模型的协议状态不回传，以及流式增量按节拍合批发布。
void main() {
  test('出错那一轮保留已产出的正文，丢掉半截的思考', () async {
    final harness = await ToolLoopHarness.create();
    harness.provider.turns.addAll([
      // 先想一半、说半句，再以流内错误收场：这一轮按失败落库。
      Stream.fromIterable([
        const ReasoningDelta(partId: 'reasoning_0', text: '想到一半'),
        const TextDelta(partId: 'text_0', text: '半句话'),
        ResponseError(
          error: const ProviderError(
            ProviderErrorCategory.providerError,
            '服务出错',
          ),
        ),
      ]),
      textTurn('重新回答'),
    ]);

    await harness.controller().send('第一个问题');
    await harness.controller().send('第二个问题');

    expect(
      (await harness.branch()).any(
        (message) => message.status == MessageStatus.failed,
      ),
      isTrue,
      reason: '第一轮应当按失败落库',
    );

    // 已产出的正文进上下文：模型要知道自己刚说过什么、做过什么。
    final second = harness.provider.requests.last;
    expect(
      second.messages.any(
        (message) => message.parts.whereType<ResolvedText>().any(
          (part) => part.text.contains('半句话'),
        ),
      ),
      isTrue,
    );
    // 半截的思考不进：回放会把模型带回被打断的思路。
    expect(
      second.messages
          .expand((message) => message.parts)
          .whereType<ResolvedReasoning>(),
      isEmpty,
    );
  });

  test('手动停止后，已经执行过的工具调用与结果留在上下文里', () async {
    final harness = await ToolLoopHarness.create(
      registry: ToolRegistry([
        RecordingTool(name: 'echo', policy: ToolPolicy.allow),
      ]),
    );
    final stream = StreamController<ChatChunk>();
    harness.provider.turns.addAll([
      // 第一轮：调用工具，正常跑完。
      toolTurn(callId: 'call_1', toolName: 'echo', arguments: '{}'),
      // 第二轮：说半句就被用户停掉。
      stream.stream,
    ]);

    final sending = harness.controller().send('跑一次工具');
    await harness.waitUntil(() async {
      final records = await harness.recordsByCall();
      return records.containsKey('call_1');
    });
    // 等第二轮真的开始，再推一点内容后停止。
    await harness.waitUntil(() => harness.provider.requests.length >= 2);
    stream.add(const TextDelta(partId: 'text_0', text: '正在总结'));
    await Future<void>.delayed(const Duration(milliseconds: 80));
    harness.controller().stop();
    await stream.close();
    await sending;

    final branch = await harness.branch();
    expect(
      branch.any((message) => message.status == MessageStatus.cancelled),
      isTrue,
      reason: '被停止的那一轮按中止落库',
    );

    harness.provider.turns.add(textTurn('换成别的方式'));
    await harness.controller().send('换个方法');

    // 下一轮带着「调用过 echo、结果是什么」以及被停掉那半句话。
    final request = harness.provider.requests.last;
    final call = request.messages
        .expand((message) => message.parts)
        .whereType<ResolvedToolCall>()
        .single;
    expect(call.callId, 'call_1');
    expect(
      request.messages
          .expand((message) => message.parts)
          .whereType<ResolvedToolResult>()
          .single
          .callId,
      'call_1',
    );
    expect(
      request.messages.any(
        (message) => message.parts.whereType<ResolvedText>().any(
          (part) => part.text.contains('正在总结'),
        ),
      ),
      isTrue,
    );
  });

  test('有调用没结果时补一条合成结果，而不是把调用删掉', () async {
    final harness = await ToolLoopHarness.create();
    harness.provider.turns.add(textTurn('先回答一次'));
    await harness.controller().send('先建个会话');
    final conversations = await harness.conversations();
    final toolCalls = await harness.toolCalls();
    final conversationId = harness.conversationId()!;
    final tail = await conversations.getThread(conversationId);
    // 记录挂在真实运行上（外键约束），历史那一轮借用它的 id。
    final runId = (await harness.latestRun()).id;

    // 造一条历史：助手发起了调用，但结果消息缺失（运行中断）。
    final callId = generateId();
    final assistant = ChatMessage(
      id: generateId(),
      conversationId: conversationId,
      parentId: tail!.currentMessageId,
      role: ChatRole.assistant,
      status: MessageStatus.completed,
      modelLabel: 'model-a',
      parts: [
        const TextPart(text: '我读一下'),
        ToolCallPart(toolCallId: callId),
      ],
      createdAt: DateTime(2026),
    );
    await conversations.appendMessage(assistant);
    await toolCalls.create(
      ToolCallRecord(
        id: callId,
        runId: runId,
        assistantMessageId: assistant.id,
        providerCallId: 'call_old',
        toolName: 'read_file',
        arguments: const {'reference': 'notes.txt'},
        channel: ExecutionChannel.app,
        defaultPolicy: ToolPolicy.allow,
        status: ToolCallStatus.prepared,
        createdAt: DateTime(2026),
      ),
    );

    harness.provider.turns.add(textTurn('继续'));
    await harness.controller().send('接着说');

    final request = harness.provider.requests.last;
    // 调用照旧回填，后面跟着一条如实说明的合成结果。
    final call = request.messages
        .expand((message) => message.parts)
        .whereType<ResolvedToolCall>()
        .single;
    expect(call.callId, 'call_old');
    final result = request.messages
        .expand((message) => message.parts)
        .whereType<ResolvedToolResult>()
        .single;
    expect(result.callId, 'call_old');
    expect(result.isError, isTrue);
    expect(result.content, contains('没有返回结果'));
  });

  test('跨模型的思考不带协议状态', () async {
    final harness = await ToolLoopHarness.create();
    harness.provider.turns.add(textTurn('先回答一次'));
    await harness.controller().send('先建个会话');
    final conversations = await harness.conversations();
    final conversationId = harness.conversationId()!;
    final tail = await conversations.getThread(conversationId);

    await conversations.appendMessage(
      ChatMessage(
        id: generateId(),
        conversationId: conversationId,
        parentId: tail!.currentMessageId,
        role: ChatRole.assistant,
        status: MessageStatus.completed,
        // 上一个模型产生的回答：签名对它有效，对当前模型无效。
        modelLabel: 'model-old',
        parts: const [
          ReasoningPart(
            publicText: '旧的思考',
            providerData: {'signature': 'sig-old'},
          ),
          TextPart(text: '旧的回答'),
        ],
        createdAt: DateTime(2026),
      ),
    );

    harness.provider.turns.add(textTurn('新回答'));
    await harness.controller().send('换个模型再问');

    final old = harness.provider.requests.last.messages.singleWhere(
      (message) => message.parts.any(
        (part) => part is ResolvedReasoning && part.text == '旧的思考',
      ),
    );
    // 协议状态照旧解析出来，回不回传由各协议编码器按 sameModel 决定。
    expect(old.sameModel, isFalse, reason: '上一个模型的回答不算同模型');
    expect(
      old.parts.whereType<ResolvedReasoning>().single.providerData,
      isNotNull,
    );
  });

  test('流式增量按节拍合批发布，收口时补齐最后一批', () async {
    final harness = await ToolLoopHarness.create();
    final stream = StreamController<ChatChunk>();
    harness.provider.turns.add(stream.stream);

    final sending = harness.controller().send('慢慢说');
    await harness.waitUntil(() => harness.provider.requests.isNotEmpty);

    stream.add(const TextDelta(partId: 'text_0', text: '第一'));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    // 增量刚到，还没到发布节拍：界面保持上一拍的内容。
    expect(harness.state().streamingParts, isEmpty);

    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(
      harness.state().streamingParts.whereType<TextPart>().single.text,
      '第一',
    );

    stream.add(const TextDelta(partId: 'text_0', text: '第二'));
    stream.add(const ResponseEnd());
    await stream.close();
    await sending;
    // 收口时最后一批已经补上，界面不会停在半句话上。
    final message = (await harness.branch()).last;
    expect(message.parts.whereType<TextPart>().single.text, '第一第二');
    expect(harness.state().isGenerating, isFalse);
  });
}
