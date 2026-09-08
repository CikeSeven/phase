import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'settings_storage.g.dart';

/// shared_preferences 的设置项封装：只放非敏感的偏好设置。
class SettingsStorage {
  SettingsStorage(this._prefs);

  final SharedPreferences _prefs;

  static const _themeModeKey = 'theme_mode';

  ThemeMode readThemeMode() {
    return switch (_prefs.getString(_themeModeKey)) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> writeThemeMode(ThemeMode mode) {
    return _prefs.setString(_themeModeKey, mode.name);
  }

  static const _lastProfileIdKey = 'last_profile_id';
  static const _lastModelKey = 'last_model';

  String? readLastProfileId() => _prefs.getString(_lastProfileIdKey);

  String? readLastModel() => _prefs.getString(_lastModelKey);

  /// 记录「最近使用的服务商 × 模型」，下次启动与默认选择以此为准。
  Future<void> writeLastModelSelection({
    required String profileId,
    required String model,
  }) async {
    await _prefs.setString(_lastProfileIdKey, profileId);
    await _prefs.setString(_lastModelKey, model);
  }
}

/// 在 main() 中用真实实例 override。
@Riverpod(keepAlive: true, dependencies: [])
SharedPreferences sharedPreferences(Ref ref) {
  throw UnimplementedError('sharedPreferences 需要在 ProviderScope 处 override');
}

@Riverpod(keepAlive: true, dependencies: [sharedPreferences])
SettingsStorage settingsStorage(Ref ref) {
  return SettingsStorage(ref.watch(sharedPreferencesProvider));
}
