import 'dart:convert';

import 'package:json_annotation/json_annotation.dart';

part 'profile_model.g.dart';

/// 服务商配置下的一个模型条目。
@JsonSerializable()
class ProfileModel {
  const ProfileModel({
    required this.id,
    this.enabled = true,
    this.supportsReasoning = true,
    this.supportsTools = true,
    this.supportsImages = true,
  });

  /// 调用 API 时使用的模型 id（如 `deepseek-reasoner`）。
  final String id;

  /// 是否启用；只有启用的模型才出现在聊天页的模型选择列表。
  final bool enabled;

  /// 是否支持推理（思考）能力；默认支持（等级是否合规交给服务商服务器
  /// 判断），确定不支持的模型可手动关闭以隐藏聊天页的等级滑杆。
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
          ProfileModel(id: item)
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
