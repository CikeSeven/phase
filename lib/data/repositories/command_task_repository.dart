import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/error/failure.dart';
import '../datasources/local/app_database.dart';
import '../models/command_task.dart';
import '../models/chat_message.dart';
import '../models/message_part.dart';
import 'conversation_repository.dart';

part 'command_task_repository.g.dart';

class CommandTaskRepository {
  CommandTaskRepository(this.db);
  final AppDatabase db;

  Future<List<CommandTask>> list() => _guard(() async {
    final configuration = db.commandTasks.configurationJson;
    final rows =
        await (db.selectOnly(db.commandTasks)
              ..addColumns([configuration])
              ..orderBy([OrderingTerm.desc(db.commandTasks.createdAt)]))
            .get();
    return rows
        .map(
          (row) => CommandTask.fromJson(
            jsonDecode(row.read(configuration)!) as Map<String, dynamic>,
          ),
        )
        .toList();
  });

  Future<CommandTaskData?> get(String id) => _guard(() async {
    final row = await (db.select(
      db.commandTasks,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null
        ? null
        : CommandTaskData(
            _task(row),
            row.stdoutTail ?? Uint8List(0),
            row.stderrTail ?? Uint8List(0),
          );
  });

  Future<void> add(CommandTask task) => _guard(() async {
    final owner = await (db.select(
      db.conversations,
    )..where((t) => t.id.equals(task.conversationId))).getSingleOrNull();
    if (owner == null || owner.workspaceId != task.workspace.id) {
      throw const OperationFailure('任务所属会话或工作区已改变');
    }
    await db
        .into(db.commandTasks)
        .insert(
          CommandTasksCompanion.insert(
            id: task.id,
            conversationId: task.conversationId,
            workspaceId: task.workspace.id,
            configurationJson: jsonEncode(task.toJson()),
            createdAt: task.createdAt,
          ),
        );
  });

  Future<void> save(CommandTaskData data) => _guard(() async {
    final count =
        await (db.update(
          db.commandTasks,
        )..where((t) => t.id.equals(data.task.id))).write(
          CommandTasksCompanion(
            configurationJson: Value(jsonEncode(data.task.toJson())),
            stdoutTail: Value(data.stdout),
            stderrTail: Value(data.stderr),
          ),
        );
    if (count != 1) throw const OperationFailure('任务记录已删除');
  });

  Future<void> remove(String id) => _guard(() async {
    await (db.delete(db.commandTasks)..where((t) => t.id.equals(id))).go();
  });

  /// Claim each completion and append its host notice in the same transaction.
  Future<List<CommandTask>> deliverCompletions({
    required String conversationId,
    required String runId,
    required String messageId,
    required ConversationRepository conversations,
    required Set<String> taskIds,
  }) => _guard(
    () => db.transaction(() async {
      final column = db.commandTasks.configurationJson;
      final rows =
          await (db.selectOnly(db.commandTasks)
                ..addColumns([column])
                ..where(db.commandTasks.conversationId.equals(conversationId))
                ..orderBy([OrderingTerm.asc(db.commandTasks.createdAt)]))
              .get();
      final tasks = rows
          .map(
            (row) => CommandTask.fromJson(
              jsonDecode(row.read(column)!) as Map<String, dynamic>,
            ),
          )
          .where(
            (task) =>
                taskIds.contains(task.id) &&
                !task.status.active &&
                task.completionDelivery == TaskCompletionDelivery.pending,
          )
          .take(32)
          .toList();
      if (tasks.isEmpty) return <CommandTask>[];
      final thread = await conversations.getThread(conversationId);
      if (thread == null) throw const OperationFailure('任务所属会话已删除');
      final delivered = [
        for (final task in tasks)
          task.copyWith(completionDelivery: TaskCompletionDelivery.delivered),
      ];
      final notice = jsonEncode({
        'tasks': [
          for (final task in tasks) task.summary(includeCommand: false),
        ],
        'instruction': '这些后台任务已结束。请使用 task_output 读取所需日志，处理结果并向用户回复。不要重复执行已完成的命令；停止或失败不代表文件变化已撤销。',
      });
      await conversations.appendMessage(
        ChatMessage(
          id: messageId,
          conversationId: conversationId,
          parentId: thread.currentMessageId,
          runId: runId,
          role: ChatRole.system,
          parts: [
            RuntimeContextPart(
              section: 'task_completion',
              text:
                  '<phase_runtime_context section="task_completion">\n$notice\n</phase_runtime_context>',
            ),
          ],
          createdAt: DateTime.now(),
        ),
      );
      for (final task in delivered) {
        await (db.update(
          db.commandTasks,
        )..where((t) => t.id.equals(task.id))).write(
          CommandTasksCompanion(
            configurationJson: Value(jsonEncode(task.toJson())),
          ),
        );
      }
      return delivered;
    }),
  );

  Future<void> recover() => _guard(
    () => db.transaction(() async {
      for (final task in await list()) {
        if (!task.status.active) continue;
        await (db.update(
          db.commandTasks,
        )..where((t) => t.id.equals(task.id))).write(
          CommandTasksCompanion(
            configurationJson: Value(
              jsonEncode(
                task
                    .copyWith(
                      status: CommandTaskStatus.interrupted,
                      finishedAt: DateTime.now(),
                      error: '应用进程已重启，任务已中断；命令未自动重跑',
                      completionDelivery: TaskCompletionDelivery.suppressed,
                    )
                    .toJson(),
              ),
            ),
          ),
        );
      }
    }),
  );

  CommandTask _task(CommandTaskRow row) => CommandTask.fromJson(
    jsonDecode(row.configurationJson) as Map<String, dynamic>,
  );

  Future<T> _guard<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on Failure {
      rethrow;
    } on Exception catch (error) {
      throw StorageFailure('任务记录读取或保存失败', cause: error);
    }
  }
}

@Riverpod(keepAlive: true)
Future<CommandTaskRepository> commandTaskRepository(Ref ref) async =>
    CommandTaskRepository(await ref.watch(appDatabaseProvider.future));
