import 'dart:convert';

import 'package:json_annotation/json_annotation.dart';

part 'chat_attachment.g.dart';

/// 消息附件类型：图片 / 文本文件。
enum ChatAttachmentType { image, file }

/// 一条消息的附件（仅元数据；二进制本体在应用私有目录，见 AttachmentStorage）。
///
/// 协议层读取时按 type 编码：图片为 base64 data，文件为内联文本。
@JsonSerializable()
class ChatAttachment {
  const ChatAttachment({
    required this.id,
    required this.type,
    required this.name,
    required this.mimeType,
    required this.path,
    required this.size,
  });

  final String id;
  final ChatAttachmentType type;

  /// 展示名（原文件名或「拍摄的照片」）。
  final String name;
  final String mimeType;

  /// 应用私有目录下的绝对路径。
  final String path;

  /// 文件字节数。
  final int size;

  factory ChatAttachment.fromJson(Map<String, dynamic> json) =>
      _$ChatAttachmentFromJson(json);

  Map<String, dynamic> toJson() => _$ChatAttachmentToJson(this);
}

/// 解码 drift 中存储的附件列表 JSON；非法内容按空列表处理。
List<ChatAttachment> decodeChatAttachments(String json) {
  try {
    final decoded = jsonDecode(json);
    if (decoded is! List) return const [];
    return [
      for (final item in decoded)
        if (item is Map<String, dynamic>) ChatAttachment.fromJson(item),
    ];
  } on FormatException {
    return const [];
  }
}

String encodeChatAttachments(List<ChatAttachment> attachments) {
  return jsonEncode([
    for (final attachment in attachments) attachment.toJson(),
  ]);
}
