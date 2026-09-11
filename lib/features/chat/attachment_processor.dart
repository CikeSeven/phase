import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../../core/error/failure.dart';

/// 发送前的图片处理：限尺寸、限 base64 体积（压在 Anthropic 5MB 之下）、
/// 超大时转 JPEG。GIF 原样保留（重编码会丢动画），超限报错。
class AttachmentImageProcessor {
  /// 最长边（px）。
  static const maxDimension = 2000;

  /// base64 编码后的体积上限。
  static const maxBase64Bytes = 4.5 * 1024 * 1024;

  /// 处理图片字节，返回（处理后的字节, mimeType）。
  Future<({List<int> bytes, String mimeType})> process(
    List<int> bytes,
    String mimeType,
  ) async {
    if (mimeType == 'image/gif') {
      if (bytes.length * 4 / 3 > maxBase64Bytes) {
        throw const UnknownFailure('GIF 图片过大，无法发送');
      }
      return (bytes: bytes, mimeType: mimeType);
    }
    final decoded = _decode(bytes);
    if (decoded == null) {
      throw const UnknownFailure('无法识别的图片格式');
    }
    var current = decoded;
    if (current.width > maxDimension || current.height > maxDimension) {
      current = img.copyResize(
        current,
        width: current.width >= current.height ? maxDimension : null,
        height: current.width >= current.height ? null : maxDimension,
      );
    }
    // 带透明通道用 PNG，其余 JPEG；仍超限就继续降档。
    final hasAlpha = current.numChannels > 3;
    List<int> encoded = hasAlpha
        ? img.encodePng(current)
        : img.encodeJpg(current, quality: 85);
    var resultMime = hasAlpha ? 'image/png' : 'image/jpeg';
    if (encoded.length * 4 / 3 > maxBase64Bytes) {
      current = img.copyResize(
        current,
        width: current.width >= current.height ? 1200 : null,
        height: current.width >= current.height ? null : 1200,
      );
      encoded = img.encodeJpg(current, quality: 75);
      resultMime = 'image/jpeg';
    }
    if (encoded.length * 4 / 3 > maxBase64Bytes) {
      throw const UnknownFailure('图片过大，无法发送');
    }
    return (bytes: encoded, mimeType: resultMime);
  }

  /// image 包对损坏内容可能抛 RangeError 而不是返回 null，统一归为无法识别。
  img.Image? _decode(List<int> bytes) {
    try {
      return img.decodeImage(Uint8List.fromList(bytes));
    } on Object {
      return null;
    }
  }
}
