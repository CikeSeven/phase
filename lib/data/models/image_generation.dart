import 'dart:typed_data';

class ImageGenerationRequest {
  const ImageGenerationRequest({
    required this.prompt,
    this.size,
    this.quality,
    this.background,
    this.outputFormat,
  });

  final String prompt;
  final String? size;
  final String? quality;
  final String? background;
  final String? outputFormat;
}

typedef GeneratedImage = ({Uint8List bytes, String mimeType, String extension});
