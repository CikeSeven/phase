import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/error/failure.dart';
import '../../../data/datasources/local/settings_storage.dart';
import '../../../data/models/tool_permission.dart';
import '../../../data/models/tool_policy.dart';

part 'tool_permission_rules_controller.g.dart';

@Riverpod(dependencies: [settingsStorage])
class ToolPermissionRulesController extends _$ToolPermissionRulesController {
  bool _saving = false;

  @override
  FutureOr<List<ToolPermissionRule>> build() =>
      ref.watch(settingsStorageProvider).readToolPermissionRules();

  Future<void> setRule(ToolPermissionRule target, ToolPolicy? policy) async {
    if (_saving) throw const OperationFailure('工具规则正在保存');
    final current = state.value;
    if (current == null) throw const OperationFailure('请先读取工具规则');
    final next = List<ToolPermissionRule>.unmodifiable([
      for (final rule in current)
        if (rule.key != target.key) rule,
      if (policy != null) target.withPolicy(policy),
    ]);
    _saving = true;
    try {
      await ref.read(settingsStorageProvider).writeToolPermissionRules(next);
      if (ref.mounted) state = AsyncData(next);
    } finally {
      _saving = false;
    }
  }
}
