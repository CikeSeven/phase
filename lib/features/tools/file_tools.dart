import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../data/models/attachment.dart';
import '../../../data/models/tool_policy.dart';
import 'tool.dart';

/// 单次读取的默认行数与上限：大文档由模型按行分段读，不一次塞满上下文。
const _defaultReadLines = 300;
const _maxReadLines = 1000;

/// 读取已导入的附件或本会话产物中的文本。
class ReadFileTool implements Tool {
  const ReadFileTool();

  @override
  String get name => 'read_file';

  @override
  String get description =>
      '读取文件文本。reference 可以是附件的文件名或 id，也可以是本会话产物的文件名。'
      '大文件用 offset（起始行，从 0 开始）与 limit（行数）分段读取。';

  @override
  Map<String, dynamic> get inputSchema => const {
    'type': 'object',
    'properties': {
      'reference': {'type': 'string', 'description': '文件名或附件 id'},
      'offset': {'type': 'integer', 'description': '起始行，从 0 开始'},
      'limit': {'type': 'integer', 'description': '读取行数，默认 300，最多 1000'},
    },
    'required': ['reference'],
    'additionalProperties': false,
  };

  @override
  Set<String> get requiredCapabilities => const {'file_read'};

  @override
  ToolPolicy get defaultPolicy => ToolPolicy.allow;

  @override
  String describeAction(Map<String, dynamic> arguments) {
    final reference = arguments['reference'];
    return '读取文件：${reference is String ? reference : '（缺少引用）'}';
  }

  @override
  Future<ToolOutcome> execute(
    Map<String, dynamic> arguments,
    ToolContext context,
    RunCancellation cancellation, {
    ToolProgress? onProgress,
  }) async {
    final args = ToolArguments(arguments, name);
    final reference = args.string('reference');
    final offset = (args.optionalInt('offset') ?? 0).clamp(0, 1 << 31);
    final limit = (args.optionalInt('limit') ?? _defaultReadLines).clamp(
      1,
      _maxReadLines,
    );

    final resolved = _resolve(reference, context);
    if (resolved == null) {
      return ToolOutcome.failure(
        '找不到文件「$reference」。可读的是当前会话的附件与本会话产物：'
        '${_availableNames(context).join('、')}',
        errorCode: 'fileNotFound',
      );
    }
    cancellation.throwIfCancelled();

    final file = File(resolved.path);
    if (!file.existsSync()) {
      return ToolOutcome.failure(
        '文件「$reference」已不存在（可能已被删除）',
        errorCode: 'fileMissing',
      );
    }
    if (file.lengthSync() > _maxBytes) {
      return ToolOutcome.failure(
        '文件超过 ${_maxBytes ~/ 1024}KB，太小无法一次读取；请改用 offset 分段读取',
        errorCode: 'fileTooLarge',
      );
    }
    final String text;
    try {
      text = await file.readAsString();
    } on FileSystemException catch (error) {
      return ToolOutcome.failure(
        '读取失败：${error.message}',
        errorCode: 'fileReadFailed',
      );
    } on FormatException {
      // 二进制内容不进上下文，也不假装读到了文本。
      return ToolOutcome.failure(
        '「$reference」不是文本内容，无法作为文本读取',
        errorCode: 'notText',
      );
    }

    final lines = text.split('\n');
    final slice = (offset >= lines.length
        ? const <String>[]
        : lines.sublist(offset, (offset + limit).clamp(0, lines.length)));
    if (slice.isEmpty) {
      return ToolOutcome.success(
        '「${resolved.name}」从第 $offset 行起没有内容（全文共 ${lines.length} 行）',
      );
    }
    final end = offset + slice.length;
    final truncated = end < lines.length;
    return ToolOutcome.success(
      '文件「${resolved.name}」第 $offset–${end - 1} 行'
      '${truncated ? '（还有 ${lines.length - end} 行未读）' : '（已到结尾）'}：\n'
      '${slice.join('\n')}',
    );
  }

  _ResolvedFile? _resolve(String reference, ToolContext context) {
    // 先看本会话产物，再看附件：产物是模型最近写出的东西。
    final artifact = _artifactFile(reference, context);
    if (artifact != null) return artifact;
    final attachment = context.attachmentBy(reference);
    if (attachment == null) return null;
    return _ResolvedFile(
      name: attachment.name,
      path: attachment.extractedTextPath ?? attachment.localPath,
    );
  }

  static const _maxBytes = 4 * 1024 * 1024;

  List<String> _availableNames(ToolContext context) {
    final names = <String>[
      for (final attachment in context.attachments) attachment.name,
      if (Directory(context.artifactsDirectory).existsSync())
        for (final entity in Directory(context.artifactsDirectory).listSync())
          if (entity is File) p.basename(entity.path),
    ];
    return names.isEmpty ? const ['（当前没有可读文件）'] : names;
  }
}

/// 把文本写成新产物：写入应用私有目录，产物作为附件登记。
class WriteFileTool implements Tool {
  const WriteFileTool();

  /// 单次写入的内容上限，避免一次落一个超大文件。
  static const maxBytes = 2 * 1024 * 1024;

  @override
  String get name => 'write_file';

  @override
  String get description =>
      '把文本写成本会话的产物文件。path 是文件名或相对路径（相对于本会话产物目录），'
      '内容完全由 content 决定；同名文件会被覆盖，覆盖前会向用户确认。';

  @override
  Map<String, dynamic> get inputSchema => const {
    'type': 'object',
    'properties': {
      'path': {'type': 'string', 'description': '文件名或相对路径，如 summary.md'},
      'content': {'type': 'string', 'description': '要写入的完整文本'},
    },
    'required': ['path', 'content'],
    'additionalProperties': false,
  };

  @override
  Set<String> get requiredCapabilities => const {'file_write'};

  @override
  ToolPolicy get defaultPolicy => ToolPolicy.ask;

  @override
  String describeAction(Map<String, dynamic> arguments) {
    final path = arguments['path'];
    final content = arguments['content'];
    final size = content is String ? content.length : 0;
    final exists = arguments['__exists'] == true;
    return '写入文件「${path is String ? path : '（缺少路径）'}」'
        '（$size 字${exists ? '，覆盖已有文件' : '，新文件'}）';
  }

  @override
  Future<ToolOutcome> execute(
    Map<String, dynamic> arguments,
    ToolContext context,
    RunCancellation cancellation, {
    ToolProgress? onProgress,
  }) async {
    final args = ToolArguments(arguments, name);
    final rawPath = args.string('path').trim();
    final content = args.string('content', required: true);
    final bytes = content.length;
    if (bytes > maxBytes) {
      return ToolOutcome.failure(
        '内容过大（$bytes 字，上限 ${maxBytes ~/ 1024}KB）；请分段写入或改用其他方式',
        errorCode: 'contentTooLarge',
      );
    }

    final safeName = _safeRelativePath(rawPath);
    if (safeName == null) {
      return ToolOutcome.failure(
        '路径不合法：只能写入本会话产物目录内的相对路径（收到「$rawPath」）',
        errorCode: 'invalidPath',
      );
    }
    final target = File(p.join(context.artifactsDirectory, safeName));
    cancellation.throwIfCancelled();

    try {
      await target.parent.create(recursive: true);
      cancellation.throwIfCancelled();
      final directory = Directory(context.artifactsDirectory).absolute.path;
      if (!p.isWithin(directory, target.absolute.path)) {
        return ToolOutcome.failure('路径越出会话产物目录', errorCode: 'invalidPath');
      }
      final existed = target.existsSync();
      await target.writeAsString(content, flush: true);
      // 产物按 artifact 类型附件登记，结果引用它（design 第六部分 §6.3）：
      // 卡片、导出与 list_files 都靠这条引用查到写出的文件。
      final artifact = await _registerArtifact(context, target, safeName);
      return ToolOutcome.success(
        '已${existed ? '覆盖' : '创建'}「$safeName」（$bytes 字）',
        artifacts: [artifact.id],
      );
    } on FileSystemException catch (error) {
      return ToolOutcome.failure(
        '写入失败：${error.message}',
        errorCode: 'fileWriteFailed',
      );
    }
  }

  /// 登记写入的文件；同一路径已有附件时复用，避免同名产物出现多条记录。
  Future<Attachment> _registerArtifact(
    ToolContext context,
    File target,
    String name,
  ) async {
    final normalized = p.normalize(target.path);
    for (final attachment in context.attachments) {
      if (p.normalize(attachment.localPath) == normalized) return attachment;
    }
    return context.storage.registerArtifact(
      conversationId: context.conversationId,
      path: target.path,
      name: name,
    );
  }

  /// 归一化相对路径；绝对路径与上跳路径一律拒绝，不做"就近落盘"的猜测。
  String? _safeRelativePath(String raw) {
    if (raw.isEmpty) return null;
    if (p.isAbsolute(raw)) return null;
    final normalized = p.normalize(raw);
    if (normalized.startsWith('..') || normalized.contains('../')) return null;
    if (normalized == '.' || normalized.endsWith('/')) return null;
    return normalized;
  }
}

/// 列出当前会话可读的文件：已导入的附件与本会话产物。
class ListFilesTool implements Tool {
  const ListFilesTool();

  @override
  String get name => 'list_files';

  @override
  String get description => '列出当前会话可读的文件（附件与本会话产物）。';

  @override
  Map<String, dynamic> get inputSchema => const {
    'type': 'object',
    'properties': {},
    'additionalProperties': false,
  };

  @override
  Set<String> get requiredCapabilities => const {'file_read'};

  @override
  ToolPolicy get defaultPolicy => ToolPolicy.allow;

  @override
  String describeAction(Map<String, dynamic> arguments) => '列出当前会话的文件';

  @override
  Future<ToolOutcome> execute(
    Map<String, dynamic> arguments,
    ToolContext context,
    RunCancellation cancellation, {
    ToolProgress? onProgress,
  }) async {
    cancellation.throwIfCancelled();
    final lines = <String>[];
    for (final attachment in context.attachments) {
      lines.add(
        '- ${attachment.name}（${_kindLabel(attachment)}，'
        '${(attachment.size / 1024).toStringAsFixed(1)}KB，'
        '引用：${attachment.name}）',
      );
    }
    final artifacts = Directory(context.artifactsDirectory);
    if (artifacts.existsSync()) {
      for (final entity in artifacts.listSync()) {
        if (entity is! File) continue;
        final size = (entity.lengthSync() / 1024).toStringAsFixed(1);
        lines.add(
          '- ${p.basename(entity.path)}（产物，${size}KB，引用：'
          '${p.basename(entity.path)}）',
        );
      }
    }
    if (lines.isEmpty) {
      return ToolOutcome.success('当前会话还没有可读文件。');
    }
    return ToolOutcome.success('当前会话的文件：\n${lines.join('\n')}');
  }

  String _kindLabel(Attachment attachment) => switch (attachment.kind) {
    AttachmentKind.image => '图片',
    AttachmentKind.pdf => 'PDF',
    AttachmentKind.docx => 'DOCX',
    AttachmentKind.artifact => '产物',
    AttachmentKind.text => '文本',
  };
}

/// 解析出的可读文件。
class _ResolvedFile {
  const _ResolvedFile({required this.name, required this.path});

  final String name;
  final String path;
}

_ResolvedFile? _artifactFile(String reference, ToolContext context) {
  final directory = Directory(context.artifactsDirectory);
  if (!directory.existsSync()) return null;
  final normalized = p.normalize(reference);
  if (normalized.startsWith('..') || p.isAbsolute(normalized)) return null;
  final file = File(p.join(directory.path, normalized));
  if (!file.existsSync()) return null;
  return _ResolvedFile(name: normalized, path: file.path);
}
