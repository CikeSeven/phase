import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 密钥存取的最小契约。
///
/// 生产实现走系统安全存储；测试注入内存实现，不读取设备密钥库。
abstract interface class KeyStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

/// 基于 flutter_secure_storage 的实现（Android Keystore）。
class SecureKeyStore implements KeyStore {
  const SecureKeyStore([this._storage = const FlutterSecureStorage()]);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}
