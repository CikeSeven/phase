import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/error/failure.dart';
import 'package:phase/data/datasources/local/app_database.dart';
import 'package:phase/data/models/api_protocol.dart';
import 'package:phase/data/models/chat_message.dart';
import 'package:phase/data/models/chat_request.dart';
import 'package:phase/data/models/context_summary.dart';
import 'package:phase/data/models/provider_profile.dart';
import 'package:phase/data/repositories/agent_context_repository.dart';
import 'package:phase/data/repositories/model_request_repository.dart';
import 'package:phase/features/chat/context/compaction_coordinator.dart';
import 'package:phase/features/tools/tool.dart';

import '../../tools/tool_loop_harness.dart';

void main() {
  late AppDatabase db;
  late AgentContextRepository summaries;
  late ModelRequestRepository requests;
  late ScriptedProvider provider;
  final profile = ProviderProfile(
    id: 'p',
    name: 'fixture',
    protocol: ApiProtocol.openaiCompletions,
    baseUrl: 'https://fixture.test',
    createdAt: DateTime(2026),
  );
  final messages = [
    const ResolvedMessage(
      sourceMessageId: 'old-user',
      role: ChatRole.user,
      parts: [ResolvedText('旧任务')],
    ),
    for (var i = 0; i < 6; i++)
      ResolvedMessage(
        sourceMessageId: 'a$i',
        role: ChatRole.assistant,
        parts: [ResolvedText('detail-$i ${'x' * 5000}')],
      ),
    const ResolvedMessage(
      sourceMessageId: 'tail',
      role: ChatRole.user,
      parts: [ResolvedText('当前任务原文')],
    ),
  ];
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    summaries = AgentContextRepository(db);
    requests = ModelRequestRepository(db);
    provider = ScriptedProvider(ApiProtocol.openaiCompletions);
    await db
        .into(db.conversations)
        .insert(
          ConversationsCompanion.insert(
            id: 'c',
            title: 'fixture',
            currentMessageId: const Value('tail'),
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
        );
  });
  tearDown(() => db.close());
  Future<void> build({Future<List<ResolvedMessage>> Function()? reload}) async {
    await CompactionCoordinator(summaries: summaries, requests: requests).build(
      conversationId: 'c',
      runId: 'r',
      branchHeadId: 'tail',
      profile: profile,
      provider: provider,
      request: ChatRequest(
        modelId: 'm',
        messages: messages,
        maxOutputTokens: 2048,
      ),
      cancellation: RunCancellation(),
      protectedIds: {'tail'},
      canReadHistory: true,
      contextWindow: 21000,
      reloadMessages: reload,
    );
  }

  test('分段压缩只在最终候选符合预算后激活，中间阶段组成累计父链', () async {
    provider.turns.addAll([textTurn('阶段一结论'), textTurn('阶段一与新增材料的累计结论')]);
    await build();
    expect(provider.requests, hasLength(2));
    final checkpoints = await summaries.list('c');
    expect(checkpoints, hasLength(2));
    expect(
      checkpoints.where((s) => s.adoption == SummaryAdoption.applied),
      hasLength(1),
    );
    expect(checkpoints.first.parentSummaryId, checkpoints.last.id);
    expect(
      checkpoints.first.afterTokens,
      lessThan(checkpoints.first.beforeTokens!),
    );
    expect(
      (await requests.list('c')).map((r) => r.summaryJobId).toSet(),
      hasLength(1),
    );
    expect(
      provider.requests.last.messages.single.parts
          .whereType<ResolvedText>()
          .single
          .text,
      contains('previousSummary'),
    );
  });

  test('第二阶段失败不激活第一阶段，付出的两个请求均保留', () async {
    provider.turns.addAll([
      textTurn('阶段一'),
      Stream.error(Exception('fixture')),
    ]);
    await expectLater(build(), throwsA(isA<OperationFailure>()));
    expect(provider.requests, hasLength(2));
    expect(
      (await summaries.list('c'))
          .where((s) => s.adoption == SummaryAdoption.applied),
      isEmpty,
    );
    expect(await requests.list('c'), hasLength(2));
  });

  test('激活事务重新核对来源；内容修订不采用旧结果', () async {
    provider.turns.addAll([textTurn('阶段一'), textTurn('累计结论')]);
    await expectLater(
      build(reload: () async => [messages.first, ...messages.skip(2)]),
      throwsA(isA<OperationFailure>()),
    );
    final checkpoints = await summaries.list('c');
    expect(checkpoints.first.adoption, SummaryAdoption.stale);
    expect(
      checkpoints.where((s) => s.adoption == SummaryAdoption.applied),
      isEmpty,
    );
  });

  test('采用写库失败不发布检查点，已收口请求消耗不回滚为免费', () async {
    provider.turns.addAll([textTurn('阶段一'), textTurn('累计结论')]);
    await db.customStatement(
      "CREATE TRIGGER reject_activation BEFORE UPDATE ON context_summaries WHEN json_extract(NEW.checkpoint_json, '\$.adoption') = 'applied' BEGIN SELECT RAISE(ABORT, 'fixture'); END",
    );
    await expectLater(build(), throwsA(isA<StorageFailure>()));
    expect(
      (await summaries.list('c'))
          .where((s) => s.adoption == SummaryAdoption.applied),
      isEmpty,
    );
    expect(await requests.list('c'), hasLength(2));
  });
}
