import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/error/failure.dart';
import '../datasources/local/app_database.dart';
import '../models/context_summary.dart';

import 'model_request_repository.dart';

part 'agent_context_repository.g.dart';

class AgentContextRepository {
  AgentContextRepository(this.db);
  final AppDatabase db;

  Stream<List<ContextSummary>> watch(String conversationId) async* {
    try {
      final query =
          db.select(db.contextSummaries).join([
              leftOuterJoin(
                db.modelRequests,
                db.modelRequests.summaryId.equalsExp(db.contextSummaries.id),
              ),
            ])
            ..where(db.contextSummaries.conversationId.equals(conversationId))
            ..orderBy([
              OrderingTerm.desc(db.contextSummaries.createdAt),
              OrderingTerm.desc(db.contextSummaries.id),
            ]);
      yield* query.watch().map(
        (rows) => rows
            .map(
              (r) => _fromRow(
                r.readTable(db.contextSummaries),
                r.readTableOrNull(db.modelRequests),
              ),
            )
            .toList(),
      );
    } on Failure {
      rethrow;
    } catch (e) {
      throw StorageFailure('读取上下文摘要失败', cause: e);
    }
  }

  Future<List<ContextSummary>> list(String conversationId) => _guard(() async {
    final query =
        db.select(db.contextSummaries).join([
            leftOuterJoin(
              db.modelRequests,
              db.modelRequests.summaryId.equalsExp(db.contextSummaries.id),
            ),
          ])
          ..where(db.contextSummaries.conversationId.equals(conversationId))
          ..orderBy([
            OrderingTerm.desc(db.contextSummaries.createdAt),
            OrderingTerm.desc(db.contextSummaries.id),
          ]);
    return (await query.get())
        .map(
          (r) => _fromRow(
            r.readTable(db.contextSummaries),
            r.readTableOrNull(db.modelRequests),
          ),
        )
        .toList();
  });

  Future<void> save(ContextSummary summary) => _guard(() async {
    await db
        .into(db.contextSummaries)
        .insertOnConflictUpdate(
          ContextSummariesCompanion.insert(
            id: summary.id,
            conversationId: summary.conversationId,
            runId: Value(summary.runId),
            branchEndId: summary.branchEndId,
            coveredIdsJson: jsonEncode(summary.coveredMessageIds),
            fingerprint: summary.fingerprint,
            sourceModel: summary.sourceModel,
            version: summary.version,
            status: summary.status.name,
            content: summary.text,
            checkpointJson: Value(jsonEncode(summary.checkpoint)),
            createdAt: summary.createdAt,
          ),
        );
  });

  /// 当前分支尚未变化且请求已收口，才可在事务内发布采用结果。
  Future<bool> activate(
    ContextSummary summary, {
    required String expectedHead,
    required bool Function() isCancelled,
    Future<bool> Function()? validateSource,
  }) => _guard(
    () => db.transaction(() async {
      final conversation = await (db.select(
        db.conversations,
      )..where((t) => t.id.equals(summary.conversationId))).getSingleOrNull();
      if (isCancelled() ||
          conversation?.currentMessageId != expectedHead ||
          (validateSource != null && !await validateSource()) ||
          isCancelled()) {
        await save(
          summary.finish(
            summary.status,
            summary.text,
            adoption: SummaryAdoption.stale,
            reason: '来源分支已变化或操作已停止',
          ),
        );
        return false;
      }
      await save(
        summary.finish(
          summary.status,
          summary.text,
          adoption: SummaryAdoption.applied,
        ),
      );
      return true;
    }),
  );

  ContextSummary _fromRow(ContextSummaryRow r, ModelRequestRow? request) {
    final checkpoint = jsonDecode(r.checkpointJson) as Map<String, dynamic>;
    return ContextSummary(
      id: r.id,
      conversationId: r.conversationId,
      runId: r.runId,
      branchEndId: r.branchEndId,
      coveredMessageIds: (jsonDecode(r.coveredIdsJson) as List).cast<String>(),
      fingerprint: r.fingerprint,
      sourceModel: r.sourceModel,
      version: r.version,
      status: SummaryStatus.values.byName(r.status),
      text: r.content,
      usage: request == null ? null : modelRequestFromRow(request).usage,
      createdAt: r.createdAt,
      parentSummaryId: checkpoint['parentSummaryId'] as String?,
      jobId: checkpoint['summaryJobId'] as String?,
      firstKeptMessageId: checkpoint['firstKeptMessageId'] as String?,
      sourceGeneration: checkpoint['sourceGeneration'] as String? ?? 'original',
      resultingGeneration: checkpoint['resultingGeneration'] as String?,
      adoption: SummaryAdoption.values.byName(
        checkpoint['adoption'] as String? ?? 'pending',
      ),
      beforeTokens: checkpoint['beforeTokens'] as int?,
      afterTokens: checkpoint['afterTokens'] as int?,
      targetTokens: checkpoint['targetTokens'] as int?,
      reason: checkpoint['reason'] as String?,
    );
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on Failure {
      rethrow;
    } on Exception catch (e) {
      throw StorageFailure('读写上下文摘要失败', cause: e);
    }
  }
}

@Riverpod(keepAlive: true)
Future<AgentContextRepository> agentContextRepository(Ref ref) async =>
    AgentContextRepository(await ref.watch(appDatabaseProvider.future));
