import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/error/failure.dart';
import '../../../data/datasources/local/attachment_storage.dart';
import '../../../data/models/attachment.dart';
import 'attachment_processor.dart';
import 'document_extractor.dart';

part 'attachment_picker.g.dart';

/// 文本类文件白名单扩展名（小写）；内容随附件进入请求上下文。
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

/// 文档附件（PDF/DOCX）的扩展名白名单。
const documentFileExtensions = {'pdf', 'docx'};

/// 文档附件的体积上限（抽取在导入时完成，需要更宽的上限）。
const maxDocumentBytes = 20 * 1024 * 1024;

/// 附件选择入口抽象：测试可注入假实现返回预制文件。
abstract class AttachmentPicker {
  /// 相册多选图片。
  Future<List<Attachment>> pickImages();

  /// 拍照。
  Future<Attachment?> pickCameraImage();

  /// 选择文本类文件（白名单见 [textFileExtensions]）。
  Future<List<Attachment>> pickFiles();
}

/// 平台实现：image_picker / file_picker + 图片压缩处理 + 落盘。
class PlatformAttachmentPicker implements AttachmentPicker {
  PlatformAttachmentPicker(
    this._storage,
    this._processor, {
    this.extractor = const DocumentExtractor(),
  });

  final AttachmentStorage _storage;
  final AttachmentImageProcessor _processor;
  final DocumentExtractor extractor;
  final _imagePicker = ImagePicker();

  @override
  Future<List<Attachment>> pickImages() async {
    final picked = await _imagePicker.pickMultiImage();
    return [for (final file in picked) await _saveImage(file)];
  }

  @override
  Future<Attachment?> pickCameraImage() async {
    final picked = await _imagePicker.pickImage(source: ImageSource.camera);
    return picked == null ? null : await _saveImage(picked);
  }

  Future<Attachment> _saveImage(XFile file) async {
    final bytes = await file.readAsBytes();
    final mime = lookupMimeType(file.name, headerBytes: bytes) ?? 'image/jpeg';
    final processed = await _processor.process(bytes, mime);
    return _storage.save(
      name: file.name,
      mimeType: processed.mimeType,
      kind: AttachmentKind.image,
      bytes: processed.bytes,
    );
  }

  @override
  Future<List<Attachment>> pickFiles() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        ...textFileExtensions,
        ...documentFileExtensions,
      ].toList(),
    );
    final attachments = <Attachment>[];
    for (final file in files) {
      final path = file.path;
      if (path == null) continue;
      final extension = file.extension?.toLowerCase() ?? '';
      final isDocument = documentFileExtensions.contains(extension);
      if (!isDocument && !textFileExtensions.contains(extension)) {
        throw UnknownFailure('不支持的文件类型：${file.name}');
      }
      final size = file.lengthSync() ?? await file.length();
      final limit = isDocument ? maxDocumentBytes : maxTextFileBytes;
      if (size > limit) {
        throw UnknownFailure(
          '文件过大（最多 ${limit ~/ (1024 * 1024)}MB）：${file.name}',
        );
      }
      final kind = switch (extension) {
        'pdf' => AttachmentKind.pdf,
        'docx' => AttachmentKind.docx,
        _ => AttachmentKind.text,
      };
      final attachment = await _storage.save(
        name: file.name,
        mimeType: lookupMimeType(file.name) ?? 'text/plain',
        kind: kind,
        bytes: await File(path).readAsBytes(),
      );
      if (!isDocument) {
        attachments.add(attachment);
        continue;
      }
      // 文档在导入时抽取文本：失败不阻止添加，但把原因记在附件上。
      attachments.add(await _extract(attachment, path, extension));
    }
    return attachments;
  }

  /// 抽取文档文本并落盘；失败时返回带失败原因的附件。
  Future<Attachment> _extract(
    Attachment attachment,
    String path,
    String extension,
  ) async {
    try {
      final result = await extractor.extract(path: path, extension: extension);
      final extractedPath = await _storage.saveExtractedText(
        attachment.id,
        result.text,
      );
      return attachment.withExtraction(extractedTextPath: extractedPath);
    } on DocumentExtractionException catch (error) {
      return attachment.withExtraction(error: error.reason);
    } on Exception catch (error) {
      return attachment.withExtraction(error: '文档读取失败：$error');
    }
  }
}

/// 附件选择器；依赖附件存储的异步初始化。
@Riverpod(keepAlive: true, dependencies: [attachmentStorage])
Future<AttachmentPicker> attachmentPicker(Ref ref) async {
  final storage = await ref.watch(attachmentStorageProvider.future);
  return PlatformAttachmentPicker(storage, AttachmentImageProcessor());
}
