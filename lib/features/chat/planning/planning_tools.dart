import '../../memory/memory_tools.dart';
import '../../../../core/error/failure.dart';
import '../../../../data/models/tool_policy.dart';
import '../../../../data/repositories/plan_repository.dart';
import '../../tools/tool.dart';
import '../../tools/file_tools.dart';
import '../../execution/platform_tools.dart';
import '../../skills/read_skill_tool.dart';

/// 宿主类型白名单，不信任服务器的 effect/readOnly 标记或工具名。
bool allowedInPlan(Tool tool) =>
    (tool is MemoryTool && !tool.write) ||
    tool is SystemInfoTool ||
    tool is ReadFileTool ||
    tool is ListFilesTool ||
    tool is ReadSkillTool ||
    tool is SubmitPlanTool ||
    (tool is ScopedFileTool &&
        (tool.name == 'read_file' || tool.name == 'list_files'));

const planModePrompt =
    '\n当前为计划模式：只允许宿主开放的只读工具，不执行外部动作。'
    '使用 submit_plan 提交标题和步骤后结束本轮，等待用户编辑、批准或取消。'
    '正文不是计划批准，批准也不授予工具执行权限。';

class SubmitPlanTool extends Tool {
  const SubmitPlanTool(this.repository);
  final PlanRepository repository;
  @override
  String get name => 'submit_plan';
  @override
  String get description => '提交待用户批准的计划，仅保存计划，不执行步骤。再次提交创建新修订。';
  @override
  Map<String, dynamic> get inputSchema => const {
    'type': 'object',
    'properties': {
      'title': {'type': 'string', 'maxLength': 200},
      'steps': {
        'type': 'array',
        'minItems': 1,
        'maxItems': 30,
        'items': {'type': 'string', 'maxLength': 2000},
      },
    },
    'required': ['title', 'steps'],
    'additionalProperties': false,
  };
  @override
  Set<String> get requiredCapabilities => const {};
  @override
  ToolPolicy get defaultPolicy => ToolPolicy.allow;
  @override
  String describeAction(Map<String, dynamic> arguments) => '提交计划';
  @override
  String? validateArguments(Map<String, dynamic> arguments) {
    final steps = arguments['steps'];
    if (arguments['title'] is! String ||
        steps is! List ||
        steps.any((s) => s is! String)) {
      return '计划格式无效';
    }
    try {
      PlanRepository.validate(
        arguments['title'] as String,
        steps.cast<String>(),
      );
    } on OperationFailure catch (e) {
      return e.userMessage;
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
    cancellation.throwIfCancelled();
    final plan = await repository.submit(
      runId: context.runId,
      toolCallId: context.toolCallId,
      title: arguments['title'] as String,
      steps: (arguments['steps'] as List).cast<String>(),
    );
    return ToolOutcome.success(
      '计划 ${plan.id} 修订 ${plan.revision} 已保存，等待用户批准。尚未执行任何计划步骤。',
    );
  }
}
