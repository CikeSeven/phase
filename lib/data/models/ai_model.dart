import 'package:json_annotation/json_annotation.dart';

part 'ai_model.g.dart';

/// 服务商提供的一个可用模型。
@JsonSerializable()
class AiModel {
  const AiModel({required this.id, this.displayName});

  /// 调用 API 时使用的模型 id（如 `gpt-4o-mini`）。
  final String id;

  /// 展示用名称，缺省时展示 [id]。
  final String? displayName;

  factory AiModel.fromJson(Map<String, dynamic> json) =>
      _$AiModelFromJson(json);

  Map<String, dynamic> toJson() => _$AiModelToJson(this);
}
