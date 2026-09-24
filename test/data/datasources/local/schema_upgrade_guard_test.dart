import 'package:sqlite3/sqlite3.dart' as raw;
import 'package:phase/data/datasources/local/database_key.dart';

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/error/failure.dart';
import 'package:phase/data/datasources/local/app_database.dart';

void main() {
  test('未获本次装机升级授权的旧 schema 拒绝打开，不删表或数据', () async {
    final directory = Directory.systemTemp.createTempSync('phase_schema_guard');
    final path = '${directory.path}/phase.sqlite';
    final key = '0123456789abcdef' * 4;
    var db = openAppDatabase(path: path, hexKey: key, background: false);
    addTearDown(() async {
      await db.close();
      directory.deleteSync(recursive: true);
    });
    await db.customStatement('CREATE TABLE preserve_fixture (value TEXT)');
    await db.customStatement(
      "INSERT INTO preserve_fixture VALUES ('must stay')",
    );
    await db.customStatement('PRAGMA user_version = 7');
    await db.close();
    db = openAppDatabase(path: path, hexKey: key, background: false);
    await expectLater(
      db.customSelect('SELECT * FROM preserve_fixture').get(),
      throwsA(isA<OperationFailure>()),
    );
    await db.close();
    // 用不含迁移器的原始连接验证拒绝升级未改变任何数据。
    final connection = raw.sqlite3.open(path);
    try {
      connection.execute(sqliteKeyPragma(key));
      expect(
        connection.select('SELECT * FROM preserve_fixture').single['value'],
        'must stay',
      );
      expect(
        connection.select('PRAGMA user_version').single['user_version'],
        7,
      );
    } finally {
      connection.close();
    }
  });
}
