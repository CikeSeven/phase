import 'dart:convert';
import 'dart:io';

import '../data/models/attachment.dart';
import '../data/models/provider_profile.dart';

/// 编码后的附件负载：图片为无前缀 base64，文档为内联文本。
class AttachmentPayload {
  const AttachmentPayload({
    required this.kind,
    required this.name,
    required this.mimeType,
    this.base64Data,
    this.text,
  });

  final AttachmentKind kind;
  final String name;
  final String mimeType;

  /// 图片的无前缀 base64；非图片为 null。
  final String? base64Data;

  /// 文档的内联文本（含文件名头）；图片为 null。
  final String? text;

  bool get isImage => kind == AttachmentKind.image && base64Data != null;

  /// data URI 形式，供 OpenAI 系协议的 image_url 使用。
  String get dataUri => 'data:$mimeType;base64,$base64Data';
}

/// 一次请求构建内的附件编码：同一个附件只读一次本地文件。
class RequestAttachmentEncoder {
  RequestAttachmentEncoder({required this.supportsImages});

  final bool supportsImages;
  final _encoded = <String, AttachmentPayload>{};

  Future<AttachmentPayload> encode(Attachment attachment) async {
    return _encoded[attachment.id] ??= await encodeAttachment(
      attachment,
      supportsImages: supportsImages,
    );
  }
}

/// 把一个附件编码为协议负载：读本地文件 → base64 / 内联文本。
///
/// 图片按 [AttachmentKind.image] 走 base64；其余类型统一作为文本上下文发送
/// （抽取结果见 [Attachment.extractedTextPath]，没有时退回原文件）。
/// 模型未标记支持图片时图片降级为占位文本；文件已丢失或读取失败时
/// 同样降级为占位文本，不阻断发送。
Future<AttachmentPayload> encodeAttachment(
  Attachment attachment, {
  required bool supportsImages,
}) async {
  if (attachment.kind == AttachmentKind.image) {
    if (!supportsImages) {
      return _placeholder(attachment, '[图片已省略：当前模型不支持图片输入]');
    }
    final bytes = await _readBytes(attachment.localPath);
    if (bytes == null) {
      return _placeholder(attachment, '[图片文件已丢失]');
    }
    return AttachmentPayload(
      kind: attachment.kind,
      name: attachment.name,
      mimeType: attachment.mimeType,
      base64Data: base64Encode(bytes),
    );
  }

  final text = await _readText(
    attachment.extractedTextPath ?? attachment.localPath,
  );
  if (text == null) {
    return _placeholder(attachment, '[附件已丢失]');
  }
  return AttachmentPayload(
    kind: attachment.kind,
    name: attachment.name,
    mimeType: attachment.mimeType,
    text: '<附件 name="${attachment.name}">\n$text\n</附件>',
  );
}

AttachmentPayload _placeholder(Attachment attachment, String notice) {
  return AttachmentPayload(
    kind: AttachmentKind.text,
    name: attachment.name,
    mimeType: 'text/plain',
    text: notice,
  );
}

Future<List<int>?> _readBytes(String path) async {
  try {
    return await File(path).readAsBytes();
  } on FileSystemException {
    return null;
  }
}

Future<String?> _readText(String path) async {
  try {
    return await File(path).readAsString();
  } on FileSystemException {
    // 文件不存在或不可读。
    return null;
  } on FormatException {
    // 非文本内容按读取失败处理，不用损坏的字节拼上下文。
    return null;
  }
}

/// 模型是否标记支持图片输入；未登记的模型默认支持（与配置页默认值一致）。
bool modelSupportsImages(ProviderProfile profile, String modelId) {
  for (final model in profile.models) {
    if (model.id == modelId) {
      return model.supportsImages;
    }
  }
  return true;
}

/// 模型是否标记支持推理；未登记的模型默认支持，
/// 是否真正下发由用户选择的推理等级表达。
bool modelSupportsReasoning(ProviderProfile profile, String modelId) {
  for (final model in profile.models) {
    if (model.id == modelId) {
      return model.supportsReasoning;
    }
  }
  return true;
}
