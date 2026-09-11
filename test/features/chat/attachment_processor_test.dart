import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:phase/core/error/failure.dart';
import 'package:phase/features/chat/attachment_processor.dart';

void main() {
  final processor = AttachmentImageProcessor();

  img.Image noise(int width, int height) {
    final image = img.Image(width: width, height: height);
    for (final pixel in image) {
      pixel
        ..r = (pixel.x * 255 ~/ width)
        ..g = (pixel.y * 255 ~/ height)
        ..b = ((pixel.x + pixel.y) * 255 ~/ (width + height));
    }
    return image;
  }

  test('小图保持原格式（JPEG 进来 JPEG 出去）', () async {
    final bytes = img.encodeJpg(noise(320, 240), quality: 90);
    final result = await processor.process(bytes, 'image/jpeg');
    expect(result.mimeType, 'image/jpeg');
    expect(img.decodeImage(Uint8List.fromList(result.bytes)), isNotNull);
  });

  test('超长边等比缩到 2000px', () async {
    final bytes = img.encodeJpg(noise(4000, 1000), quality: 90);
    final result = await processor.process(bytes, 'image/jpeg');
    final decoded = img.decodeImage(Uint8List.fromList(result.bytes))!;
    expect(decoded.width, AttachmentImageProcessor.maxDimension);
    expect(decoded.height, 500);
  });

  test('带透明通道的 PNG 保持 PNG', () async {
    final image = img.Image(width: 64, height: 64, numChannels: 4);
    final bytes = img.encodePng(image);
    final result = await processor.process(bytes, 'image/png');
    expect(result.mimeType, 'image/png');
  });

  test('GIF 原样保留，超限报错', () async {
    final gif = img.encodeGif(noise(8, 8));
    final result = await processor.process(gif, 'image/gif');
    expect(result.bytes, gif);
    expect(result.mimeType, 'image/gif');

    final huge = List<int>.filled(
      (AttachmentImageProcessor.maxBase64Bytes * 0.9).round(),
      7,
    );
    expect(
      () => processor.process(huge, 'image/gif'),
      throwsA(isA<UnknownFailure>()),
    );
  });

  test('无法解码的内容报用户文案错误', () async {
    expect(
      () => processor.process([1, 2, 3, 4], 'image/jpeg'),
      throwsA(isA<UnknownFailure>()),
    );
  });
}
