import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/error/failure.dart';
import 'app_database.dart';

/// 仅用于本次获授权的 8 → 9 覆盖安装，不在模型解码层保留旧格式。
Future<void> upgradePermissionModes(
  AppDatabase db,
  Migrator migrator,
) => db.transaction(() async {
  await migrator.addColumn(db.conversations, db.conversations.permissionMode);
  await migrator.addColumn(
    db.conversations,
    db.conversations.lastExecutionMode,
  );
  await migrator.addColumn(db.assistants, db.assistants.mcpToolNamesJson);

  final assistants = await db
      .customSelect('SELECT id, tool_policy_json FROM assistants')
      .get();
  for (final row in assistants) {
    final policies = _object(row.read<String>('tool_policy_json'));
    if (policies.values.any(
      (value) => value != 'allow' && value != 'ask' && value != 'deny',
    )) {
      throw const OperationFailure('旧权限数据无法转换，已保留原数据');
    }
    // 包括暂时不在目录中的已选工具；deny 不转成启用。
    final enabled = [
      for (final entry in policies.entries)
        if (entry.key.startsWith('mcp_') && entry.value != 'deny') entry.key,
    ]..sort();
    await db.customStatement(
      'UPDATE assistants SET mcp_tool_names_json = ? WHERE id = ?',
      [jsonEncode(enabled), row.read<String>('id')],
    );
  }

  final runs = await db
      .customSelect('SELECT id, configuration_json FROM agent_runs')
      .get();
  for (final row in runs) {
    final config = _object(row.read<String>('configuration_json'));
    config['mode'] = switch (config['mode']) {
      null || 'execute' => 'basic',
      'plan' => 'plan',
      _ => throw const OperationFailure('旧运行模式无法转换，已保留原数据'),
    };
    // 旧版本没有规划前执行档；不从助手 allow 策略推断为全权限。
    config['planExecutionMode'] = 'basic';
    await db.customStatement(
      'UPDATE agent_runs SET configuration_json = ? WHERE id = ?',
      [jsonEncode(config), row.read<String>('id')],
    );
  }
  await migrator.dropColumn(db.assistants, 'tool_policy_json');
  if ((await db.customSelect('PRAGMA foreign_key_check').get()).isNotEmpty) {
    throw const OperationFailure('升级引用检查失败，已保留原数据');
  }
  // 版本和字段转换原子提交，避免进程退出后重复添加已经提交的列。
  await db.customStatement('PRAGMA user_version = 9');
});

Map<String, dynamic> _object(String encoded) {
  try {
    final value = jsonDecode(encoded);
    if (value is Map<String, dynamic>) return value;
  } on FormatException {
    // 不把包含提示词、端点或工具参数的原始 JSON 带入日志或错误提示。
  }
  throw const OperationFailure('旧权限或运行数据无法读取，已保留原数据');
}
