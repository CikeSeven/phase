import 'dart:convert';
import 'dart:io';

import '../data/models/chat_attachment.dart';
import '../data/models/chat_request.dart';
import '../data/models/provider_profile.dart';

/// 编码后的附件负载：图片为无前缀 base64，文件为内联文本。
class AttachmentPayload {
  const AttachmentPayload({
    required this.type,
    required this.name,
    required this.mimeType,
    this.base64Data,
    this.text,
  });

  final ChatAttachmentType type;
  final String name;
  final String mimeType;

  /// 图片的无前缀 base64；非图片为 null。
  final String? base64Data;

  /// 文件的内联文本（含文件名头）；图片为 null。
  final String? text;

  bool get isImage => type == ChatAttachmentType.image && base64Data != null;
}

/// 把消息附件编码为协议负载：读文件 → base64 / 内联文本。
///
/// 模型未标记支持图片时图片降级为占位文本（pi 同款降级策略）；
/// 附件文件已丢失时不阻断发送，降级为占位文本。
Future<List<AttachmentPayload>> encodeAttachments(
  List<ChatAttachment> attachments, {
  required bool supportsImages,
}) async {
  final result = <AttachmentPayload>[];
  for (final attachment in attachments) {
    switch (attachment.type) {
      case ChatAttachmentType.image:
        if (!supportsImages) {
          result.add(_textPlaceholder(attachment, '[图片已省略：当前模型不支持图片输入]'));
          continue;
        }
        final file = File(attachment.path);
        if (!file.existsSync()) {
          result.add(_textPlaceholder(attachment, '[图片文件已丢失]'));
          continue;
        }
        final bytes = await file.readAsBytes();
        result.add(
          AttachmentPayload(
            type: attachment.type,
            name: attachment.name,
            mimeType: attachment.mimeType,
            base64Data: base64Encode(bytes),
          ),
        );
      case ChatAttachmentType.file:
        final file = File(attachment.path);
        if (!file.existsSync()) {
          result.add(_textPlaceholder(attachment, '[附件已丢失]'));
          continue;
        }
        String content;
        try {
          content = await file.readAsString();
        } on FileSystemException {
          result.add(_textPlaceholder(attachment, '[附件读取失败]'));
          continue;
        }
        result.add(
          AttachmentPayload(
            type: attachment.type,
            name: attachment.name,
            mimeType: attachment.mimeType,
            text: '<附件 name="${attachment.name}">\n$content\n</附件>',
          ),
        );
    }
  }
  return result;
}

AttachmentPayload _textPlaceholder(ChatAttachment attachment, String notice) {
  return AttachmentPayload(
    type: ChatAttachmentType.file,
    name: attachment.name,
    mimeType: 'text/plain',
    text: notice,
  );
}

/// 查询模型是否标记支持图片输入；未登记的模型默认支持（与编辑页默认值一致）。
bool modelSupportsImages(ProviderProfile profile, String modelId) {
  for (final model in profile.modelCandidates) {
    if (model.id == modelId) {
      return model.supportsImages;
    }
  }
  return true;
}

/// 把请求里每条消息的附件编码为协议负载，返回值与 request.messages 按下标对齐；
/// 全为空时返回 null，让报文构造保持纯文本快路径。
Future<List<List<AttachmentPayload>>?> encodeRequestAttachments(
  ChatRequest request, {
  required bool supportsImages,
}) async {
  if (request.messages.every((message) => message.attachments.isEmpty)) {
    return null;
  }
  return [
    for (final message in request.messages)
      if (message.attachments.isEmpty)
        const <AttachmentPayload>[]
      else
        await encodeAttachments(
          message.attachments,
          supportsImages: supportsImages,
        ),
  ];
}
