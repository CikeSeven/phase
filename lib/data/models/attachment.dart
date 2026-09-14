/// 附件类型：图片、文本、PDF/DOCX 文档与工具执行产物。
///
/// PDF/DOCX 在导入时抽取文本，抽取结果与原始文件分开保存。
enum AttachmentKind { image, text, pdf, docx, artifact }

AttachmentKind attachmentKindFromName(String name) {
  for (final kind in AttachmentKind.values) {
    if (kind.name == name) return kind;
  }
  // 未知类型按文本处理：内容仍可进入上下文，图片必须类型明确。
  return AttachmentKind.text;
}

/// 一个附件：元数据与私有目录路径。
///
/// 二进制本体在 AttachmentStorage，数据库保存引用与抽取结果；
/// 附件可被同一会话的多个分支引用，不随单条消息删除。
class Attachment {
  const Attachment({
    required this.id,
    this.conversationId,
    required this.kind,
    required this.name,
    required this.mimeType,
    required this.size,
    required this.localPath,
    required this.createdAt,
    this.sha256,
    this.extractedTextPath,
    this.extractionError,
    this.width,
    this.height,
  });

  final String id;

  /// 所属会话；选择附件时会话可能尚未创建，落库前必须认领。
  final String? conversationId;

  final AttachmentKind kind;
  final String name;
  final String mimeType;
  final int size;
  final String localPath;
  final String? sha256;

  /// 文本/PDF/DOCX 抽取结果所在的私有文件路径。
  final String? extractedTextPath;

  /// 抽取失败的原因（如扫描件需要 OCR）；成功或未尝试时为 null。
  final String? extractionError;

  /// 图片像素尺寸。
  final int? width;
  final int? height;

  final DateTime createdAt;

  bool get isImage =>
      kind == AttachmentKind.image ||
      (kind == AttachmentKind.artifact && mimeType.startsWith('image/'));

  /// 文档类附件：内容以抽取文本参与请求。
  bool get isDocument =>
      kind == AttachmentKind.pdf || kind == AttachmentKind.docx;

  /// 认领到会话；已认领的附件保持原会话不变。
  Attachment withConversation(String conversationId) => Attachment(
    id: id,
    conversationId: this.conversationId ?? conversationId,
    kind: kind,
    name: name,
    mimeType: mimeType,
    size: size,
    localPath: localPath,
    sha256: sha256,
    extractedTextPath: extractedTextPath,
    extractionError: extractionError,
    width: width,
    height: height,
    createdAt: createdAt,
  );

  /// 复制到另一个会话；文件路径由 [AttachmentStorage] 复制后传入。
  Attachment copyTo({
    required String conversationId,
    required String id,
    required String localPath,
    String? extractedTextPath,
  }) => Attachment(
    id: id,
    conversationId: conversationId,
    kind: kind,
    name: name,
    mimeType: mimeType,
    size: size,
    localPath: localPath,
    sha256: sha256,
    extractedTextPath: extractedTextPath,
    extractionError: extractionError,
    width: width,
    height: height,
    createdAt: createdAt,
  );

  Attachment withExtraction({String? extractedTextPath, String? error}) =>
      Attachment(
        id: id,
        conversationId: conversationId,
        kind: kind,
        name: name,
        mimeType: mimeType,
        size: size,
        localPath: localPath,
        sha256: sha256,
        extractedTextPath: extractedTextPath ?? this.extractedTextPath,
        extractionError: error,
        width: width,
        height: height,
        createdAt: createdAt,
      );
}
