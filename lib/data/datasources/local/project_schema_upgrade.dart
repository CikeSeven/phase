import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/error/failure.dart';
import 'app_database.dart';

/// 新归属字段不重定位旧文件；重建附件外键时逐行保留原元数据。
Future<void> upgradeProjectSchema(AppDatabase db, Migrator migrator) async {
  Future<Set<String>> columns(String table) async => {
    for (final row
        in await db.customSelect('PRAGMA table_info("$table")').get())
      row.read<String>('name'),
  };

  final workspaceColumns = await columns('workspaces');
  if (!workspaceColumns.contains('kind')) {
    await migrator.addColumn(db.workspaces, db.workspaces.kind);
  }
  final conversationColumns = await columns('conversations');
  if (!conversationColumns.contains('project_id')) {
    await migrator.addColumn(db.conversations, db.conversations.projectId);
  }

  final attachmentColumns = await columns('attachments');
  final projection = attachmentColumns.map((name) => '"$name"').join(', ');
  Future<Set<String>> retainedAttachments() async => {
    for (final row
        in await db.customSelect('SELECT $projection FROM attachments').get())
      jsonEncode(row.data),
  };
  final original = await retainedAttachments();
  await migrator.alterTable(
    TableMigration(db.attachments, newColumns: [db.attachments.projectId]),
  );
  final migrated = await retainedAttachments();
  if (original.length != migrated.length || !original.containsAll(migrated)) {
    throw const OperationFailure('项目资料升级校验失败，已保留原数据');
  }
  if ((await db.customSelect('PRAGMA foreign_key_check').get()).isNotEmpty ||
      (await db.customSelect('PRAGMA quick_check').getSingle())
              .data
              .values
              .single !=
          'ok') {
    throw const OperationFailure('数据库升级校验失败，已保留原数据');
  }
}
