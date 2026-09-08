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
