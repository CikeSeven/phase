import 'dart:math';

import 'key_store.dart';

/// 数据库密钥：随机 32 字节，以十六进制形式交给 SQLite3MultipleCiphers。
///
/// 数据库从创建时就加密，密钥本身只保存在安全存储里；
/// 安全存储读取失败直接报错，不自动清空或重建密钥库。
class DatabaseKey {
  const DatabaseKey([this._store = const SecureKeyStore()]);

  static const _storageKey = 'database_key';

  static final _random = Random.secure();

  final KeyStore _store;

  /// 删除已保存的密钥（数据库重建时一并清理）。
  Future<void> delete() => _store.delete(_storageKey);

  /// 读取已有密钥；不存在时生成并保存。
  Future<String> readOrCreate() async {
    final existing = await _store.read(_storageKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    final generated = List.generate(32, (_) => _random.nextInt(256));
    final hex = generated
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    await _store.write(_storageKey, hex);
    return hex;
  }
}

/// 把十六进制密钥转成 `PRAGMA key` 语句。
///
/// 密钥是纯十六进制字符串，不带引号或空格，因此按普通字符串下发即可；
/// SQLite3MultipleCiphers 的 PRAGMA key 不接受 x'…' 形式。
String sqliteKeyPragma(String hexKey) => "PRAGMA key = '$hexKey';";
