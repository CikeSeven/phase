import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import '../../../core/error/failure.dart';
import '../../../core/media/attachment_image_processor.dart';
import 'file_text.dart';
import 'tool.dart';

const maxReadImageBytes = 64 * 1024 * 1024;
const _maxReadImagePixels = 16 * 1024 * 1024;
const _imageHeaderBytes = 4100;

String? readImageMimeType(List<int> bytes) {
  try {
    if (bytes.length > _imageHeaderBytes) {
      bytes = bytes.sublist(0, _imageHeaderBytes);
    }
    final format = img.findFormatForData(Uint8List.fromList(bytes));
    return switch (format) {
      img.ImageFormat.jpg => 'image/jpeg',
      img.ImageFormat.png => 'image/png',
      img.ImageFormat.gif => 'image/gif',
      img.ImageFormat.webp => 'image/webp',
      img.ImageFormat.bmp => 'image/bmp',
      _ => null,
    };
  } on Object {
    return null;
  }
}

Future<ToolOutcome?> readImageFileOnDisk(
  File file,
  String name,
  ToolContext context,
  RunCancellation cancellation,
) async {
  final handle = await file.open();
  late final List<int> prefix;
  try {
    prefix = await handle.read(_imageHeaderBytes);
  } finally {
    await handle.close();
  }
  final mimeType = readImageMimeType(prefix);
  if (mimeType == null) return null;
  final size = await file.length();
  if (size > maxReadImageBytes) {
    throw const FileToolException('imageTooLarge', '图片文件超过 64 MiB，无法读取');
  }
  return readImageFile(
    await file.readAsBytes(),
    name,
    mimeType,
    context,
    cancellation,
  );
}

Future<ToolOutcome?> readImageFile(
  List<int> bytes,
  String name,
  String mimeType,
  ToolContext context,
  RunCancellation cancellation,
) async {
  if (bytes.length > maxReadImageBytes) {
    throw const FileToolException('imageTooLarge', '图片文件超过 64 MiB，无法读取');
  }
  cancellation.throwIfCancelled();
  final source = Uint8List.fromList(bytes);
  final info = _imageDimensions(source);
  if (info == null ||
      info.width < 1 ||
      info.height < 1 ||
      info.width * info.height > _maxReadImagePixels) {
    throw const FileToolException('invalidImage', '图片无法解码或像素尺寸过大，无法读取');
  }

  final ({List<int> bytes, String mimeType}) processed;
  try {
    processed = await AttachmentImageProcessor().process(bytes, mimeType);
  } on Failure catch (error) {
    throw FileToolException('imageProcessingFailed', error.userMessage);
  } on Object {
    throw const FileToolException('imageProcessingFailed', '图片处理失败，无法读取');
  }
  cancellation.throwIfCancelled();
  final output = Uint8List.fromList(processed.bytes);
  final outputInfo = _imageDimensions(output);
  if (outputInfo == null) {
    throw const FileToolException('invalidImage', '图片处理失败，无法读取');
  }
  final extension = switch (processed.mimeType) {
    'image/png' => '.png',
    'image/gif' => '.gif',
    'image/webp' => '.webp',
    'image/bmp' => '.bmp',
    _ => '.jpg',
  };
  final stem = p.basenameWithoutExtension(name);
  final outputName = '${stem.isEmpty ? 'image' : stem}$extension';
  final attachment = await context.storage.registerBytes(
    conversationId: context.conversationId,
    name: outputName,
    mimeType: processed.mimeType,
    bytes: processed.bytes,
  );
  return ToolOutcome.success(
    jsonEncode({
      'type': 'image',
      'name': name,
      'mimeType': processed.mimeType,
      'width': outputInfo.width,
      'height': outputInfo.height,
    }),
    artifacts: [attachment.id],
  );
}

({int width, int height})? _imageDimensions(Uint8List bytes) {
  try {
    final info = img.findDecoderForData(bytes)?.startDecode(bytes);
    return info == null ? null : (width: info.width, height: info.height);
  } on Object {
    return null;
  }
}
