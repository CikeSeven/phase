import 'dart:convert';

import '../../../core/error/failure.dart';
import '../../../data/models/workspace.dart';
import '../../../data/models/tool_policy.dart';
import '../../../data/models/tool_call_record.dart';
import '../tools/tool.dart';
import 'workspace_files.dart';

class WorkspaceTransferTool extends Tool {
  const WorkspaceTransferTool(this.workspace, this.files);
  final WorkspaceSnapshot workspace;
  final WorkspaceFiles files;
  @override
  ExecutionChannel get channel => ExecutionChannel.termux;
  @override
  String get name => 'workspace_transfer';
  @override
  String get policyKey => commandExecutionPolicyKey;
  @override
  ToolPolicy get defaultPolicy => ToolPolicy.ask;
  @override
  Set<String> get requiredCapabilities => const {'termux_command'};
  @override
  bool usesPlatform(Map<String, dynamic> arguments) => false;
  @override
  String get description =>
      '在本会话 Ubuntu 与 Termux 工作区的相同相对路径之间显式复制文件或递归目录。'
      '当前环境 ${workspace.primaryEnvironment.label}；to_other 导出到另一环境，from_other 从另一环境导入。'
      '同名覆盖，目录合并，不删除额外文件，不跟随链接。单文件 64 MiB、合计 256 MiB、1000 项。失败可能已提交部分文件，不自动重试。';
  @override
  Map<String, dynamic> get inputSchema => const {
    'type': 'object',
    'properties': {
      'path': {'type': 'string', 'description': '当前工作区相对路径，两端使用相同路径'},
      'direction': {
        'type': 'string',
        'enum': ['to_other', 'from_other'],
      },
    },
    'required': ['path', 'direction'],
    'additionalProperties': false,
  };
  @override
  String? validateArguments(Map<String, dynamic> arguments) {
    final path = arguments['path'] as String? ?? '';
    return path.isEmpty ||
            path.startsWith('/') ||
            path.contains('\\') ||
            path.contains('\u0000') ||
            path.split('/').contains('..')
        ? '请使用工作区内的相对路径'
        : null;
  }

  @override
  String describeAction(Map<String, dynamic> arguments) =>
      '${arguments['direction'] == 'to_other' ? workspace.primaryEnvironment.label : workspace.primaryEnvironment.other.label} → '
      '${arguments['direction'] == 'to_other' ? workspace.primaryEnvironment.other.label : workspace.primaryEnvironment.label}\n'
      '${arguments['path']}\n同名文件覆盖，目录合并，目标额外文件保留';
  @override
  Future<ToolOutcome> execute(
    Map<String, dynamic> arguments,
    ToolContext context,
    RunCancellation cancellation, {
    ToolProgress? onProgress,
  }) async {
    try {
      await files.transfer(
        workspace,
        arguments['path'] as String,
        arguments['direction'] == 'to_other',
        cancellation,
        ownerId: context.runId,
      );
      return ToolOutcome.success(
        jsonEncode({
          'path': arguments['path'],
          'direction': arguments['direction'],
          'environment': workspace.primaryEnvironment.name,
          'copied': true,
        }),
      );
    } on StorageFailure {
      rethrow;
    } on WorkspaceFailure catch (error) {
      return ToolOutcome(
        ok: false,
        cancelled: error.cancelled,
        errorCode: error.code,
        content: jsonEncode({
          'path': arguments['path'],
          'copied': false,
          'error': error.userMessage,
          'completedPaths': error.completedPaths,
          'cancelled': error.cancelled,
          'knownEffects': '已提交的文件保留，不代表整批回滚',
        }),
      );
    } on Failure catch (error) {
      return ToolOutcome.failure(
        '${error.userMessage}；已完成的复制保留',
        errorCode: 'transferFailed',
      );
    }
  }
}
