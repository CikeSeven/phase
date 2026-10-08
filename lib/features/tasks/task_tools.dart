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
    TaskToolAction.list => '列出当前会话的后台命令任务及状态，支持分页。',
    TaskToolAction.output =>
      '读取当前会话后台任务的 stdout、stderr 与状态，默认返回最新尾部。'
          '日志有界保留，过旧的读取位置返回 truncated 和 oldestOffset。',
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
      '后台任务跨轮次运行，默认完成后通知；仅在必须等待结果时设置 waitMs。',
      '使用 shell 或 task_list 返回的 taskId 查询或停止任务；停止不再需要的任务用 task_stop。',
    ],
    TaskToolAction.output || TaskToolAction.stop => const [],
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
        'taskId': {
          'type': 'string',
          'description': 'shell 或 task_list 返回的任务句柄',
        },
        'stdoutOffset': {
          'type': 'integer',
          'minimum': 0,
          'description': 'stdout 的绝对字节位置；用上次 stdout.nextOffset 续读，省略时读取尾部',
        },
        'stderrOffset': {
          'type': 'integer',
          'minimum': 0,
          'description': 'stderr 的绝对字节位置；用上次 stderr.nextOffset 续读，省略时读取尾部',
        },
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
          'description': '本次等待任务结束的最长毫秒数，默认 0；等待超时不停止任务',
        },
      },
      TaskToolAction.stop => {
        'taskId': {
          'type': 'string',
          'description': 'shell 或 task_list 返回的任务句柄',
        },
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
