import 'dart:convert';

import 'model_selection.dart';
import 'tool_policy.dart';

/// 助手的工具配置：按工具名声明策略，shell 默认询问，其他未列出的工具不向该助手开放。
///
/// 持久化结构即 工具名 → 策略 的 JSON 对象；
/// 策略为 deny 的工具不进入模型的工具定义（收到调用也不执行）。
class ToolPolicyConfig {
  const ToolPolicyConfig({this.policies = const {}});

  final Map<String, ToolPolicy> policies;

  /// 本次运行开放给模型的工具：显式允许与询问的都开放，deny 的不开放。
  Set<String> get enabledTools => {
    for (final entry in overrides.entries)
      if (entry.value != ToolPolicy.deny)
        if (entry.key == applicationOperationsPolicyKey)
          ...applicationOperationTools
        else if (!applicationOperationTools.contains(entry.key))
          entry.key,
  };

  /// 内置命令默认询问；显式 deny 保留，第三方工具仍须加入助手范围。
  Map<String, ToolPolicy> get overrides => {
    'shell': ToolPolicy.ask,
    'install_packages': ToolPolicy.ask,
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

/// 内置助手使用固定身份，改名后仍不可删除。
const defaultAssistantId = 'assistant-default';

/// 初始助手：首次创建数据库时写入，未配置模型时由界面引导去配置。
const defaultAssistantName = '相月';

/// 新助手的默认范围；命令默认询问，只有环境就绪时才注入。
const defaultToolPolicyConfig = ToolPolicyConfig(
  policies: {
    'shell': ToolPolicy.ask,
    'install_packages': ToolPolicy.ask,
    'system_info': ToolPolicy.allow,
    'read_file': ToolPolicy.allow,
    'list_files': ToolPolicy.allow,
    'write_file': ToolPolicy.ask,
    'edit_file': ToolPolicy.ask,
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
