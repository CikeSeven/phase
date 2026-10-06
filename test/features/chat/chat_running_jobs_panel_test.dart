import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/theme/app_theme.dart';
import 'package:phase/data/models/command_task.dart';
import 'package:phase/data/models/workspace.dart';
import 'package:phase/features/chat/chat_running_jobs_panel.dart';
import 'package:phase/features/tasks/command_task_controller.dart';

class _FakeCommandTaskController extends CommandTaskController {
  _FakeCommandTaskController(this._initialTasks);

  final List<CommandTask> _initialTasks;
  final List<String> stoppedTaskIds = [];

  @override
  CommandTaskState build() {
    return CommandTaskState(tasks: _initialTasks, initialized: true);
  }

  @override
  Future<CommandTask> stop(
    String id, {
    String? conversationId,
    bool modelInitiated = false,
  }) async {
    stoppedTaskIds.add(id);
    CommandTask? stoppedTask;
    state = CommandTaskState(
      tasks: state.tasks.map((t) {
        if (t.id == id) {
          stoppedTask = t.copyWith(status: CommandTaskStatus.cancelled);
          return stoppedTask!;
        }
        return t;
      }).toList(),
      initialized: true,
    );
    return stoppedTask ?? state.tasks.first;
  }
}

void main() {
  const workspace = WorkspaceSnapshot(
    id: 'ws-1',
    name: 'default',
    rootPath: '/data/ws-1',
    environmentRoot: '/data/ubuntu',
    environmentRevision: 'rev-1',
  );

  CommandTask createTask({
    required String id,
    required String command,
    CommandTaskStatus status = CommandTaskStatus.running,
  }) {
    return CommandTask(
      id: id,
      conversationId: 'conv-1',
      workspace: workspace,
      title: command,
      command: command,
      cwd: '/workspace',
      status: status,
      createdAt: DateTime.now().subtract(const Duration(seconds: 42)),
    );
  }

  Widget createWidget(
    List<CommandTask> tasks, {
    void Function(_FakeCommandTaskController)? onController,
  }) {
    final controller = _FakeCommandTaskController(tasks);
    if (onController != null) onController(controller);

    return ProviderScope(
      overrides: [commandTaskControllerProvider.overrideWith(() => controller)],
      child: MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        home: const Scaffold(
          body: Padding(
            padding: EdgeInsets.all(16),
            child: ChatRunningJobsPanel(),
          ),
        ),
      ),
    );
  }

  testWidgets('当没有后台 jobs 时，完全隐藏面板', (tester) async {
    await tester.pumpWidget(createWidget([]));
    await tester.pumpAndSettle();

    expect(find.byType(ChatRunningJobsPanel), findsOneWidget);
    expect(find.textContaining('python'), findsNothing);
    expect(
      find.byKey(const ValueKey('running-jobs-expand-button')),
      findsNothing,
    );
  });

  testWidgets('已经结束的 jobs 不会显示在面板中', (tester) async {
    final finishedTasks = [
      createTask(
        id: 't-1',
        command: 'echo done',
        status: CommandTaskStatus.succeeded,
      ),
      createTask(
        id: 't-2',
        command: 'cat failed.txt',
        status: CommandTaskStatus.failed,
      ),
      createTask(
        id: 't-3',
        command: 'kill -9',
        status: CommandTaskStatus.cancelled,
      ),
    ];

    await tester.pumpWidget(createWidget(finishedTasks));
    await tester.pumpAndSettle();

    expect(find.textContaining('echo done'), findsNothing);
    expect(find.textContaining('failed'), findsNothing);
    expect(find.byKey(const ValueKey('running-job-stop-t-1')), findsNothing);
  });

  testWidgets('单个运行中 job 时展示命令、耗时与停止按钮，且点击长命令可展开', (tester) async {
    _FakeCommandTaskController? controller;
    final singleTask = [
      createTask(
        id: 'task-long-1',
        command: 'python -m http.server 8080 --bind 127.0.0.1 --directory /tmp/workspace',
      ),
    ];

    await tester.pumpWidget(
      createWidget(singleTask, onController: (c) => controller = c),
    );
    await tester.pumpAndSettle();

    // 验证展示命令与耗时
    expect(
      find.byKey(const ValueKey('running-job-command-task-long-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('running-job-duration-task-long-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('running-job-stop-task-long-1')),
      findsOneWidget,
    );

    // 点击命令文本进行长命令展开
    await tester.tap(
      find.byKey(const ValueKey('running-job-command-task-long-1')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SelectableText), findsOneWidget);

    // 点击停止按钮
    await tester.tap(
      find.byKey(const ValueKey('running-job-stop-task-long-1')),
    );
    await tester.pumpAndSettle();
    expect(controller?.stoppedTaskIds, contains('task-long-1'));
  });

  testWidgets('多个运行中 jobs 时支持向上展开查看列表', (tester) async {
    final multipleTasks = [
      createTask(id: 'task-1', command: 'npm run dev'),
      createTask(id: 'task-2', command: 'docker compose up'),
    ];

    await tester.pumpWidget(createWidget(multipleTasks));
    await tester.pumpAndSettle();

    // 默认展示「2 个后台任务运行中」，不展示具体任务和展开按钮
    expect(find.text('2 个后台任务运行中'), findsOneWidget);
    expect(find.text('npm run dev'), findsNothing);
    expect(find.text('全部停止'), findsNothing);

    // 点击面板整行直接展开
    await tester.tap(find.byKey(const ValueKey('running-jobs-compact-multi')));
    await tester.pumpAndSettle();

    // 展开后看到全部任务列表与收起标题，带有分割线，无全部停止按钮
    expect(find.text('后台任务 (2)'), findsOneWidget);
    expect(find.text('npm run dev'), findsOneWidget);
    expect(find.text('docker compose up'), findsOneWidget);
    expect(find.text('全部停止'), findsNothing);
    expect(find.byType(Divider), findsWidgets);
    expect(
      find.byKey(const ValueKey('running-jobs-collapse-button')),
      findsOneWidget,
    );

    // 点击收起
    await tester.tap(
      find.byKey(const ValueKey('running-jobs-collapse-button')),
    );
    await tester.pumpAndSettle();
    expect(find.text('后台任务 (2)'), findsNothing);
    expect(find.text('2 个后台任务运行中'), findsOneWidget);
  });
}
