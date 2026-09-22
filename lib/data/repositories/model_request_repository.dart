import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/error/failure.dart';
import '../datasources/local/app_database.dart';
import '../models/model_request_record.dart';
import '../models/token_usage.dart';

part 'model_request_repository.g.dart';

ModelRequestRecord modelRequestFromRow(ModelRequestRow r) => ModelRequestRecord(
  id: r.id,
  conversationId: r.conversationId,
  runId: r.runId,
  logicalTurn: r.logicalTurn,
  attemptIndex: r.attemptIndex,
  purpose: ModelRequestPurpose.values.byName(r.purpose),
  status: ModelRequestStatus.values.byName(r.status),
  profileId: r.profileId,
  protocol: r.protocol,
  requestedModelId: r.requestedModelId,
  responseModelId: r.responseModelId,
  assistantMessageId: r.assistantMessageId,
  summaryId: r.summaryId,
  summaryJobId: r.summaryJobId,
  usage: r.usageJson == null
      ? null
      : TokenUsage.fromJson(jsonDecode(r.usageJson!) as Map<String, dynamic>),
  usageRevision: r.usageRevision,
  usageComplete: r.usageComplete,
  contextSnapshot: jsonDecode(r.contextJson) as Map<String, dynamic>,
  originRequestId: r.originRequestId,
  isInherited: r.isInherited,
  createdAt: r.createdAt,
  startedAt: r.startedAt,
  finishedAt: r.finishedAt,
  errorCode: r.errorCode,
);

class ModelRequestRepository {
  ModelRequestRepository(this.db);
  final AppDatabase db;

  Future<void> prepare(ModelRequestRecord r) => _guard(() async {
    await db
        .into(db.modelRequests)
        .insert(
          ModelRequestsCompanion.insert(
            id: r.id,
            conversationId: r.conversationId,
            runId: Value(r.runId),
            logicalTurn: r.logicalTurn,
            attemptIndex: r.attemptIndex,
            purpose: r.purpose.name,
            status: ModelRequestStatus.prepared.name,
            profileId: r.profileId,
            protocol: r.protocol,
            requestedModelId: r.requestedModelId,
            assistantMessageId: Value(r.assistantMessageId),
            summaryId: Value(r.summaryId),
            summaryJobId: Value(r.summaryJobId),
            contextJson: jsonEncode(r.contextSnapshot),
            createdAt: r.createdAt,
          ),
        );
  });

  Future<void> start(String id, {Future<void> Function()? onStart}) => _guard(
    () => db.transaction(() async {
      final changed =
          await (db.update(
            db.modelRequests,
          )..where((t) => t.id.equals(id) & t.status.equals('prepared'))).write(
            ModelRequestsCompanion(
              status: const Value('running'),
              startedAt: Value(DateTime.now()),
            ),
          );
      if (changed != 1) throw const StorageFailure('请求已开始或已收口，不能再次派发');
      await onStart?.call();
    }),
  );

  /// 停止发生在异步计次与订阅之间时，回退尚未真正派发的准备记录。
  Future<void> cancelBeforeStart(String id, {bool undoAttempt = false}) =>
      _guard(
        () => db.transaction(() async {
          final row = await (db.select(
            db.modelRequests,
          )..where((t) => t.id.equals(id))).getSingle();
          if (row.status != 'running') return;
          await (db.update(
            db.modelRequests,
          )..where((t) => t.id.equals(id))).write(
            const ModelRequestsCompanion(
              status: Value('prepared'),
              startedAt: Value(null),
            ),
          );
          if (undoAttempt && row.runId != null) {
            await db.customUpdate(
              'UPDATE agent_runs SET model_attempt_count = model_attempt_count - 1 WHERE id = ?',
              variables: [Variable<String>(row.runId!)],
              updates: {db.agentRuns},
            );
          }
        }),
      );

  Future<void> sample(
    String id,
    TokenUsage? usage,
    int revision, {
    String? responseModelId,
  }) => _guard(() async {
    await (db.update(db.modelRequests)..where(
          (t) =>
              t.id.equals(id) &
              t.status.equals('running') &
              t.usageRevision.isSmallerThanValue(revision),
        ))
        .write(
          ModelRequestsCompanion(
            usageJson: Value(usage == null ? null : jsonEncode(usage.toJson())),
            usageRevision: Value(revision),
            responseModelId: responseModelId == null
                ? const Value.absent()
                : Value(responseModelId),
          ),
        );
  });

  /// 调用者先等待节流写入；请求与消息/摘要的终态在同一事务中提交。
  Future<void> settle(
    String id, {
    required ModelRequestStatus status,
    required TokenUsage? usage,
    required int revision,
    bool usageComplete = false,
    String? responseModelId,
    String? errorCode,
    Future<void> Function()? persistResult,
  }) => _guard(
    () => db.transaction(() async {
      final row = await (db.select(
        db.modelRequests,
      )..where((t) => t.id.equals(id))).getSingle();
      if (row.status != 'running' && row.status != 'prepared') return;
      if (revision < row.usageRevision) throw const StorageFailure('请求用量修订已过期');
      await persistResult?.call();
      await (db.update(db.modelRequests)..where((t) => t.id.equals(id))).write(
        ModelRequestsCompanion(
          status: Value(status.name),
          usageJson: Value(usage == null ? null : jsonEncode(usage.toJson())),
          usageRevision: Value(revision),
          usageComplete: Value(usageComplete),
          responseModelId: responseModelId == null
              ? const Value.absent()
              : Value(responseModelId),
          finishedAt: Value(DateTime.now()),
          errorCode: Value(errorCode),
        ),
      );
    }),
  );

  Future<List<ModelRequestRecord>> list(String conversationId) => _guard(
    () async =>
        (await _query(conversationId).get()).map(modelRequestFromRow).toList(),
  );

  Stream<List<ModelRequestRecord>> watch(String conversationId) async* {
    try {
      yield* _query(conversationId)
          .watch()
          .map((rows) => rows.map(modelRequestFromRow).toList());
    } on Failure {
      rethrow;
    } catch (e) {
      throw StorageFailure('读取请求用量失败', cause: e);
    }
  }

  SimpleSelectStatement<$ModelRequestsTable, ModelRequestRow> _query(
    String id,
  ) => db.select(db.modelRequests)
    ..where((t) => t.conversationId.equals(id))
    ..orderBy([
      (t) => OrderingTerm.desc(t.createdAt),
      (t) => OrderingTerm.desc(t.id),
    ]);

  Future<void> interruptPending({
    String? runId,
    String errorCode = 'interrupted',
  }) => _guard(() async {
    await (db.update(db.modelRequests)..where(
          (t) =>
              t.status.isIn(['prepared', 'running']) &
              (runId == null ? const Constant(true) : t.runId.equals(runId)),
        ))
        .write(
          ModelRequestsCompanion(
            status: const Value('interrupted'),
            finishedAt: Value(DateTime.now()),
            errorCode: Value(errorCode),
          ),
        );
  });

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on Failure {
      rethrow;
    } catch (e) {
      throw StorageFailure('读写请求用量失败', cause: e);
    }
  }
}

@Riverpod(keepAlive: true)
Future<ModelRequestRepository> modelRequestRepository(Ref ref) async =>
    ModelRequestRepository(await ref.watch(appDatabaseProvider.future));

@riverpod
Stream<List<ModelRequestRecord>> conversationRequests(
  Ref ref,
  String conversationId,
) async* {
  yield* (await ref.watch(modelRequestRepositoryProvider.future))
      .watch(conversationId);
}
