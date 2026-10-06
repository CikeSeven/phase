import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:convert';

import '../../models/execution_scope.dart';
import '../../models/command_channel.dart';
import '../../models/web_search_settings.dart';
import '../../models/tool_permission.dart';
import '../../../core/error/failure.dart';

part 'settings_storage.g.dart';

/// shared_preferences 的设置项封装：只放非敏感的偏好设置。
class SettingsStorage {
  SettingsStorage(this._prefs);

  final SharedPreferences _prefs;
  List<ToolPermissionRule>? _permissionRules;
  bool _writingPermissionRules = false;

  List<ToolPermissionRule> readToolPermissionRules() {
    if (_permissionRules case final cached?) return cached;
    try {
      final value = _prefs.getString('tool_permission_rules_v1');
      if (value == null) return _permissionRules = const [];
      final rules = [
        for (final entry in jsonDecode(value) as List)
          ToolPermissionRule.fromJson(entry as Map<String, dynamic>),
      ];
      if (rules.map((rule) => rule.key).toSet().length != rules.length) {
        throw const FormatException('Duplicate tool permission rules');
      }
      return _permissionRules = List.unmodifiable(rules);
    } on Object {
      throw const StorageFailure('工具规则读取失败，任务未获授权');
    }
  }

  Future<void> writeToolPermissionRules(List<ToolPermissionRule> rules) async {
    if (_writingPermissionRules) throw const OperationFailure('工具规则正在保存');
    // SharedPreferences 先改内存缓存再提交；执行器只能读取已成功提交的规则。
    readToolPermissionRules();
    final next = List<ToolPermissionRule>.unmodifiable(rules);
    _writingPermissionRules = true;
    try {
      for (final rule in next) {
        ToolPermissionRule.fromJson(rule.toJson());
      }
      if (next.map((rule) => rule.key).toSet().length != next.length ||
          !await _prefs.setString(
            'tool_permission_rules_v1',
            jsonEncode(next.map((rule) => rule.toJson()).toList()),
          )) {
        throw const StorageFailure('工具规则保存失败');
      }
      _permissionRules = next;
    } on Failure {
      rethrow;
    } on Object {
      throw const StorageFailure('工具规则保存失败');
    } finally {
      _writingPermissionRules = false;
    }
  }

  WebSearchSettings readWebSearch() {
    final value = _prefs.getString('web_search_v1');
    if (value == null) return const WebSearchSettings();
    try {
      return WebSearchSettings.fromJson(
        jsonDecode(value) as Map<String, dynamic>,
      );
    } on Object {
      throw const StorageFailure('网页搜索配置读取失败');
    }
  }

  Future<void> writeWebSearch(WebSearchSettings value) async {
    value.validate();
    try {
      if (!await _prefs.setString(
        'web_search_v1',
        jsonEncode(value.toJson()),
      )) {
        throw const StorageFailure('网页搜索配置保存失败');
      }
    } on Failure {
      rethrow;
    } on Object {
      throw const StorageFailure('网页搜索配置保存失败');
    }
  }

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

  CommandChannelSettings readCommandChannels() {
    final value = _prefs.getString('command_channels');
    if (value == null) return const CommandChannelSettings();
    try {
      return CommandChannelSettings.fromJson(
        jsonDecode(value) as Map<String, dynamic>,
      );
    } on Object {
      throw const OperationFailure('命令通道设置读取失败');
    }
  }

  Future<void> writeCommandChannels(CommandChannelSettings value) async {
    if (!await _prefs.setString(
      'command_channels',
      jsonEncode(value.toJson()),
    )) {
      throw const OperationFailure('命令通道设置保存失败，请重试');
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
