import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:phase/data/datasources/local/app_database.dart';
import 'package:phase/data/datasources/local/database_key.dart';
import 'package:phase/data/repositories/conversation_repository.dart';
import 'package:phase/data/repositories/workspace_repository.dart';
import 'package:sqlite3/sqlite3.dart' as raw;

const _key = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

void main() {
  for (final background in [true, false]) {
    test(
      'schema 13 to 14 adds tasks while preserving conversations and foreign keys ($background)',
      () async {
        final directory = Directory.systemTemp.createTempSync(
          'phase_tasks_upgrade',
        );
        addTearDown(() => directory.deleteSync(recursive: true));
        final path = '${directory.path}/phase.sqlite';
        var db = openAppDatabase(path: path, hexKey: _key, background: false);
        final conversation = await ConversationRepository(
          db,
          workspaces: WorkspaceRepository(db, directory),
        ).createConversation(title: 'preserved');
        await db.close();
        final old = raw.sqlite3.open(path)..execute(sqliteKeyPragma(_key));
        old.execute('DROP TABLE command_tasks');
        old.execute('PRAGMA user_version = 13');
        final before = Map<String, Object?>.from(
          old.select('SELECT * FROM conversations').single,
        );
        old.close();
        for (var i = 0; i < 2; i++) {
          db = openAppDatabase(
            path: path,
            hexKey: _key,
            background: background,
          );
          try {
            expect(
              (await db.select(db.conversations).get()).single.id,
              conversation.id,
            );
            expect(
              (await db.customSelect('SELECT * FROM conversations').getSingle())
                  .data,
              before,
            );
            expect(await db.select(db.commandTasks).get(), isEmpty);
            expect(
              (await db.customSelect('PRAGMA user_version').getSingle())
                  .data
                  .values
                  .single,
              14,
            );
            expect(
              await db.customSelect('PRAGMA foreign_key_check').get(),
              isEmpty,
            );
            expect(
              (await db.customSelect('PRAGMA quick_check').getSingle())
                  .data
                  .values
                  .single,
              'ok',
            );
          } finally {
            await db.close();
          }
        }
      },
    );
  }
}
