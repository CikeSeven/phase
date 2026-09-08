import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'secure_key_storage.g.dart';

/// API Key 的唯一存取通道（AGENTS.md §5 密钥安全）。
///
/// 密钥只允许存这里：不进普通持久化、不进日志、不进数据模型。
class SecureKeyStorage {
  SecureKeyStorage([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  String _keyFor(String providerProfileId) => 'api_key_$providerProfileId';

  Future<String?> readApiKey(String providerProfileId) {
    return _storage.read(key: _keyFor(providerProfileId));
  }

  Future<void> writeApiKey(String providerProfileId, String apiKey) {
    return _storage.write(key: _keyFor(providerProfileId), value: apiKey);
  }

  Future<void> deleteApiKey(String providerProfileId) {
    return _storage.delete(key: _keyFor(providerProfileId));
  }
}

@Riverpod(keepAlive: true)
SecureKeyStorage secureKeyStorage(Ref ref) {
  return SecureKeyStorage();
}
