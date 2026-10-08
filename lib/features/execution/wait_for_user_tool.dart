import '../../../data/models/tool_call_record.dart';
import '../../../data/models/tool_policy.dart';
import '../tools/tool.dart';

typedef WaitForUser = Future<void> Function(
  ToolContext context,
  String prompt,
  RunCancellation cancellation,
);

/// 显式交还操作权；不用于核验普通动作，也不推断用户已完成操作。
class WaitForUserTool extends Tool {
  const WaitForUserTool([this.wait]);
  final WaitForUser? wait;

  @override
  String get name => 'wait_for_user';
  @override
  String get description => '暂停任务并提示用户操作（如登录、验证码、支付等），用户确认完成后继续。';
  @override
  ExecutionChannel get channel => ExecutionChannel.accessibility;
  @override
  Set<String> get requiredCapabilities => const {'user_interaction'};
  @override
  ToolPolicy get defaultPolicy => ToolPolicy.allow;
  @override
  Map<String, dynamic> get inputSchema => const {
    'type': 'object',
    'properties': {
      'prompt': {'type': 'string', 'minLength': 1, 'maxLength': 500},
    },
    'required': ['prompt'],
    'additionalProperties': false,
  };
  @override
  String? validateArguments(Map<String, dynamic> arguments) {
    final prompt = arguments['prompt'];
    return prompt is! String || prompt.trim().isEmpty || prompt.length > 500
        ? '操作提示须为 1–500 字'
        : null;
  }

  @override
  String describeAction(Map<String, dynamic> arguments) =>
      '等待用户操作：${arguments['prompt']}';
  @override
  Future<ToolOutcome> execute(
    Map<String, dynamic> arguments,
    ToolContext context,
    RunCancellation cancellation, {
    ToolProgress? onProgress,
  }) async {
    cancellation.throwIfCancelled();
    final handler = wait;
    if (handler == null) {
      return const ToolOutcome.failure(
        '用户操作等待未绑定到当前运行',
        errorCode: 'unavailable',
      );
    }
    await handler(context, arguments['prompt'] as String, cancellation);
    cancellation.throwIfCancelled();
    return const ToolOutcome.success(
      '用户已点击继续，操作权已交还。请重新观察当前界面再决定下一步；'
      '这不表示之前的操作一定成功，旧窗口、节点与截图不再作为动作依据。',
    );
  }
}
