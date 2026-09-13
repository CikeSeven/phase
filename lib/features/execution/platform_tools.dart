import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;

import '../../../core/error/failure.dart';
import '../../../data/models/execution_scope.dart';
import '../../../data/models/tool_call_record.dart';
import '../../../data/models/tool_policy.dart';
import '../chat/document_extractor.dart';
import '../tools/tool.dart';
import 'channel_driver.dart';
import 'execution_api.g.dart';

String executionScopePrompt(
  ExecutionScope scope, {
  bool applicationOperations = false,
  bool toolExecution = false,
}) {
  // 不把黑名单包名放进模型提示词，应用信息只通过过滤后的 list_apps 提供。
  return '${!toolExecution ? '' : '\n工具响应和错误由你处理，不要求用户核验普通操作的结果或填写状态。需要判断执行效果时，用正常的只读工具获取当前界面或文件。失败或取消不等于外部效果已撤销，不要无条件重发有副作用动作；无法继续时明确说明错误。用户授权与密码等必要输入仍由用户提供。'}'
      '${scope.fileUris.isEmpty ? '' : '\n本次授权文件句柄：${jsonEncode(scope.fileUris)}。'}'
      '${!applicationOperations ? '' : '\n应用操作统一受应用名单限制。先用 list_apps 查询可用应用，再用 open_app(packageName) 打开；所有应用工具必须传入同一目标的真实 packageName。不要猜包名绕过名单。UI 操作必须使用该应用最新快照的 snapshotId 和 nodeId；每次动作后使用新观察。系统接受动作不等于任务成功，最终回答依据观察。支付、密码、验证码需用户手动处理。'}';
}

ToolOutcome platformOutcome(ExecutionResult result) {
  final details = {...result.result};
  final reason = details['reason'];
  final message = switch (reason) {
    'manualIntervention' => '界面包含密码、验证码或支付操作，请手动处理',
    'locked' => '设备已锁定，请解锁后重新发起任务',
    'targetChanged' => '目标窗口或控件已改变，请重新观察',
    'unavailable' => '当前没有可操作的目标窗口',
    _ => null,
  };
  if (message != null) {
    details['reasonCode'] = reason;
    details['reason'] = message;
  }
  final content = jsonEncode(details);
  return switch (result.status) {
    ExecutionStatus.succeeded => ToolOutcome.success(content),
    ExecutionStatus.cancelled => ToolOutcome.cancelled(content),
    ExecutionStatus.failed => ToolOutcome.failure(
      result.result.isEmpty
          ? ExecutionFailure(
              ExecutionFailureCode.values.byName(
                (result.error ?? ChannelError.executionFailed).name,
              ),
            ).userMessage
          : content,
      errorCode: result.error?.name ?? 'executionFailed',
    ),
  };
}

/// 同一组文件工具根据显式 URI 路由；私有附件不绕行 Kotlin。
class ScopedFileTool extends Tool {
  const ScopedFileTool(this.local, this.driver);
  final Tool local;
  final ChannelDriver Function() driver;
  @override
  String get name => local.name;
  @override
  String get description =>
      '${local.description} 外部文件使用用户授权的 content:// URI。'
      'list_files 的 directory 为授权目录；write_file 的 directory 为目录 URI，path 为单个文件名。'
      '默认只新建；覆盖须 overwrite=true 且 expectedSha256 与之前读取的文件校验值一致。';
  @override
  Map<String, dynamic> get inputSchema => {
    ...local.inputSchema,
    'properties': {
      ...Map<String, dynamic>.from(local.inputSchema['properties'] as Map),
      if (name != 'read_file')
        'directory': {
          'type': 'string',
          'description': '本次授权目录的 content:// URI',
        },
      if (name == 'write_file') ...{
        'overwrite': {'type': 'boolean', 'description': '是否覆盖已有文件，默认 false'},
        'expectedSha256': {
          'type': 'string',
          'description': '覆盖目标之前读取到的 SHA-256',
        },
      },
    },
  };
  @override
  Set<String> get requiredCapabilities => local.requiredCapabilities;
  @override
  ToolPolicy get defaultPolicy => local.defaultPolicy;
  @override
  bool usesPlatform(Map<String, dynamic> arguments) => name == 'read_file'
      ? arguments['reference'] is String &&
            (arguments['reference'] as String).startsWith('content://')
      : arguments.containsKey('directory');
  @override
  String describeAction(Map<String, dynamic> arguments) =>
      !usesPlatform(arguments)
      ? local.describeAction(arguments)
      : name == 'write_file'
      ? '${arguments['overwrite'] == true ? '覆盖' : '新建'}外部文件 ${arguments['path']}，目录 ${arguments['directory']}'
      : '读取授权${name == 'list_files' ? '目录' : '文件'}：${arguments['directory'] ?? arguments['reference']}';

  @override
  Future<ToolOutcome> execute(
    Map<String, dynamic> arguments,
    ToolContext context,
    RunCancellation cancellation, {
    ToolProgress? onProgress,
  }) async {
    if (!usesPlatform(arguments)) {
      return local.execute(
        {
          for (final entry in arguments.entries)
            if (!['overwrite', 'expectedSha256'].contains(entry.key))
              entry.key: entry.value,
        },
        context,
        cancellation,
        onProgress: onProgress,
      );
    }
    if (name == 'write_file' &&
        utf8.encode(arguments['content'] as String).length > 128 * 1024) {
      return const ToolOutcome.failure(
        '外部文件单次写入上限为 128KB',
        errorCode: 'invalidArguments',
      );
    }
    final result = await driver().execute(
      ExecutionRequest(
        runId: context.runId,
        toolCallId: context.toolCallId,
        action: switch (name) {
          'read_file' => ExecutionAction.readFile,
          'write_file' => ExecutionAction.writeFile,
          _ => ExecutionAction.listFiles,
        },
        arguments: arguments,
        target: ExecutionTarget(
          uri: (arguments['directory'] ?? arguments['reference']) as String?,
        ),
        timeoutMs: 30000,
      ),
      cancellation,
      onProgress: (event) => onProgress?.call(event.payload),
    );
    if (result.status != ExecutionStatus.succeeded) {
      return platformOutcome(result);
    }
    final ids = <String>[];
    final details = {...result.result};
    for (final artifact in result.artifacts) {
      final source = artifact.localPath;
      if (source == null) throw const OperationFailure('文件内容没有返回，读取失败');
      final target = File(
        p.join(
          context.artifactsDirectory,
          '${context.toolCallId}-${p.basename(artifact.name)}',
        ),
      );
      try {
        await target.parent.create(recursive: true);
        await File(source).copy(target.path);
        String? extractedPath;
        String? extractionError;
        if (name == 'read_file') {
          try {
            final extension = p
                .extension(artifact.name)
                .replaceFirst('.', '')
                .toLowerCase();
            final text = await Isolate.run(() async {
              if (DocumentExtractor.supports(extension)) {
                return (await const DocumentExtractor().extract(
                  path: target.path,
                  extension: extension,
                )).text;
              }
              return await target.readAsString();
            });
            if (DocumentExtractor.supports(extension)) {
              extractedPath = '${target.path}.extracted.txt';
              await File(extractedPath).writeAsString(text);
            }
            final lines = text.split('\n');
            final offset = ((arguments['offset'] as num?)?.toInt() ?? 0).clamp(
              0,
              lines.length,
            );
            final limit = ((arguments['limit'] as num?)?.toInt() ?? 300).clamp(
              1,
              1000,
            );
            final end = (offset + limit).clamp(0, lines.length);
            final slice = lines.sublist(offset, end).join('\n');
            details['text'] = slice.length > 16000
                ? slice.substring(0, 16000)
                : slice;
            details['truncated'] = end < lines.length || slice.length > 16000;
            details['totalLines'] = lines.length;
          } on DocumentExtractionException {
            extractionError = '无法抽取文字，可能是扫描件或损坏文档';
          } on FormatException {
            extractionError = '不是可解码文本，已保留私有文件副本';
          }
        }
        if (extractionError != null) {
          details['extractionError'] = extractionError;
        }
        final attachment = await context.storage.registerArtifact(
          conversationId: context.conversationId,
          path: target.path,
          name: artifact.name,
          sha256: artifact.sha256,
          extractedTextPath: extractedPath,
          extractionError: extractionError,
        );
        ids.add(attachment.id);
      } on FileSystemException catch (error) {
        throw StorageFailure('文件副本保存失败', cause: error);
      } finally {
        // 仅清理原生返回的临时副本，绝不删除 content URI 指向的外部文件。
        try {
          await File(source).delete();
        } on FileSystemException {
          /* 缓存清理由系统兜底。 */
        }
      }
    }
    return ToolOutcome.success(jsonEncode(details), artifacts: ids);
  }
}

class ApplicationTool extends Tool {
  const ApplicationTool(this.action, this.driver);
  final ExecutionAction action;
  final ChannelDriver Function() driver;

  String _targetLabel(Map<String, dynamic> arguments) {
    final snapshot = driver().latestSnapshot;
    if (snapshot == null ||
        snapshot['id'] != arguments['snapshotId'] ||
        snapshot['packageName'] != arguments['packageName']) {
      return '未定位节点 ${arguments['nodeId']}';
    }
    final nodes = (snapshot['nodes'] as List? ?? []).whereType<Map>();
    final node = nodes
        .where((node) => node['id'] == arguments['nodeId'])
        .firstOrNull;
    final description =
        node?['description'] ??
        node?['text'] ??
        node?['viewId'] ??
        node?['className'] ??
        '控件';
    final label = description.toString();
    return '${snapshot['packageName']} · ${label.length > 120 ? label.substring(0, 120) : label} [${arguments['nodeId']}]';
  }

  @override
  ExecutionChannel get channel => action == ExecutionAction.listApps
      ? ExecutionChannel.app
      : ExecutionChannel.accessibility;
  @override
  String get policyKey => applicationOperationsPolicyKey;
  @override
  bool usesPlatform(Map<String, dynamic> arguments) => true;
  @override
  String get name => switch (action) {
    ExecutionAction.listApps => 'list_apps',
    ExecutionAction.openApp => 'open_app',
    ExecutionAction.inspectUi => 'inspect_ui',
    ExecutionAction.clickNode => 'click_node',
    ExecutionAction.scroll => 'scroll',
    ExecutionAction.inputText => 'input_text',
    _ => throw StateError('Not a UI action'),
  };
  @override
  String get description => switch (action) {
    ExecutionAction.listApps =>
      '获取名单允许的已安装应用：名称、包名、系统属性、版本、安装时间、安装包大小及可否打开。可搜索、排序和分页；不会返回被禁止的应用。',
    ExecutionAction.openApp =>
      '打开名单允许的 packageName 对应应用，返回其界面快照。不会自动改名单或打开其它包名。',
    ExecutionAction.inspectUi =>
      '读取指定 packageName 的当前可见界面并返回有界快照；目标须已在前台且通过名单校验。',
    _ =>
      '对 packageName 执行 $name；必须通过名单校验，并使用该应用最新的 snapshotId 和 nodeId。不猜坐标、不自动重试；返回动作回调和操作后观察。',
  };
  @override
  Set<String> get requiredCapabilities => action == ExecutionAction.listApps
      ? const {'applications'}
      : const {'applications', 'accessibility'};
  @override
  ToolPolicy get defaultPolicy => ToolPolicy.ask;
  @override
  Map<String, dynamic> get inputSchema => {
    'type': 'object',
    'additionalProperties': false,
    'properties': {
      if (action != ExecutionAction.listApps)
        'packageName': {'type': 'string', 'description': '名单允许的目标应用包名'},
      if (action == ExecutionAction.listApps) ...{
        'query': {'type': 'string', 'description': '按名称或包名搜索'},
        'sort': {
          'type': 'string',
          'enum': ['name', 'installedAt', 'size'],
        },
        'offset': {'type': 'integer', 'minimum': 0},
        'limit': {'type': 'integer', 'minimum': 1, 'maximum': 50},
      },
      if (_nodeAction) ...{
        'snapshotId': {'type': 'string'},
        'nodeId': {'type': 'string'},
      },
      if (action == ExecutionAction.scroll)
        'direction': {
          'type': 'string',
          'enum': ['forward', 'backward'],
        },
      if (action == ExecutionAction.inputText) 'text': {'type': 'string'},
    },
    'required': [
      if (action != ExecutionAction.listApps) 'packageName',
      if (_nodeAction) ...['snapshotId', 'nodeId'],
      if (action == ExecutionAction.scroll) 'direction',
      if (action == ExecutionAction.inputText) 'text',
    ],
  };
  bool get _nodeAction => const {
    ExecutionAction.clickNode,
    ExecutionAction.scroll,
    ExecutionAction.inputText,
  }.contains(action);
  @override
  String describeAction(Map<String, dynamic> arguments) => switch (action) {
    ExecutionAction.listApps => '获取名单允许的应用信息并发送给所选模型',
    ExecutionAction.openApp => '打开应用：${arguments['packageName']}',
    ExecutionAction.inspectUi => '读取 ${arguments['packageName']} 的可见界面并发送给所选模型',
    ExecutionAction.inputText =>
      '在 ${_targetLabel(arguments)} 输入：${arguments['text']}',
    ExecutionAction.scroll =>
      '滚动 ${_targetLabel(arguments)}：${arguments['direction']}',
    _ => '点击 ${_targetLabel(arguments)}',
  };
  @override
  Future<ToolOutcome> execute(
    Map<String, dynamic> arguments,
    ToolContext context,
    RunCancellation cancellation, {
    ToolProgress? onProgress,
  }) async {
    return platformOutcome(
      await driver().execute(
        ExecutionRequest(
          runId: context.runId,
          toolCallId: context.toolCallId,
          action: action,
          arguments: arguments,
          target: ExecutionTarget(
            packageName: arguments['packageName'] as String?,
            snapshotId: arguments['snapshotId'] as String?,
            nodeId: arguments['nodeId'] as String?,
          ),
          timeoutMs: 10000,
        ),
        cancellation,
        onProgress: (event) => onProgress?.call(event.payload),
      ),
    );
  }
}
