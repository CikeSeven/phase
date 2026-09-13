import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/error/failure.dart';
import '../../core/utils/logger.dart';
import '../datasources/local/app_database.dart';
import '../models/agent_run.dart';
import '../models/chat_message.dart';
import '../models/tool_call_record.dart';
import 'row_mappers.dart';

part 'agent_run_repository.g.dart';

class RecoveredRun {
  const RecoveredRun({
    required this.run,
    required this.title,
    required this.calls,
  });
  final AgentRun run;
  final String title;
  final List<ToolCallRecord> calls;
}

/// 运行的读写：保存循环位置、计数与终态，供中断后按已存状态恢复。
class AgentRunRepository {
  AgentRunRepository(this._db);

  final AppDatabase _db;

  Future<AgentRun> create(AgentRun run) {
    return _guard('创建运行失败', () async {
      await _db.into(_db.agentRuns).insert(agentRunCompanion(run));
      return run;
    });
  }

  Future<AgentRun?> getById(String id) {
    return _guard('读取运行失败', () async {
      final row = await (_db.select(
        _db.agentRuns,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      return row == null ? null : agentRunFromRow(row);
    });
  }

  Stream<AgentRun?> watchById(String id) {
    return (_db.select(_db.agentRuns)..where((t) => t.id.equals(id)))
        .watchSingleOrNull()
        .map((row) => row == null ? null : agentRunFromRow(row));
  }

  /// 未结束的运行：启动时读取，不重新执行已保存结果的动作。
  Future<List<AgentRun>> unfinished() {
    return _guard('读取未结束运行失败', () async {
      final rows =
          await (_db.select(_db.agentRuns)
                ..where(
                  (t) => t.status.isIn([
                    RunStatus.running.name,
                    RunStatus.awaitingConfirmation.name,
                  ]),
                )
                ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
              .get();
      return rows.map(agentRunFromRow).toList();
    });
  }

  /// 启动时核对已派发动作；后续刷新只处理原确认期限，不触碰活跃任务。
  Future<List<RecoveredRun>> recover({
    bool afterRestart = false,
    String? activeRunId,
  }) {
    return _guard(
      '读取中断任务失败',
      () => _db.transaction(() async {
        final rows =
            await (_db.select(_db.agentRuns)
                  ..where(
                    (t) => t.status.isIn([
                      RunStatus.running.name,
                      RunStatus.awaitingConfirmation.name,
                    ]),
                  )
                  ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
                .get();
        final recovered = <RecoveredRun>[];
        final now = DateTime.now();
        for (final row in rows) {
          if (row.id == activeRunId) continue;
          final callRows =
              await (_db.select(_db.toolCalls)
                    ..where((t) => t.runId.equals(row.id))
                    ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
                  .get();
          final calls = <ToolCallRecord>[];
          for (final value in callRows) {
            var call = toolCallFromRow(value);
            if (afterRestart && call.status == ToolCallStatus.executing) {
              call = call.copyWith(
                status: ToolCallStatus.failed,
                result: call.result ?? '上次运行中断，工具未返回完整结果。需要时先读取当前状态。',
                errorCode: 'interrupted',
                finishedAt: now,
              );
            } else if (call.status == ToolCallStatus.awaitingConfirmation &&
                call.confirmationExpiresAt?.isAfter(now) != true) {
              call = call.copyWith(
                status: ToolCallStatus.rejected,
                decision: ToolDecision.expired,
                decidedAt: now,
                finishedAt: now,
                result: '确认已过期，没有执行。',
              );
            }
            if (call.status != value.status) {
              await (_db.update(_db.toolCalls)
                    ..where((t) => t.id.equals(call.id)))
                  .write(toolCallCompanion(call));
            }
            calls.add(call);
          }
          if (afterRestart) {
            await (_db.update(_db.messages)..where(
                  (t) =>
                      t.runId.equals(row.id) &
                      t.status.equals(MessageStatus.streaming.name),
                ))
                .write(
                  const MessagesCompanion(
                    status: Value(MessageStatus.cancelled),
                  ),
                );
          }
          final awaiting = calls
              .where((c) => c.status == ToolCallStatus.awaitingConfirmation)
              .firstOrNull;
          final run = agentRunFromRow(row).copyWith(
            status: awaiting != null
                ? RunStatus.awaitingConfirmation
                : RunStatus.running,
            activeToolCallId: awaiting?.id,
            clearActiveToolCall: awaiting == null,
          );
          await (_db.update(
            _db.agentRuns,
          )..where((t) => t.id.equals(run.id))).write(
            agentRunCompanion(run).copyWith(
              finishedAt: const Value(null),
              finishReason: const Value(null),
            ),
          );
          final conversation = await (_db.select(
            _db.conversations,
          )..where((t) => t.id.equals(run.conversationId))).getSingle();
          recovered.add(
            RecoveredRun(
              run: (await getById(run.id))!,
              title: conversation.title,
              calls: calls,
            ),
          );
        }
        return recovered;
      }),
    );
  }

  /// 用户结束中断任务；保留已执行动作的结果，不宣称已撤销。
  Future<void> stopRecovered(String id) => _guard(
    '结束中断任务失败',
    () => _db.transaction(() async {
      final rows = await (_db.select(
        _db.toolCalls,
      )..where((t) => t.runId.equals(id))).get();
      for (final row in rows) {
        if (row.status != ToolCallStatus.prepared &&
            row.status != ToolCallStatus.awaitingConfirmation) {
          continue;
        }
        await (_db.update(
          _db.toolCalls,
        )..where((t) => t.id.equals(row.id))).write(
          ToolCallsCompanion(
            status: const Value(ToolCallStatus.cancelled),
            result: const Value('用户停止了任务，没有执行本次动作。'),
            finishedAt: Value(DateTime.now()),
          ),
        );
      }
      await finish(
        id,
        status: RunStatus.stopped,
        finishReason: RunFinishReason.cancelled,
      );
    }),
  );

  /// 本轮模型调用前增加轮次计数。
  Future<AgentRun> beginTurn(String runId) {
    return _update(runId, '开始轮次失败', (run) {
      return run.copyWith(turnCount: run.turnCount + 1);
    });
  }

  /// 每次实际发出的模型请求（含重试）计入尝试数。
  Future<AgentRun> countModelAttempt(String runId) {
    return _update(runId, '记录模型尝试失败', (run) {
      return run.copyWith(modelAttemptCount: run.modelAttemptCount + 1);
    });
  }

  /// 本轮工具执行完成，保存当前位置；不重复增加轮次。
  Future<AgentRun> finishTurn(String runId, {String? currentMessageId}) {
    return _update(runId, '结束轮次失败', (run) {
      return run.copyWith(
        currentMessageId: currentMessageId,
        clearActiveToolCall: true,
      );
    });
  }

  /// 等待用户确认：位置与待确认调用一起落库。
  Future<AgentRun> awaitConfirmation(String runId, String toolCallId) {
    return _update(runId, '等待确认失败', (run) {
      return run.copyWith(
        status: RunStatus.awaitingConfirmation,
        activeToolCallId: toolCallId,
      );
    });
  }

  /// 用户已对确认作出决定：运行回到运行中，不再停在等待确认。
  ///
  /// 批准与拒绝都在决定落库后调用它；等待期间被停止的运行走终态，
  /// 不经过这里（执行器按取消收口）。
  Future<AgentRun> resume(String runId) {
    return _update(runId, '恢复运行状态失败', (run) {
      return run.copyWith(status: RunStatus.running, clearActiveToolCall: true);
    });
  }

  Future<AgentRun> finish(
    String runId, {
    required RunStatus status,
    RunFinishReason? finishReason,
    String? currentMessageId,
    TokenUsage? usage,
  }) {
    return _guard('结束运行失败', () async {
      await _db.transaction(() async {
        final row = await (_db.select(
          _db.agentRuns,
        )..where((t) => t.id.equals(runId))).getSingleOrNull();
        if (row == null) {
          throw const UnknownFailure('运行记录已丢失');
        }
        final run = agentRunFromRow(row);
        final finished = run.copyWith(
          status: status,
          finishReason: finishReason,
          currentMessageId: currentMessageId,
          clearActiveToolCall: true,
          usage: usage,
          finishedAt: DateTime.now(),
        );
        await (_db.update(
          _db.agentRuns,
        )..where((t) => t.id.equals(runId))).write(agentRunCompanion(finished));
        if (status != RunStatus.completed) {
          await (_db.update(_db.messages)..where(
                (t) =>
                    t.runId.equals(runId) &
                    t.status.equals(MessageStatus.streaming.name),
              ))
              .write(
                MessagesCompanion(
                  status: Value(
                    status == RunStatus.stopped
                        ? MessageStatus.cancelled
                        : MessageStatus.failed,
                  ),
                ),
              );
        }
        if (status == RunStatus.stopped) {
          await (_db.update(_db.toolCalls)..where(
                (t) =>
                    t.runId.equals(runId) &
                    t.status.isIn([
                      ToolCallStatus.prepared.name,
                      ToolCallStatus.awaitingConfirmation.name,
                    ]),
              ))
              .write(
                ToolCallsCompanion(
                  status: const Value(ToolCallStatus.cancelled),
                  result: const Value('任务已停止，本次动作没有执行。'),
                  finishedAt: Value(DateTime.now()),
                ),
              );
        }
      });
      final updated = await getById(runId);
      if (updated == null) {
        throw const UnknownFailure('运行记录已丢失');
      }
      return updated;
    });
  }

  Future<AgentRun> _update(
    String runId,
    String failureMessage,
    AgentRun Function(AgentRun run) change,
  ) {
    return _guard(failureMessage, () async {
      return _db.transaction(() async {
        final row = await (_db.select(
          _db.agentRuns,
        )..where((t) => t.id.equals(runId))).getSingle();
        final updated = change(agentRunFromRow(row));
        await (_db.update(
          _db.agentRuns,
        )..where((t) => t.id.equals(runId))).write(agentRunCompanion(updated));
        return updated;
      });
    });
  }

  Future<T> _guard<T>(String message, Future<T> Function() action) async {
    try {
      return await action();
    } on Failure {
      rethrow;
    } on Exception catch (e, st) {
      AppLogger.error('$message (${e.runtimeType})', null, st);
      throw StorageFailure(message, cause: e);
    }
  }
}

@Riverpod(keepAlive: true)
Future<AgentRunRepository> agentRunRepository(Ref ref) async {
  final database = await ref.watch(appDatabaseProvider.future);
  return AgentRunRepository(database);
}
