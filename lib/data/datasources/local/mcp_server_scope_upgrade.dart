import 'dart:convert';

import '../../../core/error/failure.dart';
import 'app_database.dart';

/// 仅本次获授权的 10 → 11 保数据安装，不改写历史运行的工具快照。
Future<void> upgradeMcpServerScope(AppDatabase db) => db.transaction(() async {
  final existingTables = {
    for (final row
        in await db
            .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
            .get())
      row.read<String>('name'),
  };
  Future<Map<String, int>> rowCounts() async => {
    for (final table in db.allTables)
      if (existingTables.contains(table.actualTableName))
        table.actualTableName:
            (await db
                    .customSelect(
                      'SELECT COUNT(*) AS n FROM "${table.actualTableName}"',
                    )
                    .getSingle())
                .read<int>('n'),
  };
  final originalCounts = await rowCounts();
  final assistants = await db
      .customSelect('SELECT id, mcp_tool_names_json FROM assistants')
      .get();
  final selections = {
    for (final row in assistants)
      row.read<String>('id'): _selectedNames(
        row.read<String>('mcp_tool_names_json'),
      ),
  };
  final selectedNames = {for (final names in selections.values) ...names};
  final servers = await db
      .customSelect('SELECT id, tools_json FROM mcp_servers')
      .get();
  final serverIds = {for (final row in servers) row.read<String>('id')};
  final sources = <String, String>{};

  void remember(String name, Object? source) {
    if (!selectedNames.contains(name)) return;
    final value = _object(source);
    if (value['kind'] != 'mcp') return;
    final id = value['id'];
    if (id is! String ||
        id.isEmpty ||
        (sources.containsKey(name) && sources[name] != id)) {
      throw const OperationFailure('MCP 工具来源无法转换，已保留原数据');
    }
    sources[name] = id;
  }

  void rememberSnapshots(List<dynamic> snapshots) {
    for (final snapshot in snapshots) {
      final tool = _object(snapshot);
      final name = tool['name'];
      if (name is! String) {
        throw const OperationFailure('MCP 工具目录无法转换，已保留原数据');
      }
      remember(name, tool['source']);
    }
  }

  for (final row in servers) {
    rememberSnapshots(_list(row.read<String>('tools_json')));
  }
  // 目录刷新可能移除了原来已选的工具；只使用保存的来源身份，不反解模型别名。
  if (!sources.keys.toSet().containsAll(selectedNames)) {
    final calls = await db
        .customSelect(
          'SELECT DISTINCT tool_name, source_json FROM tool_calls WHERE source_json IS NOT NULL',
        )
        .get();
    for (final row in calls) {
      final name = row.read<String>('tool_name');
      if (selectedNames.contains(name)) {
        remember(name, _decode(row.read<String>('source_json')));
      }
    }
  }
  if (!sources.keys.toSet().containsAll(selectedNames)) {
    final runs = await db
        .customSelect('SELECT configuration_json FROM agent_runs')
        .get();
    for (final row in runs) {
      final config = _object(_decode(row.read<String>('configuration_json')));
      final snapshots = config['toolSnapshots'] ?? const [];
      if (snapshots is! List) {
        throw const OperationFailure('旧运行工具目录无法读取，已保留原数据');
      }
      rememberSnapshots(snapshots);
    }
  }
  if (!sources.keys.toSet().containsAll(selectedNames)) {
    throw const OperationFailure('已选 MCP 工具缺少服务来源，升级已取消，原数据保留');
  }
  final enabledServers = {
    for (final entry in selections.entries)
      entry.key: {
        for (final name in entry.value)
          if (serverIds.contains(sources[name])) sources[name]!,
      }.toList()..sort(),
  };
  await db.customStatement(
    'ALTER TABLE assistants RENAME COLUMN mcp_tool_names_json TO mcp_server_ids_json',
  );
  for (final entry in enabledServers.entries) {
    await db.customStatement(
      'UPDATE assistants SET mcp_server_ids_json = ? WHERE id = ?',
      [jsonEncode(entry.value), entry.key],
    );
  }
  final migratedCounts = await rowCounts();
  final migratedAssistants = await db
      .customSelect('SELECT id, mcp_server_ids_json FROM assistants')
      .get();
  if (originalCounts.entries.any(
        (entry) => migratedCounts[entry.key] != entry.value,
      ) ||
      migratedAssistants.any(
        (row) =>
            row.read<String>('mcp_server_ids_json') !=
            jsonEncode(enabledServers[row.read<String>('id')]),
      ) ||
      (await db.customSelect('PRAGMA foreign_key_check').get()).isNotEmpty ||
      (await db.customSelect('PRAGMA quick_check').getSingle())
              .data
              .values
              .single !=
          'ok') {
    throw const OperationFailure('MCP 服务范围升级校验失败，已保留原数据');
  }
  await db.customStatement('PRAGMA user_version = 11');
});

List<dynamic> _list(String encoded) {
  final value = _decode(encoded);
  if (value is List) return value;
  throw const OperationFailure('MCP 启用范围或目录无法读取，已保留原数据');
}

Set<String> _selectedNames(String encoded) {
  final values = _list(encoded);
  if (values.any((value) => value is! String || value.isEmpty)) {
    throw const OperationFailure('MCP 启用范围无法读取，已保留原数据');
  }
  return values.cast<String>().toSet();
}

Object? _decode(String encoded) {
  try {
    return jsonDecode(encoded);
  } on FormatException {
    throw const OperationFailure('MCP 升级数据无法读取，已保留原数据');
  }
}

Map<String, dynamic> _object(Object? value) {
  if (value is Map<String, dynamic>) return value;
  throw const OperationFailure('MCP 工具来源无法读取，已保留原数据');
}
