import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/utils/id.dart';
import '../../../core/error/failure.dart';
import '../../models/attachment.dart';

part 'attachment_storage.g.dart';

/// 附件二进制落盘：统一放在应用私有目录 `attachments/` 下，数据库只存元数据。
class AttachmentStorage {
  AttachmentStorage(this.root);

  /// 附件根目录；测试注入临时目录。
  final Directory root;

  static Future<AttachmentStorage> create() async {
    final documents = await getApplicationDocumentsDirectory();
    return AttachmentStorage(Directory(p.join(documents.path, 'attachments')));
  }

  /// 写入附件并返回元数据；文件名用生成的 id + 扩展名，与原始文件名解耦。
  ///
  /// 落盘时还不知道所属会话（会话在发送时创建），会话归属由会话侧认领。
  Future<Attachment> save({
    required String name,
    required String mimeType,
    required AttachmentKind kind,
    required List<int> bytes,
    int? width,
    int? height,
  }) async {
    await root.create(recursive: true);
    final id = generateId();
    final extension = p.extension(name);
    final file = File(p.join(root.path, '$id$extension'));
    await file.writeAsBytes(bytes);
    return Attachment(
      id: id,
      kind: kind,
      name: name,
      mimeType: mimeType,
      size: bytes.length,
      localPath: file.path,
      width: width,
      height: height,
      createdAt: DateTime.now(),
    );
  }

  /// 保存文档的抽取文本，返回文本文件路径。
  ///
  /// 抽取结果与原始文件分开保存：请求用文本，查看用原文件。
  Future<String> saveExtractedText(String attachmentId, String text) async {
    await root.create(recursive: true);
    final file = File(p.join(root.path, '$attachmentId.extracted.txt'));
    await file.writeAsString(text);
    return file.path;
  }

  /// 把附件及其抽取文本复制到新 id，保证不同会话互不删除文件。
  Future<Attachment> copy(
    Attachment source, {
    required String conversationId,
    required String id,
  }) async {
    await root.create(recursive: true);
    final extension = p.extension(source.localPath);
    final copiedPath = p.join(root.path, '$id$extension');
    final extractedPath = source.extractedTextPath;
    final copiedTextPath = extractedPath == null
        ? null
        : p.join(root.path, '$id.extracted.txt');
    try {
      await File(source.localPath).copy(copiedPath);
      if (extractedPath != null) {
        await File(extractedPath).copy(copiedTextPath!);
      }
      return source.copyTo(
        conversationId: conversationId,
        id: id,
        localPath: copiedPath,
        extractedTextPath: copiedTextPath,
      );
    } catch (_) {
      await deletePaths([copiedPath, ?copiedTextPath]);
      rethrow;
    }
  }

  /// 会话删除包含未登记的中间产物；清理失败交给用户重试，不能伪装成功。
  Future<void> deleteConversationFiles(
    String conversationId,
    Iterable<String> paths,
  ) async {
    try {
      for (final path in paths.toSet()) {
        final file = File(path);
        if (await file.exists()) await file.delete();
      }
      final artifacts = Directory(
        p.join(root.path, 'artifacts', conversationId),
      );
      if (await artifacts.exists()) await artifacts.delete(recursive: true);
    } on FileSystemException {
      throw const OperationFailure('会话附件或产物清理失败，请重试删除会话');
    }
  }

  /// 删除附件文件；文件已不存在不算错误（删除会话时尽力清理）。
  Future<void> deletePaths(Iterable<String> paths) async {
    for (final path in paths) {
      try {
        await File(path).delete();
      } on FileSystemException {
        // 文件可能已被删或从未写入成功，忽略。
      }
    }
  }
}

@Riverpod(keepAlive: true)
Future<AttachmentStorage> attachmentStorage(Ref ref) {
  return AttachmentStorage.create();
}
