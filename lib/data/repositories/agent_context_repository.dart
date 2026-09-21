import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/error/failure.dart';
import '../datasources/local/app_database.dart';
import '../models/chat_message.dart';
import '../models/context_summary.dart';

part 'agent_context_repository.g.dart';

class AgentContextRepository {
  AgentContextRepository(this.db);
  final AppDatabase db;

  Future<List<ContextSummary>> list(String conversationId) => _guard(() async {
    final rows =
        await (db.select(db.contextSummaries)
              ..where((t) => t.conversationId.equals(conversationId))
              ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
            .get();
    return rows.map(_fromRow).toList();
  });

  Future<void> save(ContextSummary summary) => _guard(() async {
    await db
        .into(db.contextSummaries)
        .insertOnConflictUpdate(
          ContextSummariesCompanion.insert(
            id: summary.id,
            conversationId: summary.conversationId,
            runId: summary.runId,
            branchEndId: summary.branchEndId,
            coveredIdsJson: jsonEncode(summary.coveredMessageIds),
            fingerprint: summary.fingerprint,
            sourceModel: summary.sourceModel,
            version: summary.version,
            status: summary.status.name,
            content: summary.text,
            usageJson: Value(
              summary.usage == null
                  ? null
                  : jsonEncode(summary.usage!.toJson()),
            ),
            createdAt: summary.createdAt,
          ),
        );
  });

  ContextSummary _fromRow(ContextSummaryRow r) => ContextSummary(
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
    usage: r.usageJson == null
        ? null
        : TokenUsage.fromJson(jsonDecode(r.usageJson!) as Map<String, dynamic>),
    createdAt: r.createdAt,
  );

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
