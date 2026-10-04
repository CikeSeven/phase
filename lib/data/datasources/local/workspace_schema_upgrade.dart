import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/error/failure.dart';
import 'app_database.dart';

/// 重建会话工作区结构，保留业务记录与 Ubuntu 文件来源。
Future<void> upgradeWorkspaceSchema(AppDatabase db, Migrator migrator) async {
  Future<Map<String, int>> rowCounts() async => {
    for (final table in db.allTables)
      table.actualTableName:
          (await db
                  .customSelect(
                    'SELECT COUNT(*) AS n FROM "${table.actualTableName}"',
                  )
                  .getSingle())
              .read<int>('n'),
  };
  Future<Set<String>> retainedRows(
    TableInfo<Table, Object?> table, {
    String? where,
  }) async => {
    for (final row
        in await db
            .customSelect(
              'SELECT ${table.$columns.map((column) => '"${column.name}"').join(', ')} '
              'FROM "${table.actualTableName}"${where == null ? '' : ' WHERE $where'}',
            )
            .get())
      jsonEncode(row.data),
  };

  final originalCounts = await rowCounts();
  final originalRows = {
    for (final table in <TableInfo<Table, Object?>>[
      db.conversations,
      db.workspaces,
    ])
      table.actualTableName: await retainedRows(table),
    db.workspaceCopies.actualTableName: await retainedRows(
      db.workspaceCopies,
      where: "environment = 'ubuntu'",
    ),
  };

  // 环境身份失效的运行只能收口，不能将未执行动作交给新的环境重放。
  const unsupportedEnvironment =
      "COALESCE(json_extract(configuration_json, '\$.workspace.primaryEnvironment'), 'ubuntu') != 'ubuntu'";
  const supportedChannels = "'app', 'accessibility', 'shizuku'";
  await db.customStatement("""
    UPDATE agent_plans SET status = 'cancelled'
    WHERE status = 'draft' AND source_run_id IN (
      SELECT id FROM agent_runs WHERE $unsupportedEnvironment
    )
  """);
  final interruptedRuns = await db.customSelect("""
    SELECT id FROM agent_runs
    WHERE status IN ('running', 'awaitingConfirmation', 'awaitingUser') AND (
      $unsupportedEnvironment OR
      conversation_id IN (SELECT id FROM conversations WHERE primary_environment != 'ubuntu') OR
      id IN (SELECT run_id FROM tool_calls WHERE channel NOT IN ($supportedChannels))
    )
  """).get();
  for (final run in interruptedRuns) {
    final id = run.read<String>('id');
    await db.customStatement(
      """
      UPDATE agent_runs
      SET status = 'stopped', finish_reason = 'cancelled', active_tool_call_id = NULL,
          finished_at = COALESCE(finished_at, strftime('%s', 'now'))
      WHERE id = ?
    """,
      [id],
    );
    await db.customStatement(
      """
      UPDATE tool_calls
      SET status = CASE WHEN status = 'executing' THEN 'failed' ELSE 'cancelled' END,
          error_code = 'interrupted',
          result = COALESCE(result, '运行配置已改变，任务已停止。已产生的效果和输出保留。'),
          finished_at = COALESCE(finished_at, strftime('%s', 'now'))
      WHERE status IN ('prepared', 'awaitingConfirmation', 'executing') AND run_id = ?
    """,
      [id],
    );
    await db.customStatement(
      """
      UPDATE messages SET status = 'cancelled'
      WHERE status = 'streaming' AND run_id = ?
    """,
      [id],
    );
  }
  await db.customStatement(
    "UPDATE tool_calls SET channel = 'unknown' WHERE channel NOT IN ($supportedChannels)",
  );
  await db.customStatement(
    "DELETE FROM workspace_copies WHERE environment != 'ubuntu'",
  );
  await migrator.alterTable(TableMigration(db.workspaceCopies));
  await migrator.alterTable(TableMigration(db.workspaces));
  await migrator.alterTable(TableMigration(db.conversations));

  final migratedCounts = await rowCounts();
  final expectedCounts = {
    ...originalCounts,
    db.workspaceCopies.actualTableName:
        originalRows[db.workspaceCopies.actualTableName]!.length,
  };
  for (final table in <TableInfo<Table, Object?>>[
    db.conversations,
    db.workspaces,
    db.workspaceCopies,
  ]) {
    final original = originalRows[table.actualTableName]!;
    final migrated = await retainedRows(table);
    if (original.length != migrated.length || !original.containsAll(migrated)) {
      throw const OperationFailure('工作区升级校验失败，已保留原数据');
    }
  }
  if (expectedCounts.entries.any(
        (entry) => migratedCounts[entry.key] != entry.value,
      ) ||
      (await db.customSelect('PRAGMA foreign_key_check').get()).isNotEmpty ||
      (await db.customSelect('PRAGMA quick_check').getSingle())
              .data
              .values
              .single !=
          'ok') {
    throw const OperationFailure('数据库升级校验失败，已保留原数据');
  }
  await db.customStatement('PRAGMA user_version = 12');
}
