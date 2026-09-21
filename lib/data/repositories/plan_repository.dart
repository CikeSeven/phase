import '../models/tool_call_record.dart';
import '../models/chat_message.dart';
import '../models/message_part.dart';

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/error/failure.dart';
import '../../core/utils/id.dart';
import '../datasources/local/app_database.dart';
import '../models/agent_plan.dart';
import '../models/agent_run.dart';
import 'row_mappers.dart';

part 'plan_repository.g.dart';

class PlanRepository {
  PlanRepository(this.db);
  final AppDatabase db;

  Stream<List<AgentPlan>> watch(String conversationId) async* {
    try {
      yield* (db.select(db.agentPlans)
            ..where((t) => t.conversationId.equals(conversationId))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .watch()
          .map((rows) {
            final latest = <String, AgentPlan>{};
            for (final row in rows) {
              if ((latest[row.id]?.revision ?? 0) < row.revision) {
                latest[row.id] = _fromRow(row);
              }
            }
            return latest.values.toList();
          });
    } on Failure {
      rethrow;
    } on Exception catch (e) {
      throw StorageFailure('读取计划失败', cause: e);
    }
  }

  Future<AgentPlan> latest(String id) => _guard(() async {
    final row =
        await (db.select(db.agentPlans)
              ..where((t) => t.id.equals(id))
              ..orderBy([(t) => OrderingTerm.desc(t.revision)])
              ..limit(1))
            .getSingleOrNull();
    if (row == null) throw const OperationFailure('计划已不存在');
    return _fromRow(row);
  });

  Future<AgentPlan> submit({
    required String runId,
    required String toolCallId,
    required String title,
    required List<String> steps,
  }) => _guard(
    () => db.transaction(() async {
      validate(title, steps);
      final run = await (db.select(
        db.agentRuns,
      )..where((t) => t.id.equals(runId))).getSingle();
      final call = await (db.select(
        db.toolCalls,
      )..where((t) => t.id.equals(toolCallId))).getSingle();
      if (call.runId != runId ||
          call.toolName != 'submit_plan' ||
          call.status != ToolCallStatus.executing) {
        throw const OperationFailure('计划来源调用不匹配');
      }
      final config = agentRunFromRow(run).configuration;
      if (config.mode != AgentMode.plan || run.status != RunStatus.running) {
        throw const OperationFailure('只有正在进行的计划运行可以提交计划');
      }
      final previous =
          await (db.select(db.agentPlans)
                ..where((t) => t.sourceRunId.equals(runId))
                ..orderBy([(t) => OrderingTerm.desc(t.revision)])
                ..limit(1))
              .getSingleOrNull();
      final plan = AgentPlan(
        id: previous?.id ?? generateId(),
        revision: (previous?.revision ?? 0) + 1,
        conversationId: run.conversationId,
        sourceRunId: runId,
        sourceMessageId: call.assistantMessageId,
        title: title.trim(),
        steps: steps.map((s) => s.trim()).toList(),
        createdAt: DateTime.now(),
      );
      await _insert(plan);
      return plan;
    }),
  );

  Future<AgentPlan> edit(
    String id,
    int revision,
    String title,
    List<String> steps,
  ) => _guard(
    () => db.transaction(() async {
      validate(title, steps);
      final old = await _checkRevision(id, revision);
      await _checkIdle(old.conversationId);
      final plan = AgentPlan(
        id: id,
        revision: revision + 1,
        conversationId: old.conversationId,
        sourceRunId: old.sourceRunId,
        sourceMessageId: old.sourceMessageId,
        title: title.trim(),
        steps: steps.map((s) => s.trim()).toList(),
        createdAt: DateTime.now(),
      );
      await _insert(plan);
      return plan;
    }),
  );

  Future<void> cancel(String id, int revision) => _guard(
    () => db.transaction(() async {
      final plan = await _checkRevision(id, revision);
      if (plan.status != PlanStatus.draft) {
        throw const OperationFailure('只有待批准的计划可以取消');
      }
      await _checkIdle(plan.conversationId);
      await (db.update(db.agentPlans)
            ..where((t) => t.id.equals(id) & t.revision.equals(revision)))
          .write(AgentPlansCompanion(status: Value(PlanStatus.cancelled.name)));
    }),
  );

  /// 检查修订、分支与运行状态后原子批准并创建新运行，避免重复点击/迟到批准。
  Future<AgentRun> approveAndCreate(AgentPlan expected, AgentRun run) => _guard(
    () => db.transaction(() async {
      final plan = await _checkRevision(expected.id, expected.revision);
      await _checkIdle(plan.conversationId);
      if (plan.status != PlanStatus.draft ||
          run.conversationId != plan.conversationId ||
          run.configuration.mode != AgentMode.execute ||
          run.configuration.planId != plan.id ||
          run.configuration.planRevision != plan.revision ||
          run.configuration.approvedPlan != plan.text) {
        throw const OperationFailure('计划状态已变化，请重新打开当前修订');
      }
      final conversation = await (db.select(
        db.conversations,
      )..where((t) => t.id.equals(plan.conversationId))).getSingle();
      var cursor = conversation.currentMessageId;
      var onBranch = false;
      final visited = <String>{};
      while (cursor != null && visited.add(cursor)) {
        if (cursor == plan.sourceMessageId) {
          onBranch = true;
          break;
        }
        cursor = (await (db.select(
          db.messages,
        )..where((t) => t.id.equals(cursor!))).getSingleOrNull())?.parentId;
      }
      if (!onBranch) throw const OperationFailure('计划来源不在当前分支，请重新规划');
      await db
          .into(db.messages)
          .insert(
            messageCompanion(
              ChatMessage(
                id: run.inputMessageId,
                conversationId: run.conversationId,
                parentId: conversation.currentMessageId,
                role: ChatRole.user,
                status: MessageStatus.completed,
                parts: [
                  TextPart(
                    text:
                        '批准并执行计划（${plan.id}，修订 ${plan.revision}）。具体工具仍按权限确认。\n${plan.text}',
                  ),
                ],
                createdAt: run.createdAt,
              ),
            ),
          );
      await (db.update(
        db.conversations,
      )..where((t) => t.id.equals(run.conversationId))).write(
        ConversationsCompanion(
          currentMessageId: Value(run.inputMessageId),
          updatedAt: Value(run.createdAt),
        ),
      );
      await db.into(db.agentRuns).insert(agentRunCompanion(run));
      await (db.update(db.agentPlans)..where(
            (t) => t.id.equals(plan.id) & t.revision.equals(plan.revision),
          ))
          .write(
            AgentPlansCompanion(
              status: Value(PlanStatus.approved.name),
              executionRunId: Value(run.id),
            ),
          );
      return run;
    }),
  );

  Future<void> _checkIdle(String conversationId) async {
    final active =
        await (db.select(db.agentRuns)..where(
              (t) =>
                  t.conversationId.equals(conversationId) &
                  t.status.isIn([
                    RunStatus.running.name,
                    RunStatus.awaitingConfirmation.name,
                    RunStatus.awaitingUser.name,
                  ]),
            ))
            .get();
    if (active.isNotEmpty) throw const OperationFailure('请先结束当前任务');
  }

  Future<AgentPlan> _checkRevision(String id, int revision) async {
    final plan = await latest(id);
    if (plan.revision != revision) {
      throw const OperationFailure('计划已修改，请查看最新修订后再操作');
    }
    return plan;
  }

  static void validate(String title, List<String> steps) {
    if (title.trim().isEmpty ||
        title.length > 200 ||
        steps.isEmpty ||
        steps.length > 30 ||
        steps.any((s) => s.trim().isEmpty || s.length > 2000)) {
      throw const OperationFailure('计划需要标题和 1–30 个非空步骤，标题最多 200 字，每步最多 2000 字');
    }
  }

  Future<void> _insert(AgentPlan p) async {
    await db
        .into(db.agentPlans)
        .insert(
          AgentPlansCompanion.insert(
            id: p.id,
            revision: p.revision,
            conversationId: p.conversationId,
            sourceRunId: p.sourceRunId,
            sourceMessageId: p.sourceMessageId,
            title: p.title,
            stepsJson: jsonEncode(p.steps),
            status: p.status.name,
            createdAt: p.createdAt,
          ),
        );
  }

  AgentPlan _fromRow(AgentPlanRow r) => AgentPlan(
    id: r.id,
    revision: r.revision,
    conversationId: r.conversationId,
    sourceRunId: r.sourceRunId,
    sourceMessageId: r.sourceMessageId,
    title: r.title,
    steps: (jsonDecode(r.stepsJson) as List).cast<String>(),
    status: PlanStatus.values.byName(r.status),
    executionRunId: r.executionRunId,
    createdAt: r.createdAt,
  );

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on Failure {
      rethrow;
    } on Exception catch (e) {
      throw StorageFailure('读写计划失败', cause: e);
    }
  }
}

@Riverpod(keepAlive: true)
Future<PlanRepository> planRepository(Ref ref) async =>
    PlanRepository(await ref.watch(appDatabaseProvider.future));

@riverpod
Stream<List<AgentPlan>> conversationPlans(
  Ref ref,
  String conversationId,
) async* {
  yield* (await ref.watch(planRepositoryProvider.future)).watch(conversationId);
}
