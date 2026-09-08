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

  final DateTime? createdAt;

  ProviderProfile copyWith({
    String? name,
    String? baseUrl,
    ProviderType? type,
    List<String>? models,
  }) {
    return ProviderProfile(
      id: id,
      name: name ?? this.name,
      baseUrl: baseUrl ?? this.baseUrl,
      type: type ?? this.type,
      models: models ?? this.models,
      createdAt: createdAt,
    );
  }

  factory ProviderProfile.fromJson(Map<String, dynamic> json) =>
      _$ProviderProfileFromJson(json);

  Map<String, dynamic> toJson() => _$ProviderProfileToJson(this);
}
