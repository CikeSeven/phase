import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/error/failure.dart';
import 'package:phase/data/datasources/local/app_database.dart';
import 'package:phase/data/models/model_request_record.dart';
import 'package:phase/data/models/token_usage.dart';
import 'package:phase/data/repositories/model_request_repository.dart';
import 'package:phase/data/repositories/agent_run_repository.dart';

void main() {
  late AppDatabase db;
  late ModelRequestRepository repository;
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repository = ModelRequestRepository(db);
    await db
        .into(db.conversations)
        .insert(
          ConversationsCompanion.insert(
            id: 'c',
            title: 'fixture',
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
        );
  });
  tearDown(() => db.close());
  Future<void> prepare(String id) => repository.prepare(
    ModelRequestRecord(
      id: id,
      conversationId: 'c',
      profileId: 'deleted-profile',
      protocol: 'openaiCompletions',
      requestedModelId: 'original-id',
      createdAt: DateTime(2026),
    ),
  );

  test('prepared 不计实际请求；同修订幂等，终态拒绝迟到采样', () async {
    await prepare('r');
    expect(RequestUsageTotals(await repository.list('c')).requestCount, 0);
    await repository.start('r');
    await repository.sample('r', const TokenUsage(promptTokens: 100), 1);
    await repository.sample('r', const TokenUsage(promptTokens: 80), 2);
    await repository.sample('r', const TokenUsage(promptTokens: 999), 2);
    expect((await repository.list('c')).single.usage!.promptTokens, 80);
    await repository.settle(
      'r',
      status: ModelRequestStatus.failed,
      usage: const TokenUsage(promptTokens: 80),
      revision: 2,
      errorCode: 'network',
    );
    await repository.sample('r', const TokenUsage(promptTokens: 999), 3);
    final totals = RequestUsageTotals(await repository.list('c'));
    expect(totals.metric(UsageField.promptTokens).tokens, 80);
    expect(totals.requestCount, 1);
    expect(totals.metric(UsageField.outputTokens).unknownRequests, 1);
  });

  test('相同数字的不同请求分别累计，缓存率只用成对覆盖集', () async {
    for (final id in ['a', 'b', 'missing-cache', 'unknown']) {
      await prepare(id);
      await repository.start(id);
      final usage = id == 'unknown'
          ? null
          : id == 'missing-cache'
          ? const TokenUsage(promptTokens: 1000)
          : const TokenUsage(
              promptTokens: 100,
              cacheReadTokens: 80,
              outputTokens: 10,
              reasoningTokens: 5,
              totalTokens: 110,
            );
      await repository.settle(
        id,
        status: ModelRequestStatus.completed,
        usage: usage,
        revision: 1,
      );
    }
    final totals = RequestUsageTotals(await repository.list('c'));
    expect(totals.metric(UsageField.promptTokens).tokens, 1200);
    expect(totals.metric(UsageField.totalTokens).tokens, 220);
    expect(totals.cacheHitRate, .8);
    expect(totals.cacheRequests, hasLength(2));
    expect(totals.completeCacheCoverage, isFalse);
    expect(totals.metric(UsageField.promptTokens).unknownRequests, 1);
  });

  test('请求终态与业务结果同一事务失败回滚，不发布伪成功', () async {
    await prepare('r');
    await repository.start('r');
    await expectLater(
      repository.settle(
        'r',
        status: ModelRequestStatus.completed,
        usage: const TokenUsage(promptTokens: 10),
        revision: 1,
        persistResult: () async {
          await (db.update(
            db.conversations,
          )..where((t) => t.id.equals('c'))).write(
            const ConversationsCompanion(title: Value('should rollback')),
          );
          throw StateError('fixture');
        },
      ),
      throwsA(isA<StorageFailure>()),
    );
    expect(
      (await repository.list('c')).single.status,
      ModelRequestStatus.running,
    );
    expect((await db.select(db.conversations).getSingle()).title, 'fixture');
  });

  test('重启收口无运行归属的手动请求，不补发；删除会话级联清理', () async {
    await prepare('manual');
    await repository.start('manual');
    await repository.sample('manual', const TokenUsage(promptTokens: 8), 1);
    await AgentRunRepository(db).recover(afterRestart: true);
    final request = (await repository.list('c')).single;
    expect(request.status, ModelRequestStatus.interrupted);
    expect(request.usage!.promptTokens, 8);
    expect(request.usageComplete, isFalse);
    await (db.delete(db.conversations)..where((t) => t.id.equals('c'))).go();
    expect(await repository.list('c'), isEmpty);
  });
}
