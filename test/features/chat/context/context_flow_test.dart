import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:phase/data/models/agent_run.dart';
import 'package:phase/data/models/chat_chunk.dart';
import 'package:phase/data/models/chat_message.dart';
import 'package:phase/data/models/chat_request.dart';
import 'package:phase/data/models/context_summary.dart';
import 'package:phase/data/models/profile_model.dart';
import 'package:phase/data/repositories/agent_context_repository.dart';
import 'package:phase/data/repositories/memory_repository.dart';
import 'package:phase/features/tools/tool.dart';

import '../../tools/tool_loop_harness.dart';

Future<ToolLoopHarness> longConversation() async {
  final h = await ToolLoopHarness.create(
    registry: ToolRegistry([]),
    models: const [
      ProfileModel(id: 'model-a', contextWindow: 14000, maxOutputTokens: 1000),
    ],
  );
  h.provider.turns.addAll([textTurn('old ' * 1900), textTurn('recent ' * 320)]);
  await h.controller().send('约束：不要付费或重复外部动作');
  await h.controller().send('继续保留此要求');
  return h;
}

void main() {
  test('长会话自动摘要来源、覆盖范围、独立 API 用量与历史不变', () async {
    final h = await longConversation();
    final before = await h.branch();
    h.provider.turns.addAll([
      Stream.fromIterable([
        ...(await textTurn(
          '先前背景的简洁结论',
        ).toList()).where((c) => c is! ResponseEnd),
        const UsageChunk(
          usage: TokenUsage(inputTokens: 2100, outputTokens: 20),
        ),
        const ResponseEnd(),
      ]),
      textTurn('按原约束执行后续任务'),
    ]);
    await h.controller().send('现在继续');
    expect(h.provider.requests, hasLength(4));
    final summaryRequest = h.provider.requests[2];
    expect(summaryRequest.tools, isEmpty);
    expect(summaryRequest.systemPrompt, contains('历史材料'));
    final stored = await AgentContextRepository(h.database)
        .list(h.conversationId()!);
    expect(stored, hasLength(1));
    expect(stored.single.status, SummaryStatus.completed);
    expect(stored.single.coveredMessageIds, before.take(2).map((m) => m.id));
    expect(stored.single.usage?.inputTokens, 2100);
    final answerRequest = h.provider.requests.last;
    final texts = answerRequest.messages
        .expand((m) => m.parts)
        .whereType<ResolvedText>()
        .map((p) => p.text)
        .join();
    expect(texts, contains('不要付费或重复外部动作'));
    expect(texts, contains('recent '));
    expect(texts, contains('简洁结论'));
    expect(texts, isNot(contains('old ' * 100)));
    expect((await h.latestRun()).modelAttemptCount, 1);
    expect(
      (await h.branch()).take(before.length).map((m) => m.text),
      before.map((m) => m.text),
    );
    expect(await MemoryRepository(h.database).watch().first, isEmpty);
  });

  test('摘要失败只请求一次，原历史仍在预算内则继续聊天', () async {
    final h = await longConversation();
    h.provider.turns.addAll([
      Stream<ChatChunk>.error(Exception('fixture summary failure')),
      textTurn('原上下文回答'),
    ]);
    await h.controller().send('继续');
    expect(h.provider.requests, hasLength(4));
    expect(
      (await AgentContextRepository(h.database).list(h.conversationId()!))
          .single
          .status,
      SummaryStatus.failed,
    );
    expect(
      h.provider.requests.last.messages
          .expand((m) => m.parts)
          .whereType<ResolvedText>()
          .map((p) => p.text)
          .join(),
      contains('old '),
    );
    expect((await h.latestRun()).status, RunStatus.completed);
  });

  test('超限的当前输入不裁剪或暗改参数，保存可见失败且没有模型请求', () async {
    final h = await ToolLoopHarness.create(
      registry: ToolRegistry([]),
      models: const [
        ProfileModel(id: 'model-a', contextWindow: 6000, maxOutputTokens: 1000),
      ],
    );
    await h.controller().send('不能丢弃的约束' * 1000);
    expect(h.provider.requests, isEmpty);
    final run = await h.latestRun();
    expect(run.status, RunStatus.failed);
    expect(run.finishReason, RunFinishReason.contextLimit);
    expect(run.modelAttemptCount, 0);
    expect((await h.branch()).last.text, contains('上下文超出本地预算'));
  });

  test('摘要过程中停止保留历史与取消记录，不进入聊天请求', () async {
    final h = await longConversation();
    final stream = StreamController<ChatChunk>();
    h.provider.turns.add(stream.stream);
    final sending = h.controller().send('继续');
    await h.waitUntil(
      () => h.state().summarizing && h.provider.requests.length == 3,
    );
    h.controller().stop();
    await sending.timeout(const Duration(seconds: 2));
    await stream.close();
    final summary = (await AgentContextRepository(
      h.database,
    ).list(h.conversationId()!)).single;
    expect(summary.status, SummaryStatus.cancelled);
    expect(
      (await (await h.runs()).getById(summary.runId))!.status,
      RunStatus.stopped,
    );
    expect(h.provider.requests, hasLength(3));
    expect(h.state().isGenerating, isFalse);
    expect((await h.branch()).first.text, contains('约束'));
  });
}
