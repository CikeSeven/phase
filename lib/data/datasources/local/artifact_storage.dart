import 'dart:io';

import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;

import '../../../core/error/failure.dart';
import '../../../core/utils/id.dart';
import '../../../features/tools/tool.dart';
import '../../models/attachment.dart';

/// 工具运行需要的存储能力：会话附件、按会话隔离的产物目录与产物登记。
///
/// 产物写在附件根目录下的 `artifacts/<conversationId>/`：同属应用私有文件区，
/// 登记后与普通附件一样可被引用、查看与删除（design 第三部分 §4）。
///
/// 附件索引的读写由装配点注入（[loadAttachments] / [saveAttachment] 就是
/// 仓储的同名方法）：数据源只依赖模型与文件系统，不反向依赖仓储。
class ArtifactStorage implements ToolStorage {
  ArtifactStorage({
    required this.root,
    required this.loadAttachments,
    required this.saveAttachment,
  });

  /// 附件根目录；产物目录是它下面的子目录，测试注入临时目录。
  final Directory root;

  final Future<List<Attachment>> Function(String conversationId)
  loadAttachments;
  final Future<void> Function(Attachment attachment) saveAttachment;

  @override
  Future<List<Attachment>> attachments(String conversationId) =>
      _guard(() => loadAttachments(conversationId));

  @override
  String artifactsDirectory(String conversationId) =>
      p.join(root.path, 'artifacts', conversationId);

  @override
  Future<Attachment> registerArtifact({
    required String conversationId,
    required String path,
    required String name,
    String? sha256,
    String? extractedTextPath,
    String? extractionError,
  }) {
    return _register(
      conversationId: conversationId,
      path: path,
      name: name,
      mimeType: lookupMimeType(name) ?? 'application/octet-stream',
      sha256: sha256,
      extractedTextPath: extractedTextPath,
      extractionError: extractionError,
    );
  }

  @override
  Future<Attachment> registerBytes({
    required String conversationId,
    required String name,
    required String mimeType,
    required List<int> bytes,
  }) => _guard(() async {
    final directory = Directory(artifactsDirectory(conversationId));
    await directory.create(recursive: true);
    final file = File(p.join(directory.path, _uniqueName(directory, name)));
    await file.writeAsBytes(bytes, flush: true);
    return _register(
      conversationId: conversationId,
      path: file.path,
      // 文件名可能因重名加了后缀：附件名与磁盘上的名字保持一致。
      name: p.basename(file.path),
      mimeType: mimeType,
    );
  });

  /// 把产物目录里尚未登记的产物写成附件。
  ///
  /// 每次执行后统一扫描一次：工具自己登记过并写进结果引用的产物不在待登记
  /// 范围内，这里兜住其余写到产物目录却没有登记的文件。
  Future<List<Attachment>> registerPendingArtifacts(String conversationId) =>
      _guard(() async {
        final directory = Directory(artifactsDirectory(conversationId));
        if (!directory.existsSync()) return const [];
        final known = {
          for (final attachment in await attachments(conversationId)) ...[
            p.normalize(attachment.localPath),
            if (attachment.extractedTextPath != null)
              p.normalize(attachment.extractedTextPath!),
          ],
        };
        final registered = <Attachment>[];
        for (final entity in directory.listSync(recursive: true)) {
          if (entity is! File) continue;
          if (known.contains(p.normalize(entity.path))) continue;
          registered.add(
            await registerArtifact(
              conversationId: conversationId,
              path: entity.path,
              // 嵌套目录下的产物保留相对路径，重名时能区分。
              name: p.relative(entity.path, from: directory.path),
            ),
          );
        }
        return registered;
      });

  Future<Attachment> _register({
    required String conversationId,
    required String path,
    required String name,
    required String mimeType,
    String? sha256,
    String? extractedTextPath,
    String? extractionError,
  }) => _guard(() async {
    final file = File(path);
    final attachment = Attachment(
      id: generateId(),
      conversationId: conversationId,
      kind: AttachmentKind.artifact,
      name: name,
      mimeType: mimeType,
      size: file.existsSync() ? file.lengthSync() : 0,
      localPath: path,
      sha256: sha256,
      extractedTextPath: extractedTextPath,
      extractionError: extractionError,
      createdAt: DateTime.now(),
    );
    await saveAttachment(attachment);
    return attachment;
  });

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on StorageFailure {
      rethrow;
    } catch (error) {
      throw StorageFailure('工具产物读取或保存失败', cause: error);
    }
  }

  /// 同名产物不覆盖：登记的名字与磁盘文件名始终一一对应。
  String _uniqueName(Directory directory, String name) {
    final safe = p.basename(name.trim().isEmpty ? 'artifact' : name.trim());
    if (!File(p.join(directory.path, safe)).existsSync()) return safe;
    final extension = p.extension(safe);
    final stem = safe.substring(0, safe.length - extension.length);
    for (var index = 1; ; index++) {
      final candidate = '$stem-$index$extension';
      if (!File(p.join(directory.path, candidate)).existsSync()) {
        return candidate;
      }
    }
  }
}
