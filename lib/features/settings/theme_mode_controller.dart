import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/datasources/local/settings_storage.dart';

part 'theme_mode_controller.g.dart';

/// 主题模式：默认跟随系统，修改后持久化到 shared_preferences。
@Riverpod(dependencies: [settingsStorage])
class ThemeModeController extends _$ThemeModeController {
  @override
  ThemeMode build() {
    return ref.watch(settingsStorageProvider).readThemeMode();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    await ref.read(settingsStorageProvider).writeThemeMode(mode);
  }
}
