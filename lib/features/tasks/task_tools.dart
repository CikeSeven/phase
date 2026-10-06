import 'dart:convert';

import '../../../core/error/failure.dart';
import '../../../data/models/tool_policy.dart';
import '../tools/tool.dart';
import 'command_task_controller.dart';

enum TaskToolAction { list, output, stop }

class TaskTool extends Tool {
  const TaskTool(this.action, {this.controller});
  final TaskToolAction action;
  final CommandTaskController? controller;

  @override
  String get name => switch (action) {
    TaskToolAction.list => 'task_list',
    TaskToolAction.output => 'task_output',
    TaskToolAction.stop => 'task_stop',
  };
  @override
  String get description => switch (action) {
    TaskToolAction.list => '列出当前会话的后台命令任务，返回任务 ID、状态和退出信息。支持分页。',
    TaskToolAction.output =>
      '读取当前会话后台任务的 stdout、stderr 与状态。'
          '设置 waitMs 可挂起阻塞当前会话等待任务完成；'
          '后台任务在后台结束后拉起会话时，使用本工具读取任务输出和终态。'
          '默认读取最新尾部；分别传 stdoutOffset、stderrOffset 从绝对字节位置续读。'
          '日志有界保留，过旧的读取位置返回 truncated。waitMs 只控制本次等待，不终止任务。',
    TaskToolAction.stop => '停止当前会话的后台命令任务及其子进程，等待退出回执。已结束的任务返回已有状态。',
  };
  @override
  String get promptSnippet => switch (action) {
    TaskToolAction.list => '查看当前会话的后台任务',
    TaskToolAction.output => '等待或读取后台任务结果',
    TaskToolAction.stop => '停止后台任务',
  };
  @override
  List<String> get promptGuidelines => switch (action) {
    TaskToolAction.list => const [
      '后台任务属于当前会话，跨本轮模型运行保留；默认结束后自动通知并唤醒 AI。应用进程重启后运行中的任务变为 interrupted，不自动重跑。',
      '记住 shell 返回的 taskId；开始新轮次或忘记 ID 时用 task_list 查看。需要结果时使用 task_output，不重复启动同一服务。',
      '停止不再需要的任务用 task_stop；等待日志可设置 waitMs，等待结束不代表进程被停止。',
    ],
    TaskToolAction.output => const [
      '后台任务支持两种模式：若需阻塞当前会话等待任务执行结束，可传入 waitMs（毫秒）；若需后台静默执行，则结束本轮回复，任务完成后系统会自动拉起并唤醒会话调用本工具。',
    ],
    TaskToolAction.stop => const [],
  };
  @override
  Map<String, dynamic> get inputSchema => {
    'type': 'object',
    'properties': switch (action) {
      TaskToolAction.list => {
        'activeOnly': {'type': 'boolean', 'description': '仅返回活跃任务，默认 false'},
        'offset': {'type': 'integer', 'minimum': 0},
        'limit': {'type': 'integer', 'minimum': 1, 'maximum': 50},
      },
      TaskToolAction.output => {
        'taskId': {'type': 'string', 'description': '后台任务 ID'},
        'stdoutOffset': {'type': 'integer', 'minimum': 0},
        'stderrOffset': {'type': 'integer', 'minimum': 0},
        'maxBytes': {
          'type': 'integer',
          'minimum': 4,
          'maximum': 16384,
          'description': '每路输出的原始字节上限，默认 8192',
        },
        'waitMs': {
          'type': 'integer',
          'minimum': 0,
          'maximum': 30000,
          'description': '挂起阻塞会话等待后台任务完成的最长毫秒数，默认 0',
        },
      },
      TaskToolAction.stop => {
        'taskId': {'type': 'string'},
      },
    },
    if (action != TaskToolAction.list) 'required': ['taskId'],
    'additionalProperties': false,
  };
  @override
  Set<String> get requiredCapabilities => const {};
  @override
  ToolPolicy get defaultPolicy => ToolPolicy.allow;
  @override
  String describeAction(Map<String, dynamic> arguments) {
    if (action == TaskToolAction.output) {
      final isWaiting = (arguments['waitMs'] as int? ?? 0) > 0;
      return isWaiting
          ? '正在等待后台任务 ${arguments['taskId'] ?? ''}'.trim()
          : '后台任务完成 ${arguments['taskId'] ?? ''}'.trim();
    }
    return '$promptSnippet ${arguments['taskId'] ?? ''}'.trim();
  }

  @override
  String? validateArguments(Map<String, dynamic> arguments) {
    for (final key in [
      'offset',
      'limit',
      'stdoutOffset',
      'stderrOffset',
      'maxBytes',
      'waitMs',
    ]) {
      final value = arguments[key];
      if (value != null && (value is! int || value < 0)) return '$key 必须是非负整数';
    }
    if (arguments['activeOnly'] != null && arguments['activeOnly'] is! bool) {
      return 'activeOnly 必须是布尔值';
    }
    if ((arguments['limit'] as int? ?? 20) < 1 ||
        (arguments['limit'] as int? ?? 20) > 50 ||
        (arguments['maxBytes'] as int? ?? 8192) < 4 ||
        (arguments['maxBytes'] as int? ?? 8192) > 16384 ||
        (arguments['waitMs'] as int? ?? 0) > 30000) {
      return '条目数、日志大小或等待时间超出允许范围';
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
    final tasks = controller;
    if (tasks == null) throw const OperationFailure('任务管理不可用');
    await tasks.initialize();
    cancellation.throwIfCancelled();
    switch (action) {
      case TaskToolAction.list:
        final values = tasks.tasks
            .where(
              (task) =>
                  task.conversationId == context.conversationId &&
                  (arguments['activeOnly'] != true || task.status.active),
            )
            .toList();
        final offset = (arguments['offset'] as int? ?? 0).clamp(
          0,
          values.length,
        );
        final end = (offset + (arguments['limit'] as int? ?? 20)).clamp(
          offset,
          values.length,
        );
        return ToolOutcome.success(
          jsonEncode({
            'tasks': [
              for (final task in values.sublist(offset, end)) task.summary(),
            ],
            'total': values.length,
            if (end < values.length) 'nextOffset': end,
          }),
        );
      case TaskToolAction.output:
        final id = arguments['taskId'] as String;
        await tasks.wait(
          id,
          Duration(milliseconds: arguments['waitMs'] as int? ?? 0),
          conversationId: context.conversationId,
          cancellation: cancellation,
        );
        final output = await tasks.output(
          id,
          conversationId: context.conversationId,
          stdoutOffset: arguments['stdoutOffset'] as int?,
          stderrOffset: arguments['stderrOffset'] as int?,
          maxBytes: arguments['maxBytes'] as int? ?? 8192,
        );
        if (!output.task.status.active) {
          await tasks.collectCompletion(
            id,
            conversationId: context.conversationId,
          );
        }
        return ToolOutcome.success(jsonEncode(output.toJson()));
      case TaskToolAction.stop:
        final task = await tasks.stop(
          arguments['taskId'] as String,
          conversationId: context.conversationId,
          modelInitiated: true,
        );
        return ToolOutcome.success(jsonEncode(task.summary()));
    }
  }
}
