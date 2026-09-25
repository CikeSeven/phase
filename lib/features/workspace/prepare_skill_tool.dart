import 'dart:convert';

import '../../../core/error/failure.dart';
import '../../../data/models/tool_policy.dart';
import '../../../data/models/workspace.dart';
import '../skills/read_skill_tool.dart';
import '../tools/tool.dart';
import 'workspace_files.dart';

class PrepareSkillTool extends Tool {
  PrepareSkillTool(this.reader, this.workspace, this.files);
  final ReadSkillTool reader;
  final WorkspaceSnapshot workspace;
  final WorkspaceFiles files;
  @override
  String get name => 'prepare_skill';
  @override
  String get description =>
      '将已启用 Skill 的固定版本资源复制到工作区，返回 executionPath 供 shell 使用。';
  @override
  Map<String, dynamic> get inputSchema => {
    'type': 'object',
    'properties': {
      'skillId': {
        'type': 'string',
        'enum': reader.skills.map((s) => s.id).toList(),
      },
    },
    'required': ['skillId'],
    'additionalProperties': false,
  };
  @override
  ToolPolicy get defaultPolicy => ToolPolicy.ask;
  @override
  Set<String> get requiredCapabilities => const {'file_write'};
  @override
  String describeAction(Map<String, dynamic> arguments) =>
      '将 Skill ${arguments['skillId']} 的固定版本复制到工作区「${workspace.name}」';
  Future<ToolPolicy> currentPolicy() => reader.currentPolicy();
  @override
  Future<ToolOutcome> execute(
    Map<String, dynamic> arguments,
    ToolContext context,
    RunCancellation cancellation, {
    ToolProgress? onProgress,
  }) async {
    final skill = reader.skills
        .where((s) => s.id == arguments['skillId'])
        .firstOrNull;
    if (skill == null) {
      return const ToolOutcome.failure(
        'Skill 不在本次运行范围内',
        errorCode: 'skillDenied',
      );
    }
    try {
      final path = await files.prepareSkill(
        workspace,
        skill,
        cancellation,
        ownerId: context.runId,
        checkPermission: () => reader.checkAccess(skill, cancellation),
      );
      return ToolOutcome.success(
        jsonEncode({
          'skillId': skill.id,
          'revision': skill.revision,
          'executionPath': path,
          'executed': false,
          'instruction': '资源是工作副本，脚本需使用 shell 显式调用解释器；缺失依赖不会自动安装',
        }),
      );
    } on StorageFailure {
      rethrow;
    } on WorkspaceFailure catch (error) {
      return ToolOutcome(
        ok: false,
        cancelled: error.cancelled,
        content: error.userMessage,
        errorCode: 'skillCopyFailed',
      );
    } on Failure catch (error) {
      return ToolOutcome.failure(
        error.userMessage,
        errorCode: 'skillCopyFailed',
      );
    }
  }
}
