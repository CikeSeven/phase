import 'reasoning_effort.dart';

/// 一次运行使用的模型与参数；会话/助手保存默认值，运行创建时固定下来。
class ModelSelection {
  const ModelSelection({
    required this.profileId,
    required this.modelId,
    this.reasoningEffort = ReasoningEffort.off,
    this.temperature,
    this.maxOutputTokens,
  });

  final String profileId;
  final String modelId;

  /// 推理等级；模型不支持推理时不下发任何推理字段。
  final ReasoningEffort reasoningEffort;

  final double? temperature;
  final int? maxOutputTokens;

  ModelSelection copyWith({
    String? profileId,
    String? modelId,
    ReasoningEffort? reasoningEffort,
    double? temperature,
    int? maxOutputTokens,
  }) {
    return ModelSelection(
      profileId: profileId ?? this.profileId,
      modelId: modelId ?? this.modelId,
      reasoningEffort: reasoningEffort ?? this.reasoningEffort,
      temperature: temperature ?? this.temperature,
      maxOutputTokens: maxOutputTokens ?? this.maxOutputTokens,
    );
  }

  Map<String, dynamic> toJson() => {
    'profileId': profileId,
    'modelId': modelId,
    'reasoningEffort': reasoningEffort.name,
    if (temperature != null) 'temperature': temperature,
    if (maxOutputTokens != null) 'maxOutputTokens': maxOutputTokens,
  };

  factory ModelSelection.fromJson(Map<String, dynamic> json) => ModelSelection(
    profileId: json['profileId'] as String,
    modelId: json['modelId'] as String,
    reasoningEffort: ReasoningEffort.fromName(
      json['reasoningEffort'] as String?,
    ),
    temperature: (json['temperature'] as num?)?.toDouble(),
    maxOutputTokens: json['maxOutputTokens'] as int?,
  );
}
