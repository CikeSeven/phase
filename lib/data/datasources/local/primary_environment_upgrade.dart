import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/error/failure.dart';
import 'app_database.dart';

/// 仅本次获授权的 9 → 10 保数据覆盖安装；不转换历史运行或外部目录。
Future<void> upgradePrimaryEnvironment(
  AppDatabase db,
  Migrator migrator,
) => db.transaction(() async {
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
  final originalCounts = await rowCounts();
  Future<Set<String>> copies() async => {
    for (final row
        in await db
            .customSelect(
              'SELECT workspace_id, relative_path, source_json FROM workspace_copies',
            )
            .get())
      jsonEncode([
        row.data['workspace_id'],
        row.data['relative_path'],
        row.data['source_json'],
      ]),
  };
  final originalCopies = await copies();
  await migrator.addColumn(
    db.conversations,
    db.conversations.primaryEnvironment,
  );
  await migrator.addColumn(db.workspaces, db.workspaces.termuxUid);
  await migrator.alterTable(
    TableMigration(
      db.workspaceCopies,
      newColumns: [db.workspaceCopies.environment],
    ),
  );
  final migratedCopies = await copies();
  final migratedCounts = await rowCounts();
  if (originalCopies.length != migratedCopies.length ||
      !originalCopies.containsAll(migratedCopies) ||
      originalCounts.entries.any(
        (entry) => migratedCounts[entry.key] != entry.value,
      )) {
    throw const OperationFailure('文件来源升级校验失败，已保留原数据');
  }
  final unexpected = await db
      .customSelect(
        "SELECT 1 FROM conversations WHERE primary_environment != 'ubuntu' "
        'UNION ALL SELECT 1 FROM workspaces WHERE termux_uid IS NOT NULL '
        "UNION ALL SELECT 1 FROM workspace_copies WHERE environment != 'ubuntu' LIMIT 1",
      )
      .get();
  if (unexpected.isNotEmpty ||
      (await db.customSelect('PRAGMA foreign_key_check').get()).isNotEmpty ||
      (await db.customSelect('PRAGMA quick_check').getSingle())
              .data
              .values
              .single !=
          'ok') {
    throw const OperationFailure('主环境升级校验失败，已保留原数据');
  }
  // 与表变更一并提交，避免进程退出后重复添加列。
  await db.customStatement('PRAGMA user_version = 10');
});
