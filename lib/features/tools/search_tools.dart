import 'dart:convert';

import '../../../core/error/failure.dart';
import '../../../data/models/tool_call_record.dart';
import '../../../data/models/tool_policy.dart';
import '../../../data/models/tool_source.dart';
import '../../../data/models/workspace.dart';
import '../workspace/workspace_search.dart';
import 'file_tools.dart';
import 'tool.dart';

class WorkspaceSearchTool extends Tool {
  const WorkspaceSearchTool({
    required this.findFiles,
    this.workspace,
    this.search,
  });
  final bool findFiles;
  final WorkspaceSnapshot? workspace;
  final WorkspaceSearch? search;
  @override
  String get name => findFiles ? 'find' : 'grep';
  @override
  ExecutionChannel get channel => ExecutionChannel.app;
  @override
  bool usesPlatform(Map<String, dynamic> arguments) => false;
  @override
  String get description => findFiles
      ? '按 glob 模式查找当前环境中的文件，遵守 .gitignore，包含隐藏文件但排除 .git。'
            '返回相对于搜索目录的路径。默认最多 1000 项或 50 KiB，以先达到的上限为准。'
            '截断时增大 limit 或缩小范围；需要当前环境已安装 ripgrep（rg）。'
      : '按正则或字面文本搜索当前环境中的文件内容，遵守 .gitignore，包含隐藏文件但排除 .git。'
            '返回相对于搜索目录的文件路径、行号和匹配行，支持上下文。'
            '默认最多 100 处匹配或 50 KiB，以先达到的上限为准；长行截断到 500 字符。'
            '需要当前环境已安装 ripgrep（rg）。';
  @override
  String get promptSnippet =>
      findFiles ? '按 glob 查找文件（遵守 .gitignore）' : '搜索文件内容（遵守 .gitignore）';
  @override
  List<String> get promptGuidelines => findFiles
      ? const ['按文件名或路径查找使用 find，列目录使用 list_files；搜索结果路径相对于传入的搜索目录。']
      : const ['搜索文件内容优先使用 grep，而不是通过 shell 拼接搜索命令；需要完整匹配行时使用 read_file。'];
  @override
  Map<String, dynamic> get inputSchema => {
    'type': 'object',
    'properties': {
      'pattern': {
        'type': 'string',
        'minLength': 0,
        'description': findFiles
            ? '文件 glob，例如 *.ts、**/*.json、src/**/*.dart'
            : '正则表达式或字面搜索文本',
      },
      'path': {
        'type': 'string',
        'description': '$fileToolPathDescription 默认 .；grep 可指定文件或目录，find 指定目录',
      },
      if (!findFiles) ...{
        'glob': {
          'type': 'string',
          'description': '文件 glob 过滤，例如 *.dart 或 **/*.spec.ts',
        },
        'ignoreCase': {'type': 'boolean', 'description': '忽略大小写，默认 false'},
        'literal': {'type': 'boolean', 'description': '按字面文本匹配而非正则，默认 false'},
        'context': {
          'type': 'integer',
          'minimum': 0,
          'description': '每处匹配前后附加行数，默认 0',
        },
      },
      'limit': {
        'type': 'integer',
        'minimum': 1,
        'description': '最多${findFiles ? '返回文件数，默认 1000' : '匹配行数，默认 100'}',
      },
    },
    'required': ['pattern'],
    'additionalProperties': false,
  };
  @override
  ToolSource get source => ToolSource(
    kind: ToolSourceKind.builtIn,
    id: 'builtIn',
    originalName: name,
    effectClass: ToolEffectClass.readOnly,
    definitionRevision: definitionDigest([name, description, inputSchema]),
  );
  @override
  Set<String> get requiredCapabilities => const {'file_read', 'linux_process'};
  @override
  ToolPolicy get defaultPolicy => ToolPolicy.allow;
  @override
  String describeAction(Map<String, dynamic> arguments) =>
      '${findFiles ? '查找文件' : '搜索内容'}：${arguments['pattern']}\n目录：${arguments['path'] ?? workspace?.executionRoot ?? '.'}';
  @override
  String? validateArguments(Map<String, dynamic> arguments) {
    for (final key in ['pattern', 'path', 'glob']) {
      final value = arguments[key];
      if (value != null &&
          (value is! String ||
              value.contains('\u0000') ||
              utf8.encode(value).length > 120 * 1024)) {
        return '$key 不是有效的搜索参数';
      }
    }
    for (final key in ['limit', 'context']) {
      final value = arguments[key];
      if (value != null &&
          (value is! int || value < (key == 'limit' ? 1 : 0))) {
        return '$key 必须是${key == 'limit' ? '正整数' : '非负整数'}';
      }
    }
    for (final key in ['ignoreCase', 'literal']) {
      if (arguments.containsKey(key) && arguments[key] is! bool) {
        return '$key 必须是布尔值';
      }
    }
    return null;
  }

  @override
  Future<ToolOutcome> execute(
    Map<String, dynamic> arguments,
    ToolContext context,
    RunCancellation cancellation, {
    ToolProgress? onProgress,
  }) async {
    if (search == null) {
      return const ToolOutcome.failure(
        '当前搜索环境未就绪',
        errorCode: 'environmentMissing',
      );
    }
    try {
      return ToolOutcome.success(
        await search!.run(
          WorkspaceSearchRequest(
            findFiles: findFiles,
            pattern: arguments['pattern'] as String,
            path: arguments['path'] as String? ?? '.',
            glob: arguments['glob'] as String?,
            ignoreCase: arguments['ignoreCase'] as bool? ?? false,
            literal: arguments['literal'] as bool? ?? false,
            contextLines: arguments['context'] as int? ?? 0,
            limit: arguments['limit'] as int? ?? (findFiles ? 1000 : 100),
          ),
          context,
          cancellation,
        ),
      );
    } on WorkspaceFailure catch (error) {
      return ToolOutcome.failure(error.userMessage, errorCode: error.code);
    } on CommandChannelFailure catch (error) {
      return ToolOutcome.failure(error.userMessage, errorCode: error.code);
    }
  }
}
