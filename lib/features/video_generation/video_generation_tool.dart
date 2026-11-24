import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/error/failure.dart';
import '../../data/models/tool_policy.dart';
import '../../data/models/tool_source.dart';
import '../../data/repositories/media_generation_repository.dart';
import '../../data/repositories/video_generation_repository.dart';
import '../tools/tool.dart';

class VideoGenerationTool extends Tool {
  const VideoGenerationTool(this.repository, this.binding);

  static const toolName = 'generate_video';
  static const _maxPromptLength = 16000;
  final VideoGenerationRepository repository;
  final MediaGenerationBinding binding;

  @override
  String get name => toolName;

  @override
  String get description => '调用已配置的视频模型，根据提示词生成视频并返回 MP4 附件。';

  @override
  String get promptSnippet => '用户要求生成视频时，描述画面、动作和镜头，并按字段说明填写视频参数。';

  @override
  Set<String> get requiredCapabilities => const {'video_generation'};

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
  Map<String, dynamic> get inputSchema {
    final fields = binding.video!.parameters;
    return {
      'type': 'object',
      'additionalProperties': false,
      'required': [
        'prompt',
        for (final entry in fields.entries)
          if (entry.value.required) entry.key,
      ],
      'properties': {
        'prompt': {'type': 'string', 'description': '描述视频主体、场景、动作、镜头和声音。'},
        for (final MapEntry(:key, :value) in fields.entries) key: value.schema,
      },
    };
  }

  @override
  String? validateArguments(Map<String, dynamic> arguments) {
    final prompt = arguments['prompt'];
    if (prompt is! String ||
        prompt.trim().isEmpty ||
        prompt.length > _maxPromptLength) {
      return '请输入 1–16,000 字符的视频提示词';
    }
    final fields = binding.video!.parameters;
    if (arguments.keys.any(
      (key) => key != 'prompt' && !fields.containsKey(key),
    )) {
      return '视频参数包含未配置的字段';
    }
    for (final MapEntry(:key, :value) in fields.entries) {
      if (arguments.containsKey(key)) {
        if (!value.accepts(arguments[key])) return '视频参数 $key 的类型或取值无效';
      } else if (value.required) {
        return '请填写视频参数 $key';
      }
    }
    return null;
  }

  @override
  String describeAction(Map<String, dynamic> args) => [
    binding.target.modelId,
    for (final MapEntry(:key, :value) in args.entries)
      if (key != 'prompt') '$key = $value',
    args['prompt'] ?? '',
  ].join('\n');

  @override
  Future<ToolOutcome> execute(
    Map<String, dynamic> args,
    ToolContext context,
    RunCancellation cancellation, {
    ToolProgress? onProgress,
  }) async {
    final error = validateArguments(args);
    if (error != null) {
      return ToolOutcome.failure(error, errorCode: 'invalidArguments');
    }
    await context.checkPermission?.call();
    cancellation.throwIfCancelled();
    Directory? staging;
    try {
      final directory = Directory(context.artifactsDirectory);
      final parent = await directory.parent.create(recursive: true);
      staging = await parent.createTemp('.video-');
      final file = File(p.join(staging.path, 'video.mp4'));
      await repository.generate(
        binding: binding,
        prompt: (args['prompt'] as String).trim(),
        parameters: {
          for (final MapEntry(:key, :value) in args.entries)
            if (key != 'prompt') key: value,
        },
        destination: file,
        cancellation: cancellation.whenCancelled,
        checkCancellation: cancellation.throwIfCancelled,
        onProgress: onProgress,
      );
      cancellation.throwIfCancelled();
      final name = '生成视频-${context.toolCallId}.mp4';
      await directory.create(recursive: true);
      final destination = await file.rename(p.join(directory.path, name));
      final attachment = await context.storage.registerArtifact(
        conversationId: context.conversationId,
        path: destination.path,
        name: name,
      );
      return ToolOutcome.success(
        '已生成视频「${attachment.name}」',
        artifacts: [attachment.id],
      );
    } on CancelledFailure {
      return const ToolOutcome.cancelled('视频等待已停止');
    } on Failure catch (error) {
      return ToolOutcome.failure(
        error.userMessage,
        errorCode: 'videoGenerationFailed',
      );
    } on FileSystemException {
      return const ToolOutcome.failure(
        '无法保存视频，请检查可用存储空间',
        errorCode: 'videoStorageFailed',
      );
    } finally {
      try {
        await staging?.delete(recursive: true);
      } on FileSystemException {
        // The staging directory is outside the conversation's artifact list.
      }
    }
  }
}
