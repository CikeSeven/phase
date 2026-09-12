import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/error/failure.dart';
import '../../core/utils/logger.dart';
import '../datasources/local/app_database.dart';
import '../models/agent_run.dart';
import '../models/chat_message.dart';
import 'row_mappers.dart';

part 'agent_run_repository.g.dart';

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
                    RunStatus.awaitingResult.name,
                  ]),
                )
                ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
              .get();
      return rows.map(agentRunFromRow).toList();
    });
  }

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
        activeToolCallId: null,
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

  /// 动作已派发但结果未取得：挂起运行，等待核验。
  Future<AgentRun> waitForResult(String runId, String toolCallId) {
    return _update(runId, '等待工具结果失败', (run) {
      return run.copyWith(
        status: RunStatus.awaitingResult,
        activeToolCallId: toolCallId,
      );
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
      AppLogger.error(message, e, st);
      throw UnknownFailure(message, cause: e);
    }
  }
}

@Riverpod(keepAlive: true)
Future<AgentRunRepository> agentRunRepository(Ref ref) async {
  final database = await ref.watch(appDatabaseProvider.future);
  return AgentRunRepository(database);
}
