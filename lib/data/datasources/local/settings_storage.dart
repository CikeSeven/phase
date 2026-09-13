import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:convert';

import '../../models/execution_scope.dart';
import '../../../core/error/failure.dart';

part 'settings_storage.g.dart';

/// shared_preferences 的设置项封装：只放非敏感的偏好设置。
class SettingsStorage {
  SettingsStorage(this._prefs);

  final SharedPreferences _prefs;

  ExecutionScope readExecutionScope() {
    final value = _prefs.getString('execution_scope');
    if (value == null) return const ExecutionScope();
    try {
      return ExecutionScope.fromJson(jsonDecode(value) as Map<String, dynamic>);
    } on Object {
      throw const OperationFailure('执行范围读取失败，请重新设置');
    }
  }

  Future<void> writeExecutionScope(ExecutionScope scope) async {
    if (!await _prefs.setString(
      'execution_scope',
      jsonEncode(scope.toJson()),
    )) {
      throw const OperationFailure('执行范围保存失败，请重试');
    }
  }

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
  static const _lastReasoningEffortKey = 'last_reasoning_effort';

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

  /// 最近使用的推理等级（ReasoningEffort.name）；未设置时返回 null。
  String? readLastReasoningEffort() =>
      _prefs.getString(_lastReasoningEffortKey);

  Future<void> writeLastReasoningEffort(String effortName) {
    return _prefs.setString(_lastReasoningEffortKey, effortName);
  }

  /// 「存量模型统一默认支持推理」迁移是否已完成。
  static const _reasoningSupportMigratedKey = 'reasoning_support_migrated_v1';

  bool readReasoningSupportMigrated() =>
      _prefs.getBool(_reasoningSupportMigratedKey) ?? false;

  Future<void> writeReasoningSupportMigrated() {
    return _prefs.setBool(_reasoningSupportMigratedKey, true);
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
