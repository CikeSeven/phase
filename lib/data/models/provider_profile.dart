import 'package:json_annotation/json_annotation.dart';

import 'api_protocol.dart';
import 'openai_compat.dart';
import 'profile_model.dart';

part 'provider_profile.g.dart';

/// 一个服务商配置。
///
/// 协议与服务商正交：protocol 决定报文格式，presetId 记录创建时用的预设。
/// 安全纪律：API Key 不在本模型中，单独经 flutter_secure_storage 按
/// profile id 存取（见 secure_key_storage.dart）。
@JsonSerializable(explicitToJson: true)
class ProviderProfile {
  const ProviderProfile({
    required this.id,
    required this.name,
    required this.baseUrl,
    this.protocol = ApiProtocol.openaiCompletions,
    this.presetId = 'custom',
    this.models = const [],
    this.defaultModel,
    this.compatOverrides,
    this.createdAt,
  });

  final String id;

  /// 用户起的名字（如「DeepSeek 官方」）。
  final String name;

  /// 如 `https://api.openai.com/v1`。
  final String baseUrl;

  /// 报文协议。
  final ApiProtocol protocol;

  /// 创建时选用的预设 id（custom 表示完全自定义）。
  final String presetId;

  /// 用户维护的模型列表（可手动添加，或由 listModels 拉取填充）。
  final List<ProfileModel> models;

  /// 默认使用的模型 id；为空时上层回退到 [modelCandidates] 第一个。
  final String? defaultModel;

  /// OpenAI 兼容协议的差异覆盖；为 null 时按 baseUrl 嗅探。
  /// 仅 protocol 为 openaiCompletions 时有意义。
  final OpenAiCompat? compatOverrides;

  final DateTime? createdAt;

  /// 可选模型候选：默认模型优先，与 [models] 合并去重。
  List<ProfileModel> get modelCandidates {
    final result = [...models];
    final fallback = defaultModel;
    if (fallback != null && result.every((m) => m.id != fallback)) {
      result.insert(
        0,
        ProfileModel(
          id: fallback,
          supportsReasoning: guessSupportsReasoning(fallback),
        ),
      );
    }
    return result;
  }

  ProviderProfile copyWith({
    String? name,
    String? baseUrl,
    ApiProtocol? protocol,
    String? presetId,
    List<ProfileModel>? models,
    String? defaultModel,
  }) {
    return ProviderProfile(
      id: id,
      name: name ?? this.name,
      baseUrl: baseUrl ?? this.baseUrl,
      protocol: protocol ?? this.protocol,
      presetId: presetId ?? this.presetId,
      models: models ?? this.models,
      defaultModel: defaultModel ?? this.defaultModel,
      compatOverrides: compatOverrides,
      createdAt: createdAt,
    );
  }

  factory ProviderProfile.fromJson(Map<String, dynamic> json) =>
      _$ProviderProfileFromJson(json);

  Map<String, dynamic> toJson() => _$ProviderProfileToJson(this);
}
