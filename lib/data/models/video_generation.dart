import 'dart:convert';

import '../../core/error/failure.dart';

enum VideoGenerationProtocol {
  seedance('火山方舟 / BytePlus', 'contents/generations/tasks'),
  openRouter('OpenRouter', 'videos'),
  compatible('OpenAI 兼容网关', 'videos');

  const VideoGenerationProtocol(this.label, this.endpoint);

  final String label;
  final String endpoint;

  static VideoGenerationProtocol forBaseUrl(String url) {
    final base = Uri.tryParse(url);
    final host = base?.host ?? '';
    if (host == 'openrouter.ai') return openRouter;
    if (host.endsWith('.volces.com') ||
        host.endsWith('.bytepluses.com') ||
        (base?.pathSegments.contains('v3') ?? false)) {
      return seedance;
    }
    return compatible;
  }

  Map<String, VideoParameter> get parameters => switch (this) {
    seedance => const {
      'duration': VideoParameter('integer', '时长（秒）。取值依所选模型而定。'),
      'ratio': VideoParameter('string', '画面宽高比，如 16:9、9:16，或 adaptive。'),
      'resolution': VideoParameter('string', '画面分辨率，如 720p 或 1080p。'),
      'generate_audio': VideoParameter('boolean', '是否生成音频。'),
    },
    openRouter => const {
      'duration': VideoParameter('integer', '时长（秒）。取值依所选模型而定。'),
      'aspect_ratio': VideoParameter('string', '画面宽高比，如 16:9 或 9:16。'),
      'resolution': VideoParameter('string', '画面分辨率，如 720p 或 1080p。'),
      'generate_audio': VideoParameter('boolean', '是否生成音频。'),
    },
    compatible => const {
      'seconds': VideoParameter('integer', '时长（秒）。取值依所选模型而定。', required: true),
      'size': VideoParameter('string', '视频的宽度x高度，如 1280x720。'),
    },
  };
}

class VideoParameter {
  const VideoParameter(
    this.type,
    this.description, {
    this.required = false,
    this.allowed,
  });

  final String type;
  final String description;
  final bool required;
  final List<Object?>? allowed;

  bool accepts(Object? value) =>
      _matches(value, type) && (allowed?.contains(value) ?? true);

  static bool _matches(Object? value, String type) => switch (type) {
    'string' => value is String && value.length <= 2048,
    'integer' => value is int,
    'number' => value is num && value.isFinite,
    'boolean' => value is bool,
    _ => false,
  };

  Map<String, Object?> get schema => {
    'type': type,
    'description': description,
    'enum': ?allowed,
  };

  Map<String, Object?> toJson() => {...schema, if (required) 'required': true};

  static Map<String, VideoParameter> parseFields(Object? value) {
    const invalid = OperationFailure(
      '自定义字段须为 JSON 对象，每个字段填写 type 和 description',
    );
    if (value is! Map<String, dynamic> || value.length > 16) throw invalid;
    const reserved = {
      'model',
      'prompt',
      'content',
      'callback_url',
      'callback_secret',
      'webhook_url',
    };
    final namePattern = RegExp(r'^[A-Za-z_][A-Za-z0-9_]{0,63}$');
    final fields = <String, VideoParameter>{};
    for (final MapEntry(:key, :value) in value.entries) {
      if (!namePattern.hasMatch(key) || reserved.contains(key)) {
        throw OperationFailure('字段名 $key 不适用于自定义视频参数');
      }
      if (value is! Map<String, dynamic> ||
          value.keys.any(
            (key) => !const {
              'type',
              'description',
              'required',
              'enum',
            }.contains(key),
          ) ||
          value['type'] is! String ||
          !const {
            'string',
            'integer',
            'number',
            'boolean',
          }.contains(value['type']) ||
          value['description'] is! String ||
          (value['description'] as String).trim().isEmpty ||
          (value['description'] as String).length > 400 ||
          (value.containsKey('required') && value['required'] is! bool)) {
        throw invalid;
      }
      final type = value['type'] as String;
      final choices = value['enum'];
      if (value.containsKey('enum') &&
          (choices is! List ||
              choices.isEmpty ||
              choices.length > 30 ||
              choices.any((choice) => !_matches(choice, type)) ||
              choices.toSet().length != choices.length)) {
        throw OperationFailure('字段 $key 的 enum 须包含互不重复且与类型一致的值');
      }
      fields[key] = VideoParameter(
        type,
        (value['description'] as String).trim(),
        required: value['required'] == true,
        allowed: choices is List ? List<Object?>.unmodifiable(choices) : null,
      );
    }
    return Map.unmodifiable(fields);
  }
}

class VideoGenerationOptions {
  const VideoGenerationOptions(
    this.protocol, {
    this.preset,
    this.custom = const {},
  });

  final VideoGenerationProtocol protocol;
  final Map<String, VideoParameter>? preset;
  final Map<String, VideoParameter> custom;

  Map<String, VideoParameter> get parameters => {
    ...(preset ?? protocol.parameters),
    ...custom,
  };

  Map<String, Object?> toJson() => {
    'protocol': protocol.name,
    if (preset case final fields?)
      'preset': {
        for (final entry in fields.entries) entry.key: entry.value.toJson(),
      },
    'custom': {
      for (final MapEntry(:key, :value) in custom.entries) key: value.toJson(),
    },
  };

  factory VideoGenerationOptions.fromJson(Map<String, dynamic> value) =>
      VideoGenerationOptions(
        VideoGenerationProtocol.values.byName(value['protocol'] as String),
        preset: value.containsKey('preset')
            ? VideoParameter.parseFields(value['preset'])
            : null,
        custom: VideoParameter.parseFields(
          value['custom'] ?? <String, dynamic>{},
        ),
      );

  static Map<String, VideoParameter> parseCustomText(String text) {
    if (text.trim().isEmpty) return const {};
    if (text.length > 16000) throw const OperationFailure('自定义字段内容超过长度上限');
    try {
      return VideoParameter.parseFields(jsonDecode(text));
    } on FormatException {
      throw const OperationFailure('自定义字段格式有误，请输入有效的 JSON');
    }
  }
}

class VideoCatalogModel {
  const VideoCatalogModel(this.id, this.label, {this.preset});

  final String id;
  final String label;
  final Map<String, VideoParameter>? preset;

  static final _videoId = RegExp(
    r'seedance|\b(?:veo|sora|kling|wan|hailuo|vidu|luma)(?:[-_/ .]|\d|$)|(?:^|[-_/])video(?:[-_/]|$)',
    caseSensitive: false,
  );

  static bool advertisesVideo(Object? id) =>
      id is String && _videoId.hasMatch(id);

  static List<VideoCatalogModel> readList(
    Object? data,
    VideoGenerationProtocol protocol,
  ) {
    if (data is! List) throw const OperationFailure('服务商未返回有效的视频模型列表');
    final candidates = <VideoCatalogModel>[];
    final identified = <VideoCatalogModel>[];
    final ids = <String>{};
    for (final item in data.whereType<Map<String, dynamic>>()) {
      final id = item['id'];
      if (id is! String || id.isEmpty || id.length > 256 || !ids.add(id)) {
        continue;
      }
      final label = item['name'];
      final modalities = item['modalities'] ?? item['architecture'];
      final outputs = modalities is Map
          ? modalities['output_modalities']
          : null;
      final isVideo =
          protocol == VideoGenerationProtocol.openRouter ||
          item['domain'] == 'VideoGeneration' ||
          (outputs is List && outputs.contains('video')) ||
          advertisesVideo(id);
      final model = VideoCatalogModel(
        id,
        label is String && label.isNotEmpty ? label : id,
        preset: protocol == VideoGenerationProtocol.openRouter
            ? _routerPreset(item)
            : protocol == VideoGenerationProtocol.seedance && isVideo
            ? protocol.parameters
            : null,
      );
      if (outputs is! List || outputs.isEmpty) candidates.add(model);
      if (isVideo) identified.add(model);
    }
    // 兼容网关的模型列表有时只给 ID，别名仍供用户选择。
    return identified.isNotEmpty ||
            protocol != VideoGenerationProtocol.compatible
        ? identified
        : candidates;
  }

  static Map<String, VideoParameter> _routerPreset(Map<String, dynamic> item) {
    final fields = VideoGenerationProtocol.openRouter.parameters;
    final result = <String, VideoParameter>{};
    for (final (field, key) in const [
      ('duration', 'supported_durations'),
      ('aspect_ratio', 'supported_aspect_ratios'),
      ('resolution', 'supported_resolutions'),
    ]) {
      final supported = item[key];
      final base = fields[field]!;
      if (supported is List && supported.isNotEmpty) {
        final choices = supported.where(base.accepts).toSet().take(30).toList();
        if (choices.isNotEmpty) {
          result[field] = VideoParameter(
            base.type,
            base.description,
            allowed: choices,
          );
        }
      }
    }
    if (item['generate_audio'] == true) {
      result['generate_audio'] = fields['generate_audio']!;
    }
    return result;
  }
}
