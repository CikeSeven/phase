import '../../../data/models/workspace.dart';
import '../workspace/workspace_file_access.dart';

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/error/failure.dart';
import '../../../data/models/tool_policy.dart';
import 'file_text.dart';
import 'tool.dart';

const _pathDescription = '相对于本会话工作区根目录的路径。';

class ReadFileTool extends Tool {
  const ReadFileTool();
  @override
  String get name => 'read_file';
  @override
  String get description =>
      '读取 UTF-8 文本或附件已抽取的文本。'
      '最多返回 2000 行或 16 KiB 完整行，按返回的 nextOffset/offset 继续读取。';
  @override
  Map<String, dynamic> get inputSchema => const {
    'type': 'object',
    'properties': {
      'path': {
        'type': 'string',
        'description': '$_pathDescription 附件可用 attachment:<ID> 或唯一文件名。',
      },
      'offset': {'type': 'integer', 'minimum': 1, 'description': '起始行，默认 1'},
      'limit': {
        'type': 'integer',
        'minimum': 1,
        'description': '最多读取行数，默认 2000',
      },
    },
    'required': ['path'],
    'additionalProperties': false,
  };
  @override
  Set<String> get requiredCapabilities => const {'file_read'};
  @override
  ToolPolicy get defaultPolicy => ToolPolicy.allow;
  @override
  String? validateArguments(Map<String, dynamic> arguments) =>
      validateFileRead(arguments);
  @override
  String describeAction(Map<String, dynamic> arguments) =>
      '读取文件：${arguments['path']}';
  @override
  Future<ToolOutcome> execute(
    Map<String, dynamic> arguments,
    ToolContext context,
    RunCancellation cancellation, {
    ToolProgress? onProgress,
  }) => _fileOperation(() async {
    final path = ToolArguments(arguments, name).string('path');
    cancellation.throwIfCancelled();
    final relative = path.startsWith('attachment:')
        ? null
        : _relative(path, context);
    final access = _access(context);
    final page =
        relative != null &&
            (await access.stat(relative, cancellation)).type == 'file'
        ? await access.readPage(relative, arguments, cancellation)
        : await readFilePage(
            _attachmentFile(path, context),
            arguments,
            cancellation,
          );
    return ToolOutcome.success(page.render());
  });
}

class WriteFileTool extends Tool {
  const WriteFileTool();
  static const maxBytes = maxFileWriteBytes;
  @override
  String get name => 'write_file';
  @override
  String get description =>
      '写入 UTF-8 文件，不存在则创建，存在则完整覆盖；自动创建父目录。局部修改用 edit_file。';
  @override
  Map<String, dynamic> get inputSchema => const {
    'type': 'object',
    'properties': {
      'path': {'type': 'string', 'description': _pathDescription},
      'content': {
        'type': 'string',
        'minLength': 0,
        'description': '完整内容；空字符串创建空文件或清空文件',
      },
    },
    'required': ['path', 'content'],
    'additionalProperties': false,
  };
  @override
  Set<String> get requiredCapabilities => const {'file_write'};
  @override
  ToolPolicy get defaultPolicy => ToolPolicy.ask;
  @override
  String describeAction(Map<String, dynamic> arguments) =>
      '写入文件「${arguments['path']}」（存在则完整覆盖）';
  @override
  Future<ToolOutcome> execute(
    Map<String, dynamic> arguments,
    ToolContext context,
    RunCancellation cancellation, {
    ToolProgress? onProgress,
  }) => _fileOperation(() async {
    final path = ToolArguments(arguments, name).string('path');
    final content = arguments['content'];
    if (content is! String) throw ToolArgumentException(name, 'content 必须是字符串');
    return _write(path, content, context, cancellation);
  });
}

class EditFileTool extends Tool {
  const EditFileTool();
  @override
  String get name => 'edit_file';
  @override
  String get description =>
      '用精确文本替换编辑文件，支持多处修改一次提交；全部匹配成功才写入。'
      '先读取文件，保留原文空格；oldText 在保证唯一匹配的前提下尽量短。';
  @override
  Map<String, dynamic> get inputSchema => const {
    'type': 'object',
    'properties': {
      'path': {'type': 'string', 'description': _pathDescription},
      'edits': {
        'type': 'array',
        'minItems': 1,
        'description': '每处替换均匹配原文件，各区域不得重叠',
        'items': {
          'type': 'object',
          'properties': {
            'oldText': {
              'type': 'string',
              'minLength': 1,
              'description': '原文件中唯一的原文',
            },
            'newText': {'type': 'string', 'description': '替换文本，空字符串表示删除'},
          },
          'required': ['oldText', 'newText'],
          'additionalProperties': false,
        },
      },
    },
    'required': ['path', 'edits'],
    'additionalProperties': false,
  };
  @override
  Set<String> get requiredCapabilities => const {'file_read', 'file_write'};
  @override
  ToolPolicy get defaultPolicy => ToolPolicy.ask;
  @override
  String? validateArguments(Map<String, dynamic> arguments) =>
      validateFileEdits(arguments);
  @override
  String describeAction(Map<String, dynamic> arguments) =>
      '编辑文件：${arguments['path']}';
  @override
  Future<ToolOutcome> execute(
    Map<String, dynamic> arguments,
    ToolContext context,
    RunCancellation cancellation, {
    ToolProgress? onProgress,
  }) => _fileOperation(() async {
    final path = ToolArguments(arguments, name).string('path');
    cancellation.throwIfCancelled();
    final access = _access(context);
    final relative = _relative(path, context);
    final original = await access.readText(relative, cancellation);
    if (original.contains('\u0000')) {
      throw const FileToolException('notText', '不能编辑二进制文件');
    }
    final content = applyFileEdits(original, arguments);
    cancellation.throwIfCancelled();
    if (content == original) {
      return const ToolOutcome.success('替换内容与原文相同，文件未改变');
    }
    final outcome = await _write(
      path,
      content,
      context,
      cancellation,
      original: original,
    );
    return ToolOutcome.success(
      '已替换 ${(arguments['edits'] as List).length} 处文本。${outcome.content}',
      artifacts: outcome.artifacts,
    );
  });
}

class ListFilesTool extends Tool {
  const ListFilesTool();
  @override
  String get name => 'list_files';
  @override
  String get description => '列出目录的直接子项，返回可直接用于文件工具的路径；支持分页。';
  @override
  Map<String, dynamic> get inputSchema => const {
    'type': 'object',
    'properties': {
      'path': {'type': 'string', 'description': '工作区内的目录路径，默认 .（工作区根目录）'},
      'offset': {'type': 'integer', 'minimum': 0, 'description': '跳过的条目数，默认 0'},
      'limit': {
        'type': 'integer',
        'minimum': 1,
        'maximum': 200,
        'description': '返回条目数，默认 100',
      },
    },
    'additionalProperties': false,
  };
  @override
  Set<String> get requiredCapabilities => const {'file_read'};
  @override
  ToolPolicy get defaultPolicy => ToolPolicy.allow;
  @override
  String? validateArguments(Map<String, dynamic> arguments) {
    final offset = arguments['offset'];
    final limit = arguments['limit'];
    if (offset != null && (offset is! int || offset < 0)) {
      return 'offset 必须是非负整数';
    }
    if (limit != null && (limit is! int || limit < 1 || limit > 200)) {
      return 'limit 必须是 1–200 的整数';
    }
    return null;
  }

  @override
  String describeAction(Map<String, dynamic> arguments) =>
      '列出目录：${arguments['path'] ?? '.'}';
  @override
  Future<ToolOutcome> execute(
    Map<String, dynamic> arguments,
    ToolContext context,
    RunCancellation cancellation, {
    ToolProgress? onProgress,
  }) => _fileOperation(() async {
    final path = arguments['path'] as String? ?? '.';
    cancellation.throwIfCancelled();
    final relative = _relative(path, context, directory: true);
    final entries = <Map<String, Object?>>[
      for (final entry in await _access(context).list(relative, cancellation))
        {'path': entry.path, 'type': entry.type},
    ];
    if (relative == '.') {
      for (final attachment in context.attachments) {
        if (p.isWithin(
          p.absolute(context.workspaceDirectory),
          p.absolute(attachment.localPath),
        )) {
          continue;
        }
        entries.add({
          'path': 'attachment:${attachment.id}',
          'name': attachment.name,
          'type': 'attachment',
        });
      }
    }
    entries.sort(
      (a, b) => (a['path'] as String).compareTo(b['path'] as String),
    );
    final offset = arguments['offset'] as int? ?? 0;
    final limit = arguments['limit'] as int? ?? 100;
    final selected = <Map<String, Object?>>[];
    var bytes = 0;
    for (final entry in entries.skip(offset).take(limit)) {
      final size = utf8.encode(jsonEncode(entry)).length;
      if (bytes + size > maxFileReadBytes && selected.isNotEmpty) break;
      selected.add(entry);
      bytes += size;
    }
    final end = offset + selected.length;
    return ToolOutcome.success(
      jsonEncode({
        'path': relative,
        'files': selected,
        'total': entries.length,
        if (end < entries.length) 'nextOffset': end,
      }),
    );
  });
}

WorkspaceFileAccess _access(ToolContext context) {
  if (context.fileAccess != null) return context.fileAccess!;
  if (context.workspaceDirectory.isEmpty) {
    throw const FileToolException('workspaceUnavailable', '本次运行的会话工作区不可用');
  }
  return LocalWorkspaceFileAccess(
    WorkspaceSnapshot(
      id: context.conversationId,
      name: '会话工作区',
      rootPath: context.workspaceDirectory,
      environmentRoot: null,
      environmentRevision: null,
    ),
    Directory(p.join(context.artifactsDirectory, '.workspace-staging')),
  );
}

String _relative(String path, ToolContext context, {bool directory = false}) {
  final ubuntu =
      context.fileAccess?.binding.primaryEnvironment !=
      PrimaryEnvironment.termux;
  final relative =
      ubuntu && (path == '/workspace' || path.startsWith('/workspace/'))
      ? (path == '/workspace' ? '.' : path.substring(11))
      : path;
  if (relative.startsWith('attachment:')) {
    throw const FileToolException('readOnlyAttachment', '附件只读；请写到新的文件路径');
  }
  if (relative.isEmpty ||
      relative.contains('\u0000') ||
      relative.contains('\\') ||
      p.posix.isAbsolute(relative) ||
      p.posix.split(relative).contains('..') ||
      (!directory &&
          (p.posix.normalize(relative) == '.' || relative.endsWith('/')))) {
    throw const FileToolException('invalidPath', '路径不合法：请使用工作区内的相对路径');
  }
  return p.posix.normalize(relative);
}

File _attachmentFile(String path, ToolContext context) {
  final matches = path.startsWith('attachment:')
      ? context.attachments.where((a) => a.id == path.substring(11))
      : context.attachments.where((a) => a.name == path || a.id == path);
  if (matches.length > 1) {
    throw const FileToolException(
      'ambiguousPath',
      '附件名不唯一，请使用 attachment:<ID>',
    );
  }
  final attachment = matches.firstOrNull;
  if (attachment == null) {
    throw FileToolException('fileNotFound', '找不到文件「$path」，请用 list_files 查看路径');
  }
  return File(attachment.extractedTextPath ?? attachment.localPath);
}

Future<ToolOutcome> _write(
  String path,
  String content,
  ToolContext context,
  RunCancellation cancellation, {
  String? original,
}) async {
  await _access(
    context,
  ).write(_relative(path, context), content, cancellation, original: original);
  return ToolOutcome.success(
    '已写入「$path」（${utf8.encode(content).length} bytes）',
  );
}

Future<ToolOutcome> _fileOperation(
  Future<ToolOutcome> Function() action,
) async {
  try {
    return await action();
  } on FileToolException catch (error) {
    return ToolOutcome.failure(error.message, errorCode: error.code);
  } on WorkspaceFailure catch (error) {
    return ToolOutcome(
      ok: false,
      cancelled: error.cancelled,
      content: error.userMessage,
      errorCode: error.code,
    );
  } on CommandChannelFailure catch (error) {
    return ToolOutcome.failure(error.userMessage, errorCode: error.code);
  } on FileSystemException catch (error) {
    return ToolOutcome.failure(
      '文件操作失败：${error.message}',
      errorCode: 'fileOperationFailed',
    );
  } on FormatException {
    return const ToolOutcome.failure('文件不是有效的 UTF-8 文本', errorCode: 'notText');
  }
}
