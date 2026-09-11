import 'dart:convert';

import 'package:json_annotation/json_annotation.dart';

part 'profile_model.g.dart';

/// 服务商配置下的一个模型条目。
@JsonSerializable()
class ProfileModel {
  const ProfileModel({
    required this.id,
    this.enabled = true,
    this.supportsReasoning = false,
    this.supportsTools = true,
    this.supportsImages = true,
  });

  /// 调用 API 时使用的模型 id（如 `deepseek-reasoner`）。
  final String id;

  /// 是否启用；只有启用的模型才出现在聊天页的模型选择列表。
  final bool enabled;

  /// 是否支持推理（思考）能力；支持时聊天页可选择推理等级。
  final bool supportsReasoning;

  /// 是否支持工具调用；默认支持，个别模型不支持时手动关闭。
  final bool supportsTools;

  /// 是否支持图片输入；默认支持，纯文本模型手动关闭。
  final bool supportsImages;

  ProfileModel copyWith({
    bool? enabled,
    bool? supportsReasoning,
    bool? supportsTools,
    bool? supportsImages,
  }) {
    return ProfileModel(
      id: id,
      enabled: enabled ?? this.enabled,
      supportsReasoning: supportsReasoning ?? this.supportsReasoning,
      supportsTools: supportsTools ?? this.supportsTools,
      supportsImages: supportsImages ?? this.supportsImages,
    );
  }

  factory ProfileModel.fromJson(Map<String, dynamic> json) =>
      _$ProfileModelFromJson(json);

  Map<String, dynamic> toJson() => _$ProfileModelToJson(this);
}

/// 按模型 id 启发式预填「支持推理」：覆盖主流推理模型的命名习惯。
bool guessSupportsReasoning(String modelId) {
  final id = modelId.toLowerCase();
  const hints = [
    'reasoner',
    'r1',
    'o1',
    'o3',
    'gpt-5',
    'qwq',
    'thinking',
    'gemini-2',
    'gemini-3',
    'claude',
  ];
  return hints.any(id.contains);
}

/// 解码 drift 中存储的模型列表 JSON。
///
/// 兼容老格式：纯字符串列表（v1~v3 数据）自动转换为带推理标记的条目。
List<ProfileModel> decodeProfileModels(String modelsJson) {
  try {
    final decoded = jsonDecode(modelsJson);
    if (decoded is! List) {
      return const [];
    }
    return [
      for (final item in decoded)
        if (item is String)
          ProfileModel(
            id: item,
            supportsReasoning: guessSupportsReasoning(item),
          )
        else if (item is Map<String, dynamic>)
          ProfileModel.fromJson(item),
    ];
  } on FormatException {
    return const [];
  }
}

String encodeProfileModels(List<ProfileModel> models) {
  return jsonEncode([for (final model in models) model.toJson()]);
}
