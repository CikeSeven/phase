import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'key_store.dart';

part 'secure_key_storage.g.dart';

/// 密钥的唯一存取通道（AGENTS.md §5）。
///
/// 目前存取 API Key（按服务商配置 id）与数据库密钥；密钥不进普通持久化、
/// 不进日志、不进数据模型。读取失败直接报错，不自动清空整个密钥库。
class SecureKeyStorage {
  const SecureKeyStorage([this._store = const SecureKeyStore()]);

  final KeyStore _store;

  String _keyFor(String profileId) => 'api_key_$profileId';

  Future<String?> read(String profileId) => _store.read(_keyFor(profileId));

  Future<void> write(String profileId, String apiKey) =>
      _store.write(_keyFor(profileId), apiKey);

  Future<void> delete(String profileId) => _store.delete(_keyFor(profileId));
}

@Riverpod(keepAlive: true)
SecureKeyStorage secureKeyStorage(Ref ref) {
  return const SecureKeyStorage();
}
