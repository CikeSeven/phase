import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;

import '../../../core/error/failure.dart';
import '../../../core/utils/logger.dart';
import '../../../data/models/execution_scope.dart';
import '../../../data/models/tool_call_record.dart';
import '../../../data/models/tool_policy.dart';
import '../chat/document_extractor.dart';
import '../tools/tool.dart';
import '../tools/file_text.dart';
import '../tools/file_tools.dart';
import 'channel_driver.dart';
import 'execution_api.g.dart';

String executionScopePrompt(
  ExecutionScope scope, {
  bool applicationOperations = false,
  bool toolExecution = false,
}) {
  // 不把黑名单包名放进模型提示词，应用信息只通过过滤后的 list_apps 提供。
  return '${!toolExecution ? '' : '\n工具响应和错误由你处理；需要判断效果时读取当前界面或文件，不要求用户核验普通操作或填写状态。失败或取消不代表外部效果已撤销，不要无条件重发有副作用动作；无法继续时说明错误。必要的授权和敏感输入由用户提供。'}'
      '${scope.fileUris.isEmpty ? '' : '\n本次授权文件句柄：${jsonEncode(scope.fileUris)}。'}'
      '${!applicationOperations ? '' : '\n应用操作受应用名单限制；打开应用前用 list_apps 查询真实包名，再调用 open_app。依据最新界面选择操作，动作后根据返回的观察或重新读取界面判断效果。系统接受动作不等于任务完成。支付、密码、验证码由用户手动处理。'}';
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
      '${local.description} 外部文件的 path 使用授权的 content:// URI。'
      '${name == 'write_file' ? '外部单次写入上限 128 KiB。' : ''}';
  @override
  Map<String, dynamic> get inputSchema => {
    ...local.inputSchema,
    'properties': {
      ...Map<String, dynamic>.from(local.inputSchema['properties'] as Map),
      if (name == 'write_file')
        'directory': {
          'type': 'string',
          'description': '新建或按名称写入外部文件时使用的授权目录 URI；指定时 path 为相对路径',
        },
    },
  };
  @override
  Set<String> get requiredCapabilities => local.requiredCapabilities;
  @override
  ToolPolicy get defaultPolicy => local.defaultPolicy;
  @override
  String? validateArguments(Map<String, dynamic> arguments) {
    final directory = arguments['directory'];
    if (directory != null &&
        (directory is! String || !directory.startsWith('content://'))) {
      return 'directory 必须是授权目录的 content:// URI';
    }
    if (directory != null &&
        (arguments['path'] as String).startsWith('content://')) {
      return '指定 directory 时 path 应为相对路径';
    }
    return local.validateArguments(arguments);
  }

  @override
  bool usesPlatform(Map<String, dynamic> arguments) =>
      (arguments['path'] is String &&
          (arguments['path'] as String).startsWith('content://')) ||
      arguments.containsKey('directory');
  @override
  String describeAction(Map<String, dynamic> arguments) =>
      '${local.describeAction(arguments)}${arguments['directory'] == null ? '' : '，目录 ${arguments['directory']}'}';

  @override
  Future<ToolOutcome> execute(
    Map<String, dynamic> arguments,
    ToolContext context,
    RunCancellation cancellation, {
    ToolProgress? onProgress,
  }) async {
    if (!usesPlatform(arguments)) {
      return local.execute(
        arguments,
        context,
        cancellation,
        onProgress: onProgress,
      );
    }
    if (name == 'edit_file') {
      return _editExternal(arguments, context, cancellation, onProgress);
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
          uri: (arguments['directory'] ?? arguments['path']) as String?,
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
      if (source == null) {
        return _unavailableArtifact(
          details,
          artifact.name,
          artifacts: ids,
          reason: '文件内容没有返回，未能读取「${artifact.name}」。',
        );
      }
      // 原文件名只用于展示。加上调用前缀后可能超过文件系统的单段字节上限。
      final target = File(
        p.join(
          context.artifactsDirectory,
          '${context.toolCallId}-${ids.length}',
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
            if (DocumentExtractor.supports(extension)) {
              final text = await Isolate.run(
                () async => (await const DocumentExtractor().extract(
                  path: target.path,
                  extension: extension,
                )).text,
              );
              extractedPath = '${target.path}.extracted.txt';
              await File(extractedPath).writeAsString(text);
            }
            final page = await readFilePage(
              File(extractedPath ?? target.path),
              arguments,
              cancellation,
            );
            details.addAll(page.toJson());
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
        if (extractionError != null) {
          return ToolOutcome(
            ok: false,
            content: jsonEncode(details),
            artifacts: ids,
            errorCode: 'notText',
          );
        }
      } on ToolCancelled {
        await _discardCopy(target);
        rethrow;
      } on FileToolException catch (error) {
        await _discardCopy(target);
        return ToolOutcome.failure(error.message, errorCode: error.code);
      } on FileSystemException catch (error) {
        AppLogger.warning('授权文件处理失败 (io=${error.osError?.errorCode})');
        await _discardCopy(target);
        return _unavailableArtifact(details, artifact.name, artifacts: ids);
      } on OperationFailure {
        await _discardCopy(target);
        return _unavailableArtifact(details, artifact.name, artifacts: ids);
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

  Future<ToolOutcome> _editExternal(
    Map<String, dynamic> arguments,
    ToolContext context,
    RunCancellation cancellation,
    ToolProgress? onProgress,
  ) async {
    // 两个原生阶段使用不同派发 ID；写入阶段仍归属当前工具调用，禁止底层重放。
    final uri = arguments['path'] as String;
    final read = await driver().execute(
      ExecutionRequest(
        runId: context.runId,
        toolCallId: '${context.toolCallId}:read',
        action: ExecutionAction.readFile,
        arguments: {'path': uri},
        target: ExecutionTarget(uri: uri),
        timeoutMs: 30000,
      ),
      cancellation,
    );
    if (read.status != ExecutionStatus.succeeded) return platformOutcome(read);
    try {
      final source = read.artifacts.singleOrNull;
      if (source?.localPath == null || source?.sha256 == null) {
        return const ToolOutcome.failure(
          '未获得完整文件与校验值，未执行编辑',
          errorCode: 'fileReadFailed',
        );
      }
      cancellation.throwIfCancelled();
      final file = File(source!.localPath!);
      if (await file.length() > 128 * 1024) {
        return const ToolOutcome.failure(
          '外部文件编辑上限为 128 KiB',
          errorCode: 'contentTooLarge',
        );
      }
      final original = await readEditableText(file);
      if (original.contains('\u0000')) {
        return const ToolOutcome.failure('不能编辑二进制文件', errorCode: 'notText');
      }
      final edited = applyFileEdits(original, arguments);
      if (original == edited) {
        return const ToolOutcome.success('替换内容与原文相同，文件未改变');
      }
      cancellation.throwIfCancelled();
      return await ScopedFileTool(const WriteFileTool(), driver).execute(
        {'path': uri, 'content': edited, 'expectedSha256': source.sha256},
        context,
        cancellation,
        onProgress: onProgress,
      );
    } on FileToolException catch (error) {
      return ToolOutcome.failure(error.message, errorCode: error.code);
    } on FormatException {
      return const ToolOutcome.failure(
        '文件不是有效的 UTF-8 文本，未执行编辑',
        errorCode: 'notText',
      );
    } on FileSystemException {
      return const ToolOutcome.failure(
        '无法读取文件副本，未执行编辑',
        errorCode: 'fileReadFailed',
      );
    } finally {
      for (final artifact in read.artifacts) {
        if (artifact.localPath case final path?) {
          try {
            await File(path).delete();
          } on FileSystemException {
            /* 临时缓存由系统清理。 */
          }
        }
      }
    }
  }

  ToolOutcome _unavailableArtifact(
    Map<String, Object?> details,
    String fileName, {
    required List<String> artifacts,
    String? reason,
  }) {
    if (name == 'write_file') {
      // 原生已校验写入成功；预览副本失败不能把已完成的写入说成失败。
      return ToolOutcome.success(
        jsonEncode({
          ...details,
          'name': fileName,
          'warning': '文件「$fileName」已写入，但暂时无法预览。',
        }),
        artifacts: artifacts,
      );
    }
    return ToolOutcome.failure(
      jsonEncode({
        ...details,
        'name': fileName,
        'reason':
            reason ??
            (details['text'] is String
                ? '已读取「$fileName」，但未能保存附件。'
                : '未能读取「$fileName」的内容。'),
      }),
      errorCode: 'fileReadFailed',
    );
  }

  Future<void> _discardCopy(File target) async {
    for (final file in [File('${target.path}.extracted.txt'), target]) {
      try {
        if (await file.exists()) await file.delete();
      } on FileSystemException {
        AppLogger.warning('未完成的文件副本清理失败');
      }
    }
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
      '查询名单允许的已安装应用，返回名称、包名、系统属性、版本、安装时间、安装包大小及可否打开；支持搜索、排序和分页。',
    ExecutionAction.openApp =>
      '打开 packageName 对应应用，返回文字控件树 snapshot，不含截图图片。'
          '需要查看画面或控件树信息不足时，调用可用的 capture_screen 读取当前前台截图。',
    ExecutionAction.inspectUi =>
      '读取指定 packageName 的可见文字控件树 snapshot，不含截图图片；目标须已在前台。'
          '需要查看画面或控件树信息不足时，调用可用的 capture_screen。',
    _ =>
      '对 packageName 执行 $name，使用该应用最新控件快照的 snapshotId 和 nodeId；'
          '返回动作回调和操作后的文字控件树，不含截图图片。需要查看画面时调用可用的 capture_screen。',
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
