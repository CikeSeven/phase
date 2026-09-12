import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:phase/data/datasources/local/app_database.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../../support/fake_secure_storage.dart';

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

  group('明文文件识别（非本应用数据格式）', () {
    test('加密库不会被误判为明文库', () {
      createEncryptedDatabase();
      expect(isPlaintextDatabase(dbPath), isFalse);
    });

    test('未加密的 SQLite 库会被识别为明文库', () {
      // 旧原型遗留的未加密库：文件头就是 `SQLite format 3`。
      final plain = sqlite3.open(dbPath);
      plain.execute('CREATE TABLE legacy (value TEXT);');
      plain.close();

      expect(isPlaintextDatabase(dbPath), isTrue);
      expect(
        String.fromCharCodes(File(dbPath).readAsBytesSync().take(15)),
        'SQLite format 3',
      );
    });

    test('文件不存在时按明文库返回 false', () {
      expect(
        isPlaintextDatabase(p.join(tempDir.path, 'missing.sqlite')),
        isFalse,
      );
    });
  });

  test('打开设备库时清理明文文件与旧密钥，重建加密库', () async {
    // 预置：一个明文库 + 一份「属于它」的密钥。
    final plain = sqlite3.open(dbPath);
    plain.execute('CREATE TABLE legacy (value TEXT)');
    plain.close();
    final keyStore = FakeSecureStorage({'database_key': 'ff' * 32});

    final database = await openDeviceDatabase(
      directory: tempDir,
      keyStore: keyStore,
      background: false,
    );
    // 打开时已校验过加密；关库后再看磁盘文件。
    await database.close();

    // 明文被清掉、换成加密库，密钥也已更换。
    expect(isPlaintextDatabase(dbPath), isFalse);
    expect(keyStore.values['database_key'], isNot('ff' * 32));
  });

  test('已是加密库时保持原密钥与数据', () async {
    final keyStore = FakeSecureStorage();
    final first = await openDeviceDatabase(
      directory: tempDir,
      keyStore: keyStore,
      background: false,
    );
    await first
        .into(first.conversations)
        .insert(
          ConversationsCompanion.insert(
            id: 'c1',
            title: '保留我',
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
        );
    await first.close();
    final savedKey = keyStore.values['database_key'];

    final reopened = await openDeviceDatabase(
      directory: tempDir,
      keyStore: keyStore,
      background: false,
    );
    addTearDown(reopened.close);

    expect(keyStore.values['database_key'], savedKey);
    final rows = await reopened.select(reopened.conversations).get();
    expect(rows.single.title, '保留我');
  });
}
