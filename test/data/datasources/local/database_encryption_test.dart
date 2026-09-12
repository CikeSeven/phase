import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

/// 校验构建期实际链接的是 SQLite3MultipleCiphers，而不是上游 sqlite3。
///
/// pubspec 的 `hooks.user_defines.sqlite3.source` 决定链接哪一份库；这里用
/// 建库后的口令行为做证据：上游 sqlite3 不认识 cipher，加密版接受口令并
/// 拒绝用错误口令打开同一个库。
void main() {
  late Directory tempDir;
  late String dbPath;

  const passphrase = 'phase-schema-1-test';
  const wrongPassphrase = 'phase-wrong-passphrase';

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('phase_encryption');
    dbPath = p.join(tempDir.path, 'phase.sqlite');
  });

  tearDown(() => tempDir.deleteSync(recursive: true));

  /// 用口令建库并写入一行，返回该连接报告的 cipher 名称。
  String createEncryptedDatabase() {
    final db = sqlite3.open(dbPath);
    addTearDown(db.close);
    db.execute("PRAGMA key = '$passphrase';");
    final cipher = db
        .select('PRAGMA cipher;')
        .map((row) => row.values.join())
        .join();
    db.execute('CREATE TABLE probe (value TEXT NOT NULL);');
    db.execute("INSERT INTO probe VALUES ('secret');");
    return cipher;
  }

  test('链接的是 SQLite3MultipleCiphers', () {
    expect(
      createEncryptedDatabase(),
      isNotEmpty,
      reason: '未链接 SQLite3MultipleCiphers：PRAGMA cipher 无结果',
    );
  });

  test('正确口令可重新打开并读到数据', () {
    createEncryptedDatabase();

    final reopened = sqlite3.open(dbPath);
    addTearDown(reopened.close);
    reopened.execute("PRAGMA key = '$passphrase';");
    expect(
      reopened.select('SELECT value FROM probe;').single['value'],
      'secret',
    );
  });

  test('错误口令无法读取数据', () {
    createEncryptedDatabase();

    final wrong = sqlite3.open(dbPath);
    addTearDown(wrong.close);
    wrong.execute("PRAGMA key = '$wrongPassphrase';");
    expect(
      () => wrong.select('SELECT value FROM probe;'),
      throwsA(anything),
      reason: '错误口令不应读出加密库内容',
    );
  });

  // 应用使用随机 32 字节密钥，按十六进制字符串下发（见 sqliteKeyPragma）。
  test('随机十六进制密钥可用', () {
    final rawKey = 'a1b2c3d4' * 8;
    final db = sqlite3.open(dbPath);
    addTearDown(db.close);
    db.execute("PRAGMA key = '$rawKey';");
    db.execute('CREATE TABLE probe (value TEXT NOT NULL);');
    db.execute("INSERT INTO probe VALUES ('hex-secret');");
    db.close();

    final reopened = sqlite3.open(dbPath);
    addTearDown(reopened.close);
    reopened.execute("PRAGMA key = '$rawKey';");
    expect(
      reopened.select('SELECT value FROM probe;').single['value'],
      'hex-secret',
    );

    final bytes = File(dbPath).readAsBytesSync();
    expect(String.fromCharCodes(bytes).contains('hex-secret'), isFalse);
  });
}
