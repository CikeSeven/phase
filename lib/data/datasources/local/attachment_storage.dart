import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/utils/id.dart';
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
