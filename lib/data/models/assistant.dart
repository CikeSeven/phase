import 'dart:convert';

import 'model_selection.dart';
import 'tool_policy.dart';

/// 助手的工具配置：按工具名声明策略，未列出的工具不向该助手开放。
///
/// 持久化结构即 工具名 → 策略 的 JSON 对象；
/// 策略为 deny 的工具不进入模型的工具定义（收到调用也不执行）。
class ToolPolicyConfig {
  const ToolPolicyConfig({this.policies = const {}});

  final Map<String, ToolPolicy> policies;

  /// 本次运行开放给模型的工具：显式允许与询问的都开放，deny 的不开放。
  Set<String> get enabledTools => {
    for (final entry in policies.entries)
      if (entry.value != ToolPolicy.deny)
        if (entry.key == applicationOperationsPolicyKey)
          ...applicationOperationTools
        else if (!applicationOperationTools.contains(entry.key))
          entry.key,
  };

  /// 工具级策略；未列出的工具不开放。
  Map<String, ToolPolicy> get overrides => {
    for (final entry in policies.entries)
      if (!applicationOperationTools.contains(entry.key))
        entry.key: entry.value,
  };

  ToolPolicyConfig withPolicy(String toolName, ToolPolicy policy) {
    return ToolPolicyConfig(policies: {...policies, toolName: policy});
  }

  String encode() => jsonEncode({
    for (final entry in overrides.entries) entry.key: entry.value.name,
  });

  factory ToolPolicyConfig.decode(String? json) {
    if (json == null || json.isEmpty) return const ToolPolicyConfig();
    final decoded = jsonDecode(json);
    if (decoded is! Map<String, dynamic>) return const ToolPolicyConfig();
    return ToolPolicyConfig(
      policies: {
        for (final entry in decoded.entries)
          if (!applicationOperationTools.contains(entry.key))
            entry.key: toolPolicyFromName(entry.value as String?),
      },
    );
  }
}

/// 一个助手：系统提示词、默认模型与工具范围。
///
/// 删除助手不删除已有会话，会话之后可以重新选择助手。
class Assistant {
  const Assistant({
    required this.id,
    required this.name,
    required this.systemPrompt,
    this.defaultModelSelection,
    this.toolPolicy = defaultToolPolicyConfig,
    this.skillIds = const {},
    required this.createdAt,
  });

  final String id;
  final String name;
  final String systemPrompt;
  final ModelSelection? defaultModelSelection;
  final ToolPolicyConfig toolPolicy;
  final Set<String> skillIds;
  final DateTime createdAt;

  Assistant copyWith({
    String? name,
    String? systemPrompt,
    ModelSelection? defaultModelSelection,
    ToolPolicyConfig? toolPolicy,
    Set<String>? skillIds,
  }) {
    return Assistant(
      id: id,
      name: name ?? this.name,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      defaultModelSelection:
          defaultModelSelection ?? this.defaultModelSelection,
      toolPolicy: toolPolicy ?? this.toolPolicy,
      skillIds: skillIds ?? this.skillIds,
      createdAt: createdAt,
    );
  }
}

/// 初始助手：首次创建数据库时写入，未配置模型时由界面引导去配置。
const defaultAssistantName = '普通助手';

/// 新助手的显式默认范围；空 ToolPolicyConfig 始终表示全部禁止。
const defaultToolPolicyConfig = ToolPolicyConfig(
  policies: {
    'system_info': ToolPolicy.allow,
    'read_file': ToolPolicy.allow,
    'list_files': ToolPolicy.allow,
    'write_file': ToolPolicy.ask,
    'http_request': ToolPolicy.ask,
    applicationOperationsPolicyKey: ToolPolicy.ask,
  },
);

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
