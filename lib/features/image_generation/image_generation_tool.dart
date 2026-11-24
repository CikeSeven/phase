import '../../core/error/failure.dart';
import '../../data/models/image_generation.dart';
import '../../data/models/tool_policy.dart';
import '../../data/models/tool_source.dart';
import '../../data/repositories/image_generation_repository.dart';
import '../../data/repositories/media_generation_repository.dart';
import '../tools/tool.dart';

class ImageGenerationTool extends Tool {
  const ImageGenerationTool(this.repository, this.binding);

  static const toolName = 'generate_image';
  static const _maxPromptLength = 32000;
  static final _sizePattern = RegExp(r'^[1-9][0-9]{0,3}x[1-9][0-9]{0,3}$');
  static const _qualities = ['auto', 'low', 'medium', 'high'];
  static const _backgrounds = ['auto', 'opaque', 'transparent'];
  static const _formats = ['png', 'jpeg', 'webp'];
  static const _keys = {
    'prompt',
    'size',
    'quality',
    'background',
    'output_format',
  };

  final ImageGenerationRepository repository;
  final MediaGenerationBinding binding;

  @override
  String get name => toolName;

  @override
  String get description => '调用已配置的图像模型，根据提示词生成一张图片并返回会话附件。';

  @override
  String get promptSnippet => '用户要求画图或生成图片时，传入生图提示词和所需参数。';

  @override
  Set<String> get requiredCapabilities => const {'image_generation'};

  @override
  ToolPolicy get defaultPolicy => ToolPolicy.ask;

  @override
  ToolSource get source => ToolSource(
    kind: ToolSourceKind.builtIn,
    id: 'builtIn',
    originalName: name,
    definitionRevision: definitionDigest([
      name,
      description,
      inputSchema,
      binding.revision,
    ]),
  );

  @override
  Map<String, dynamic> get inputSchema => const {
    'type': 'object',
    'additionalProperties': false,
    'required': ['prompt'],
    'properties': {
      'prompt': {
        'type': 'string',
        'description': '描述图片的主体、构图、风格与画面文字。',
        'minLength': 1,
        'maxLength': _maxPromptLength,
      },
      'size': {'type': 'string', 'description': '像素宽度x高度，例如 1536x1024，或 auto。'},
      'quality': {'type': 'string', 'enum': _qualities, 'description': '输出画质。'},
      'background': {
        'type': 'string',
        'enum': _backgrounds,
        'description': '背景类型。',
      },
      'output_format': {
        'type': 'string',
        'enum': _formats,
        'description': '输出格式。透明背景使用 PNG 或 WebP。',
      },
    },
  };

  @override
  String? validateArguments(Map<String, dynamic> arguments) {
    final prompt = arguments['prompt'];
    if (prompt is! String ||
        prompt.trim().isEmpty ||
        prompt.length > _maxPromptLength) {
      return '请输入 1–32,000 字符的生图提示词';
    }
    if (arguments.keys.any((key) => !_keys.contains(key))) return '图像生成参数无效';
    if (arguments.containsKey('size')) {
      final size = arguments['size'];
      if (size is! String || (size != 'auto' && !_sizePattern.hasMatch(size))) {
        return '尺寸须为宽度x高度或 auto';
      }
    }
    if ((arguments.containsKey('quality') &&
            !_qualities.contains(arguments['quality'])) ||
        (arguments.containsKey('background') &&
            !_backgrounds.contains(arguments['background'])) ||
        (arguments.containsKey('output_format') &&
            !_formats.contains(arguments['output_format']))) {
      return '画质、背景或图片格式无效';
    }
    if (arguments['background'] == 'transparent' &&
        arguments['output_format'] == 'jpeg') {
      return '透明背景需要 PNG 或 WebP 格式';
    }
    return null;
  }

  @override
  String describeAction(Map<String, dynamic> arguments) {
    final parameters = [
      binding.target.modelId,
      for (final field in ['size', 'quality', 'background', 'output_format'])
        if (arguments[field] case final String value) value,
    ].join(' · ');
    return '$parameters\n${arguments['prompt'] ?? ''}';
  }

  @override
  Future<ToolOutcome> execute(
    Map<String, dynamic> arguments,
    ToolContext context,
    RunCancellation cancellation, {
    ToolProgress? onProgress,
  }) async {
    final error = validateArguments(arguments);
    if (error != null) {
      return ToolOutcome.failure(error, errorCode: 'invalidArguments');
    }
    await context.checkPermission?.call();
    cancellation.throwIfCancelled();
    try {
      final image = await repository.generate(
        binding: binding,
        request: ImageGenerationRequest(
          prompt: (arguments['prompt'] as String).trim(),
          size: arguments['size'] as String?,
          quality: arguments['quality'] as String?,
          background: arguments['background'] as String?,
          outputFormat: arguments['output_format'] as String?,
        ),
        cancellation: cancellation.whenCancelled,
        checkCancellation: cancellation.throwIfCancelled,
      );
      cancellation.throwIfCancelled();
      final attachment = await context.storage.registerBytes(
        conversationId: context.conversationId,
        name: '生成图片-${context.toolCallId}.${image.extension}',
        mimeType: image.mimeType,
        bytes: image.bytes,
      );
      return ToolOutcome.success(
        '已生成图片「${attachment.name}」',
        artifacts: [attachment.id],
      );
    } on CancelledFailure {
      return const ToolOutcome.cancelled('图像生成已停止');
    } on Failure catch (error) {
      return ToolOutcome.failure(
        error.userMessage,
        errorCode: 'imageGenerationFailed',
      );
    }
  }
}
