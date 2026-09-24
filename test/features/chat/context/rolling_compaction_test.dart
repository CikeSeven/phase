import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/error/provider_error.dart';
import 'package:phase/data/models/agent_run.dart';
import 'package:phase/data/models/api_protocol.dart';
import 'package:phase/data/models/chat_chunk.dart';
import 'package:phase/data/models/chat_message.dart';
import 'package:phase/data/models/chat_request.dart';
import 'package:phase/data/models/context_summary.dart';
import 'package:phase/data/models/model_request_record.dart';
import 'package:phase/data/models/profile_model.dart';
import 'package:phase/data/models/token_usage.dart';
import 'package:phase/data/repositories/assistant_repository.dart';
import 'package:phase/data/repositories/agent_context_repository.dart';
import 'package:phase/data/repositories/model_request_repository.dart';
import 'package:phase/features/tools/file_tools.dart';
import 'package:phase/features/tools/tool.dart';
import 'package:phase/providers/ai_provider.dart';

import '../../tools/tool_loop_harness.dart';
import 'context_flow_test.dart' show longConversation;

class LongTaskProvider implements AiProvider {
  Future<void> Function()? prepareFile;
  final requests = <ChatRequest>[];
  int mainCalls = 0;
  int summaries = 0;
  @override
  ApiProtocol get protocol => ApiProtocol.openaiCompletions;
  @override
  Future<List<ProfileModel>> listModels() async => [];
  @override
  Stream<ChatChunk> streamChat(ChatRequest request) async* {
    requests.add(request);
    if (request.tools.isEmpty && request.systemPrompt.contains('累计摘要')) {
      summaries++;
      yield* textTurn('目标：汇总资料。已完成前缀读取 $summaries。下一步：继续原任务。关键来源见宿主引用。');
    } else {
      mainCalls++;
      if (mainCalls == 1) await prepareFile!();
      yield* mainCalls <= 12
          ? toolTurn(
              callId: 'repeated',
              toolName: 'read_file',
              arguments: '{"path":"source.txt"}',
            )
          : textTurn('完成汇总');
    }
  }
}

void main() {
  test('摘要期间编辑助手不改变会话历史读取许可', () async {
    final h = await longConversation();
    final stream = StreamController<ChatChunk>();
    h.provider.turns.add(stream.stream);
    final compacting = h.controller().compactContext(h.conversationId()!);
    await h.waitUntil(() => h.provider.requests.length == 3);
    final assistants = AssistantRepository(h.database);
    final assistant = (await assistants.getAssistants()).single;
    await assistants.save(assistant.copyWith(systemPrompt: '修改助手提示词'));
    for (final event in await textTurn('新摘要').toList()) {
      stream.add(event);
    }
    final notice = await compacting.timeout(const Duration(seconds: 2));
    await stream.close();
    expect(notice, contains('已采用摘要'));
    expect(
      (await AgentContextRepository(h.database).list(h.conversationId()!))
          .single
          .adoption,
      SummaryAdoption.applied,
    );
    expect(h.state().contextBuild!.summaryId, isNotNull);
  });

  test('生成完成但无收益不采用，摘要用量仍计入会话', () async {
    final h = await longConversation();
    h.provider.turns.add(
      Stream.fromIterable([
        ...(await textTurn(
          'expanded ' * 1500,
        ).toList()).where((c) => c is! ResponseEnd),
        const UsageChunk(
          usage: TokenUsage(
            promptTokens: 100,
            outputTokens: 50,
            totalTokens: 150,
          ),
        ),
        const ResponseEnd(),
      ]),
    );
    final original = (await h.branch()).map((m) => m.id).toList();
    await h.controller().compactContext(h.conversationId()!);
    final summary = (await AgentContextRepository(
      h.database,
    ).list(h.conversationId()!)).single;
    expect(summary.status, SummaryStatus.completed);
    expect(summary.adoption, SummaryAdoption.noGain);
    expect((await h.branch()).map((m) => m.id), original);
    final totals = RequestUsageTotals(
      await ModelRequestRepository(h.database).list(h.conversationId()!),
    );
    expect(totals.metric(UsageField.totalTokens).tokens, 150);
    expect(totals.requestCount, 3);
  });

  test('一条用户消息跨至少三次压缩续跑，增量摘要不重读起点或重放工具', () async {
    final provider = LongTaskProvider();
    final h = await ToolLoopHarness.create(
      registry: ToolRegistry([const ReadFileTool()]),
      models: const [
        ProfileModel(
          id: 'model-a',
          contextWindow: 26000,
          maxOutputTokens: 1000,
        ),
      ],
      factory: (_, _) => provider,
    );
    provider.prepareFile = () async {
      final directory = h.artifactsDir(h.conversationId()!);
      await directory.create(recursive: true);
      await File('${directory.path}/source.txt')
          .writeAsString('reference content\n' * 250);
    };
    await h.controller().send('持续阅读并汇总，不写文件，不重放外部动作');
    expect((await h.latestRun()).status, RunStatus.completed);
    expect(provider.summaries, greaterThanOrEqualTo(3));
    expect(provider.mainCalls, 13);
    expect((await h.latestRun()).modelAttemptCount, 13);
    final branch = await h.branch();
    expect(branch.where((m) => m.role == ChatRole.user), hasLength(1));
    expect(branch.where((m) => m.role == ChatRole.tool), hasLength(12));
    final checkpoints = await AgentContextRepository(h.database)
        .list(h.conversationId()!);
    expect(
      checkpoints.where((s) => s.adoption == SummaryAdoption.applied).length,
      provider.summaries,
    );
    final covered = <String>{};
    for (final request in provider.requests.where((r) => r.tools.isEmpty)) {
      final payload = jsonDecode(
        (request.messages.single.parts.single as ResolvedText).text,
      ) as Map;
      if (covered.isNotEmpty) expect(payload['previousSummary'], isNotNull);
      for (final message in payload['newHistory'] as List) {
        expect(covered.add(message['messageId'] as String), isTrue);
      }
    }
    final requests = await ModelRequestRepository(h.database)
        .list(h.conversationId()!);
    expect(
      requests.where((r) => r.purpose == ModelRequestPurpose.turnPrefixSummary),
      hasLength(provider.summaries),
    );
    final run = await h.latestRun();
    expect(requests.every((r) => r.runId == run.id), isTrue);
    expect(
      provider.requests.last.messages.any(
        (m) => m.sourceMessageId == branch.first.id,
      ),
      isTrue,
    );
  });

  test('手动整理无新用户消息/AgentRun，独立计量且不自动聊天', () async {
    final h = await longConversation();
    final originalRun = await h.latestRun();
    final originalBranch = await h.branch();
    h.provider.turns.add(textTurn('目标约束：不要付费或重复外部动作。历史结论。'));
    final notice = await h.controller().compactContext(h.conversationId()!);
    expect(notice, contains('已采用'));
    expect(
      (await h.branch()).map((m) => m.id),
      originalBranch.map((m) => m.id),
    );
    expect((await h.latestRun()).id, originalRun.id);
    final requests = await ModelRequestRepository(h.database)
        .list(h.conversationId()!);
    expect(requests.where((r) => r.runId == null), hasLength(1));
    expect(h.provider.requests, hasLength(3));
    expect(h.state().isGenerating, isFalse);
    // 后代重开复用活动检查点，不重新收费。
    await h.controller().openConversation(h.conversationId()!);
    h.provider.turns.add(textTurn('继续'));
    await h.controller().send('继续当前目标');
    expect(h.provider.requests, hasLength(4));
    expect(
      h.provider.requests.last.messages.first.parts
          .whereType<ResolvedText>()
          .first
          .text,
      contains('历史派生摘要'),
    );
  });

  test('手动整理停止阻止并发发送，不激活半截摘要', () async {
    final h = await longConversation();
    final stream = StreamController<ChatChunk>();
    h.provider.turns.add(stream.stream);
    final compacting = h.controller().compactContext(h.conversationId()!);
    await h.waitUntil(() => h.provider.requests.length == 3);
    await h.controller().send('不能并发发送');
    h.controller().stop();
    await compacting.timeout(const Duration(seconds: 2));
    await stream.close();
    expect(h.provider.requests, hasLength(3));
    expect(
      (await AgentContextRepository(h.database).list(h.conversationId()!))
          .single
          .status,
      SummaryStatus.cancelled,
    );
    expect((await h.branch()).last.text, isNot(contains('不能并发')));
    expect(h.state().isGenerating, isFalse);
  });

  test('服务端 contextLimit 每逻辑轮只压缩恢复一次，失败请求独立保留', () async {
    final h = await ToolLoopHarness.create(
      registry: ToolRegistry([]),
      models: const [
        ProfileModel(
          id: 'model-a',
          contextWindow: 40000,
          maxOutputTokens: 1000,
        ),
      ],
    );
    h.provider.turns.addAll([
      textTurn('old details ' * 700),
      textTurn('recent'),
    ]);
    await h.controller().send('old task');
    await h.controller().send('recent task');
    const overflow = ResponseError(
      error: ProviderError(ProviderErrorCategory.contextLimit, 'fixture'),
    );
    h.provider.turns.addAll([
      Stream.value(overflow),
      textTurn('累计简洁结论'),
      Stream.value(overflow),
    ]);
    await h.controller().send('继续');
    expect(h.provider.requests, hasLength(5));
    expect((await h.latestRun()).modelAttemptCount, 2);
    expect((await h.latestRun()).status, RunStatus.failed);
    final run = await h.latestRun();
    final attempts = (await ModelRequestRepository(h.database).list(
      h.conversationId()!,
    )).where((r) => r.runId == run.id && r.purpose == ModelRequestPurpose.chat);
    expect(attempts, hasLength(2));
    expect(
      attempts.every((r) => r.status == ModelRequestStatus.failed),
      isTrue,
    );
    expect(run.finishReason, RunFinishReason.contextLimit);
    expect(
      (await AgentContextRepository(h.database).list(h.conversationId()!))
          .single
          .adoption,
      SummaryAdoption.applied,
    );
  });
}
