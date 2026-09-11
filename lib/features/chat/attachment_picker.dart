import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/error/failure.dart';
import '../../../data/datasources/local/attachment_storage.dart';
import '../../../data/models/chat_attachment.dart';
import 'attachment_processor.dart';

part 'attachment_picker.g.dart';

/// 文本类文件白名单扩展名（小写）；文件内容在请求时内联进报文。
const textFileExtensions = {
  'txt',
  'md',
  'markdown',
  'json',
  'jsonl',
  'csv',
  'log',
  'yaml',
  'yml',
  'xml',
  'html',
  'htm',
  'py',
  'dart',
  'js',
  'ts',
  'java',
  'kt',
  'kts',
  'c',
  'h',
  'cpp',
  'cc',
  'rs',
  'go',
  'sh',
  'sql',
  'toml',
  'ini',
  'env',
};

/// 文本附件的体积上限。
const maxTextFileBytes = 1024 * 1024;

/// 附件选择入口抽象：测试可注入假实现返回预制文件。
abstract class AttachmentPicker {
  /// 相册多选图片。
  Future<List<ChatAttachment>> pickImages();

  /// 拍照。
  Future<ChatAttachment?> pickCameraImage();

  /// 选择文本类文件（白名单见 [textFileExtensions]）。
  Future<List<ChatAttachment>> pickFiles();
}

/// 平台实现：image_picker / file_picker + 图片压缩处理 + 落盘。
class PlatformAttachmentPicker implements AttachmentPicker {
  PlatformAttachmentPicker(this._storage, this._processor);

  final AttachmentStorage _storage;
  final AttachmentImageProcessor _processor;
  final _imagePicker = ImagePicker();

  @override
  Future<List<ChatAttachment>> pickImages() async {
    final picked = await _imagePicker.pickMultiImage();
    return [for (final file in picked) await _saveImage(file)];
  }

  @override
  Future<ChatAttachment?> pickCameraImage() async {
    final picked = await _imagePicker.pickImage(source: ImageSource.camera);
    return picked == null ? null : await _saveImage(picked);
  }

  Future<ChatAttachment> _saveImage(XFile file) async {
    final bytes = await file.readAsBytes();
    final mime = lookupMimeType(file.name, headerBytes: bytes) ?? 'image/jpeg';
    final processed = await _processor.process(bytes, mime);
    return _storage.save(
      name: file.name,
      mimeType: processed.mimeType,
      type: ChatAttachmentType.image,
      bytes: processed.bytes,
    );
  }

  @override
  Future<List<ChatAttachment>> pickFiles() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: textFileExtensions.toList(),
    );
    final attachments = <ChatAttachment>[];
    for (final file in files) {
      final path = file.path;
      if (path == null) continue;
      final extension = file.extension?.toLowerCase() ?? '';
      if (!textFileExtensions.contains(extension)) {
        throw UnknownFailure('不支持的文件类型：${file.name}');
      }
      final size = file.lengthSync() ?? await file.length();
      if (size > maxTextFileBytes) {
        throw UnknownFailure('文件过大（最多 1MB）：${file.name}');
      }
      attachments.add(
        await _storage.save(
          name: file.name,
          mimeType: lookupMimeType(file.name) ?? 'text/plain',
          type: ChatAttachmentType.file,
          bytes: await File(path).readAsBytes(),
        ),
      );
    }
    return attachments;
  }
}

/// 附件选择器；依赖附件存储的异步初始化。
@Riverpod(keepAlive: true, dependencies: [attachmentStorage])
Future<AttachmentPicker> attachmentPicker(Ref ref) async {
  final storage = await ref.watch(attachmentStorageProvider.future);
  return PlatformAttachmentPicker(storage, AttachmentImageProcessor());
}
