part of 'app_database.dart';

/// 直接插入仍接受会话 ID，更新和项目资料支持解除会话归属。
class AttachmentsCompanion extends AttachmentChanges {
  const AttachmentsCompanion({
    super.id,
    super.conversationId,
    super.projectId,
    super.kind,
    super.name,
    super.mimeType,
    super.size,
    super.localPath,
    super.sha256,
    super.extractedTextPath,
    super.extractionError,
    super.width,
    super.height,
    super.createdAt,
    super.rowid,
  });

  AttachmentsCompanion.insert({
    required super.id,
    String? conversationId,
    super.projectId,
    required super.kind,
    required super.name,
    required super.mimeType,
    required super.size,
    required super.localPath,
    super.sha256,
    super.extractedTextPath,
    super.extractionError,
    super.width,
    super.height,
    required super.createdAt,
    super.rowid,
  }) : super.insert(conversationId: Value(conversationId));
}
