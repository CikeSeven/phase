import 'memory_entry.dart';

import 'dart:convert';

import 'model_selection.dart';

/// 一个助手：系统提示词、默认模型与扩展启用范围。
///
/// 删除助手不删除已有会话，会话之后可以重新选择助手。
class Assistant {
  const Assistant({
    required this.id,
    required this.name,
    required this.systemPrompt,
    this.defaultModelSelection,
    this.mcpToolNames = const {},
    this.skillIds = const {},
    this.memoryScope = MemoryScope.disabled,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String systemPrompt;
  final ModelSelection? defaultModelSelection;
  final Set<String> mcpToolNames;
  final Set<String> skillIds;
  final MemoryScope memoryScope;
  final DateTime createdAt;

  Assistant copyWith({
    String? name,
    String? systemPrompt,
    ModelSelection? defaultModelSelection,
    Set<String>? mcpToolNames,
    Set<String>? skillIds,
    MemoryScope? memoryScope,
  }) {
    return Assistant(
      id: id,
      name: name ?? this.name,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      defaultModelSelection:
          defaultModelSelection ?? this.defaultModelSelection,
      mcpToolNames: mcpToolNames ?? this.mcpToolNames,
      skillIds: skillIds ?? this.skillIds,
      memoryScope: memoryScope ?? this.memoryScope,
      createdAt: createdAt,
    );
  }
}

/// 内置助手使用固定身份，改名后仍不可删除。
const defaultAssistantId = 'assistant-default';

/// 初始助手：首次创建数据库时写入，未配置模型时由界面引导去配置。
const defaultAssistantName = '相月';

String encodeModelSelection(ModelSelection? selection) =>
    selection == null ? '' : jsonEncode(selection.toJson());

ModelSelection? decodeModelSelection(String? json) {
  if (json == null || json.isEmpty) return null;
  try {
    final decoded = jsonDecode(json);
    if (decoded is! Map<String, dynamic>) return null;
    return ModelSelection.fromJson(decoded);
  } on FormatException {
    return null;
  }
}
