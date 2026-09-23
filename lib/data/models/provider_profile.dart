import 'dart:convert';

import 'api_protocol.dart';
import 'openai_compat.dart';
import 'profile_model.dart';

/// 一个服务商配置；API Key 不在本模型中，按 [id] 交给 SecureKeyStorage。
///
/// [protocol] 由用户明确选择，创建后不因域名、模型名或请求失败自动切换。
class ProviderProfile {
  const ProviderProfile({
    required this.id,
    required this.name,
    required this.protocol,
    required this.baseUrl,
    this.requiresKey = true,
    this.presetId = 'custom',
    this.models = const [],
    this.defaultModel,
    this.compatOverrides,
    required this.createdAt,
  });

  final String id;
  final String name;
  final ApiProtocol protocol;

  /// 如 `https://api.openai.com/v1`。
  final String baseUrl;

  /// 是否需要鉴权；免 Key 服务商在请求中不发送鉴权头。
  final bool requiresKey;

  /// 创建时选用的预设 id；用于表单默认值和模型元数据目录映射，
  /// 不参与协议选择或请求参数推断。
  final String presetId;

  /// 用户维护的模型列表；启用的模型才进入聊天选择列表。
  final List<ProfileModel> models;

  /// 该服务商默认使用的模型 id；为空时由上层回退到启用的第一个模型。
  final String? defaultModel;

  /// OpenAI 兼容协议的差异声明；null 时用 [OpenAiCompat] 的默认值。
  final OpenAiCompat? compatOverrides;

  final DateTime createdAt;

  List<ProfileModel> get enabledModels => [
    for (final model in models)
      if (model.enabled) model,
  ];

  ProviderProfile copyWith({
    String? name,
    ApiProtocol? protocol,
    String? baseUrl,
    bool? requiresKey,
    String? presetId,
    List<ProfileModel>? models,
    String? defaultModel,
    OpenAiCompat? compatOverrides,
  }) {
    return ProviderProfile(
      id: id,
      name: name ?? this.name,
      protocol: protocol ?? this.protocol,
      baseUrl: baseUrl ?? this.baseUrl,
      requiresKey: requiresKey ?? this.requiresKey,
      presetId: presetId ?? this.presetId,
      models: models ?? this.models,
      defaultModel: defaultModel ?? this.defaultModel,
      compatOverrides: compatOverrides ?? this.compatOverrides,
      createdAt: createdAt,
    );
  }
}

/// 解码 models 列的 JSON；结构损坏时按空列表处理并保留可用的其他配置。
List<ProfileModel> decodeProfileModels(String? json) {
  if (json == null || json.isEmpty) return const [];
  try {
    final decoded = jsonDecode(json);
    if (decoded is! List) return const [];
    return [
      for (final item in decoded)
        if (item is Map<String, dynamic>) ProfileModel.fromJson(item),
    ];
  } on FormatException {
    return const [];
  }
}

String encodeProfileModels(List<ProfileModel> models) =>
    jsonEncode([for (final model in models) model.toJson()]);
