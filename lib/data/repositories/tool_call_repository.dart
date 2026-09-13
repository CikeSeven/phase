import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/error/failure.dart';
import '../../core/utils/logger.dart';
import '../datasources/local/app_database.dart';
import '../models/tool_call_record.dart';
import 'row_mappers.dart';

part 'tool_call_repository.g.dart';

/// 工具调用记录的读写：状态流转按 design 第二部分 §5 的状态机推进。
///
/// 参数在记录创建时确定，执行期间不再修改；新的尝试使用新记录。
class ToolCallRepository {
  ToolCallRepository(this._db);

  /// 用户确认的默认期限（design 第一部分 §5.3）。
  static const confirmationTimeout = Duration(seconds: 60);

  final AppDatabase _db;

  Future<ToolCallRecord> create(ToolCallRecord record) {
    return _guard('创建工具记录失败', () async {
      await _db.into(_db.toolCalls).insert(toolCallCompanion(record));
      return record;
    });
  }

  Future<ToolCallRecord> getById(String id) {
    return _guard('读取工具记录失败', () async {
      final row = await (_db.select(
        _db.toolCalls,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      if (row == null) {
        throw const UnknownFailure('工具记录不存在');
      }
      return toolCallFromRow(row);
    });
  }

  Stream<ToolCallRecord> watchById(String id) {
    return (_db.select(_db.toolCalls)..where((t) => t.id.equals(id)))
        .watchSingleOrNull()
        .map((row) => row == null ? null : toolCallFromRow(row))
        .where((record) => record != null)
        .cast<ToolCallRecord>();
  }

  Future<List<ToolCallRecord>> getByRun(String runId) {
    return _guard('读取工具记录失败', () async {
      final rows =
          await (_db.select(_db.toolCalls)
                ..where((t) => t.runId.equals(runId))
                ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
              .get();
      return rows.map(toolCallFromRow).toList();
    });
  }

  /// 进入等待确认；期限从请求时刻起算，重新打开应用不重新计时。
  Future<ToolCallRecord> requestConfirmation(String id) {
    return _apply(id, '请求确认失败', (record) {
      if (record.status == ToolCallStatus.awaitingConfirmation) return record;
      final now = DateTime.now();
      return record.copyWith(
        status: ToolCallStatus.awaitingConfirmation,
        confirmationRequestedAt: record.confirmationRequestedAt ?? now,
        confirmationExpiresAt:
            record.confirmationExpiresAt ?? now.add(confirmationTimeout),
      );
    });
  }

  /// 记录用户决定；批准后由执行方推进到 executing。
  Future<ToolCallRecord> recordDecision(String id, ToolDecision decision) {
    return _apply(id, '记录确认决定失败', (record) {
      if (record.status != ToolCallStatus.awaitingConfirmation) {
        throw const OperationFailure('本次确认已经结束');
      }
      final now = DateTime.now();
      if (record.confirmationExpiresAt?.isAfter(now) != true) {
        decision = ToolDecision.expired;
      }
      return record.copyWith(
        decision: decision,
        decidedAt: now,
        status: switch (decision) {
          ToolDecision.approved => ToolCallStatus.prepared,
          ToolDecision.rejected => ToolCallStatus.rejected,
          ToolDecision.expired => ToolCallStatus.rejected,
        },
        result: decision == ToolDecision.approved
            ? null
            : (decision == ToolDecision.expired
                  ? '确认已过期，没有执行。'
                  : '用户拒绝了本次动作，没有执行。'),
        finishedAt: decision == ToolDecision.approved ? null : now,
      );
    });
  }

  /// 直接执行前的落库：先保存 executing，再派发外部动作。
  Future<ToolCallRecord> markExecuting(String id) {
    return _guard(
      '更新工具状态失败',
      () => _db.transaction(() async {
        final record = await getById(id);
        if (record.status != ToolCallStatus.prepared) {
          throw const OperationFailure('此动作已不再等待派发');
        }
        final executing = record.copyWith(
          status: ToolCallStatus.executing,
          startedAt: DateTime.now(),
        );
        await (_db.update(
          _db.toolCalls,
        )..where((t) => t.id.equals(id))).write(toolCallCompanion(executing));
        await (_db.update(_db.agentRuns)
              ..where((t) => t.id.equals(record.runId)))
            .write(AgentRunsCompanion(activeToolCallId: Value(id)));
        return executing;
      }),
    );
  }

  Future<ToolCallRecord> markSucceeded(
    String id, {
    String? result,
    List<String> artifacts = const [],
    String? errorCode,
  }) {
    return _apply(id, '记录工具结果失败', (record) {
      return record.copyWith(
        status: ToolCallStatus.succeeded,
        result: result,
        artifacts: artifacts,
        errorCode: errorCode,
        finishedAt: DateTime.now(),
      );
    });
  }

  Future<ToolCallRecord> markFailed(
    String id, {
    String? result,
    String? errorCode,
  }) {
    return _apply(id, '记录工具失败结果失败', (record) {
      return record.copyWith(
        status: ToolCallStatus.failed,
        result: result,
        errorCode: errorCode,
        finishedAt: DateTime.now(),
      );
    });
  }

  Future<ToolCallRecord> markRejected(
    String id, {
    ToolDecision? decision,
    String? result,
    String? errorCode,
  }) {
    return _apply(id, '记录拒绝失败', (record) {
      return record.copyWith(
        status: ToolCallStatus.rejected,
        decision: decision,
        result: result,
        errorCode: errorCode,
        finishedAt: DateTime.now(),
      );
    });
  }

  Future<ToolCallRecord> markCancelled(String id, {String? result}) {
    return _apply(id, '记录取消失败', (record) {
      return record.copyWith(
        status: ToolCallStatus.cancelled,
        result: result ?? '本次调用已取消，未继续执行。',
        finishedAt: DateTime.now(),
      );
    });
  }

  Future<ToolCallRecord> _apply(
    String id,
    String failureMessage,
    ToolCallRecord Function(ToolCallRecord record) change,
  ) {
    return _guard(failureMessage, () async {
      return _db.transaction(() async {
        final row = await (_db.select(
          _db.toolCalls,
        )..where((t) => t.id.equals(id))).getSingle();
        final updated = change(toolCallFromRow(row));
        await (_db.update(
          _db.toolCalls,
        )..where((t) => t.id.equals(id))).write(toolCallCompanion(updated));
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
Future<ToolCallRepository> toolCallRepository(Ref ref) async {
  final database = await ref.watch(appDatabaseProvider.future);
  return ToolCallRepository(database);
}
