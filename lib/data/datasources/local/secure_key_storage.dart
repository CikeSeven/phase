import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/error/failure.dart';
import 'key_store.dart';

part 'secure_key_storage.g.dart';

/// 密钥的唯一存取通道（AGENTS.md §5）。
///
/// 模型 API Key 按配置 ID 存取，MCP 凭据/请求头按版本引用存取。
/// 密钥不进普通持久化、日志或数据模型；读取失败不自动清空密钥库。
class SecureKeyStorage {
  const SecureKeyStorage([this._store = const SecureKeyStore()]);

  final KeyStore _store;

  Future<String?> readMcp(String reference) async {
    try {
      return await _store.read('mcp_secret_$reference');
    } catch (error) {
      throw StorageFailure('读取 MCP 凭据失败', cause: error);
    }
  }

  Future<void> writeMcp(String reference, String value) async {
    try {
      await _store.write('mcp_secret_$reference', value);
    } catch (error) {
      throw StorageFailure('保存 MCP 凭据失败', cause: error);
    }
  }

  Future<void> deleteMcp(String reference) async {
    try {
      await _store.delete('mcp_secret_$reference');
    } catch (error) {
      throw StorageFailure('删除 MCP 凭据失败', cause: error);
    }
  }

  String _keyFor(String profileId) => 'api_key_$profileId';

  Future<String?> read(String profileId) async {
    try {
      return await _store.read(_keyFor(profileId));
    } on StorageFailure {
      rethrow;
    } catch (error) {
      throw StorageFailure('读取模型凭据失败', cause: error);
    }
  }

  Future<void> write(String profileId, String apiKey) =>
      _store.write(_keyFor(profileId), apiKey);

  Future<void> delete(String profileId) => _store.delete(_keyFor(profileId));
}

@Riverpod(keepAlive: true)
SecureKeyStorage secureKeyStorage(Ref ref) {
  return const SecureKeyStorage();
}
