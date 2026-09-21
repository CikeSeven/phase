import 'package:json_annotation/json_annotation.dart';

part 'profile_model.g.dart';

/// 服务商下的一个模型配置；能力由用户显式设置并在请求时遵守。
@JsonSerializable()
class ProfileModel {
  const ProfileModel({
    required this.id,
    this.displayName,
    this.enabled = true,
    // 工具与图片按原型的宽松默认开启，确定不支持的模型由用户关闭；
    // 推理等级只有显式声明支持时才随请求下发。
    this.supportsReasoning = false,
    this.supportsTools = true,
    this.supportsImages = true,
    this.contextWindow,
    this.maxOutputTokens,
    this.temperature,
  });

  /// 请求中使用的模型 id（如 `deepseek-reasoner`）。
  final String id;

  /// 展示名；为空时展示 [id]。
  final String? displayName;

  /// 只有启用的模型才进入聊天选择列表。
  final bool enabled;

  final bool supportsReasoning;
  final bool supportsTools;
  final bool supportsImages;

  /// 上下文窗口用于本地预算；空值使用本地保守默认。输出上限为空时不下发。
  final int? contextWindow;
  final int? maxOutputTokens;

  /// 采样温度；未设置时不下发该字段。
  final double? temperature;

  String get label => displayName?.isNotEmpty == true ? displayName! : id;

  /// 能力设置的局部更新；未提供的字段保持不变。
  ProfileModel withSettings({
    String? displayName,
    bool? enabled,
    bool? supportsReasoning,
    bool? supportsTools,
    bool? supportsImages,
    int? contextWindow,
    int? maxOutputTokens,
    bool clearContextWindow = false,
    bool clearMaxOutputTokens = false,
    double? temperature,
  }) {
    return ProfileModel(
      id: id,
      displayName: displayName ?? this.displayName,
      enabled: enabled ?? this.enabled,
      supportsReasoning: supportsReasoning ?? this.supportsReasoning,
      supportsTools: supportsTools ?? this.supportsTools,
      supportsImages: supportsImages ?? this.supportsImages,
      contextWindow: clearContextWindow
          ? null
          : contextWindow ?? this.contextWindow,
      maxOutputTokens: clearMaxOutputTokens
          ? null
          : maxOutputTokens ?? this.maxOutputTokens,
      temperature: temperature ?? this.temperature,
    );
  }

  factory ProfileModel.fromJson(Map<String, dynamic> json) =>
      _$ProfileModelFromJson(json);

  Map<String, dynamic> toJson() => _$ProfileModelToJson(this);
}
