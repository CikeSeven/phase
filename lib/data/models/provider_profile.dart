import 'package:json_annotation/json_annotation.dart';

part 'provider_profile.g.dart';

/// 服务商协议类型。
///
/// OpenAI 兼容协议是默认实现（AGENTS.md §4）：DeepSeek、Ollama、
/// 自定义网关等一律复用，仅 Base URL 不同。
enum ProviderType { openaiCompatible }

/// 一个服务商配置。
///
/// 安全纪律：API Key 不在本模型中，单独经 flutter_secure_storage 按
/// profile id 存取（见 secure_key_storage.dart）。
@JsonSerializable(explicitToJson: true)
class ProviderProfile {
  const ProviderProfile({
    required this.id,
    required this.name,
    required this.baseUrl,
    this.type = ProviderType.openaiCompatible,
    this.models = const [],
    this.defaultModel,
    this.createdAt,
  });

  final String id;

  /// 用户起的名字（如「DeepSeek 官方」）。
  final String name;

  /// 如 `https://api.openai.com/v1`。
  final String baseUrl;

  final ProviderType type;

  /// 用户维护的可用模型 id 列表（可后续由 listModels 拉取填充）。
  final List<String> models;

  /// 默认使用的模型；为空时上层回退到 [modelCandidates] 第一个。
  final String? defaultModel;

  final DateTime? createdAt;

  /// 可选模型候选：默认模型优先，与 [models] 合并去重。
  List<String> get modelCandidates => {?defaultModel, ...models}.toList();

  ProviderProfile copyWith({
    String? name,
    String? baseUrl,
    ProviderType? type,
    List<String>? models,
    String? defaultModel,
  }) {
    return ProviderProfile(
      id: id,
      name: name ?? this.name,
      baseUrl: baseUrl ?? this.baseUrl,
      type: type ?? this.type,
      models: models ?? this.models,
      defaultModel: defaultModel ?? this.defaultModel,
      createdAt: createdAt,
    );
  }

  factory ProviderProfile.fromJson(Map<String, dynamic> json) =>
      _$ProviderProfileFromJson(json);

  Map<String, dynamic> toJson() => _$ProviderProfileToJson(this);
}
