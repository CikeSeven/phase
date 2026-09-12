import 'package:phase/data/datasources/local/key_store.dart';

/// 内存密钥库：测试不读取手机安全存储。
class FakeSecureStorage implements KeyStore {
  FakeSecureStorage([Map<String, String>? initial]) : _values = {...?initial};

  final Map<String, String> _values;

  /// 直接查看已写入的内容（断言密钥是否更换）。
  Map<String, String> get values => Map.unmodifiable(_values);

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }
}
