import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/theme/app_theme.dart';
import 'package:phase/data/models/command_task.dart';
import 'package:phase/data/models/conversation.dart';
import 'package:phase/data/models/workspace.dart';
import 'package:phase/features/tasks/command_task_controller.dart';
import 'package:phase/features/tasks/task_detail_page.dart';
import 'package:phase/features/tasks/task_output_buffer.dart';
import 'package:phase/features/tasks/task_start_dialog.dart';
import 'package:phase/features/tasks/tasks_page.dart';

final _task = CommandTask(
  id: 'task-1',
  conversationId: 'conversation-1',
  workspace: const WorkspaceSnapshot(
    id: 'conversation-1',
    name: 'workspace',
    rootPath: '/host',
    environmentRoot: '/rootfs',
    environmentRevision: 'fixture',
  ),
  title: 'A long service task title with repeated output and a very long name',
  command: 'npm run dev -- --host 127.0.0.1',
  cwd: '/sessions/conversation-1',
  createdAt: DateTime(2026, 10, 7),
  status: CommandTaskStatus.running,
);

class _UiTasks extends CommandTaskController {
  @override
  CommandTaskState build() =>
      CommandTaskState(tasks: [_task], initialized: true);
  @override
  Future<void> initialize() async {}
}

void main() {
  for (final size in [const Size(320, 640), const Size(640, 280)]) {
    for (final dark in [false, true]) {
      testWidgets('task list and detail fit $size, dark=$dark, large text', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        Future<void> show(Widget page) async {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                commandTaskControllerProvider.overrideWith(_UiTasks.new),
                taskConversationsProvider.overrideWith(
                  (ref) => Stream.value([
                    Conversation(
                      id: 'conversation-1',
                      title: 'Conversation with a long name',
                      workspaceId: 'conversation-1',
                      createdAt: DateTime(2026),
                      updatedAt: DateTime(2026),
                    ),
                  ]),
                ),
                commandTaskOutputProvider('task-1').overrideWith(
                  (ref) async => CommandTaskOutput(
                    _task,
                    const TaskOutputPage(
                      text: 'server ready\nlogs\n',
                      nextOffset: 18,
                      oldestOffset: 0,
                      totalBytes: 18,
                      truncated: false,
                    ),
                    const TaskOutputPage(
                      text: '',
                      nextOffset: 0,
                      oldestOffset: 0,
                      totalBytes: 0,
                      truncated: false,
                    ),
                  ),
                ),
              ],
              child: MaterialApp(
                theme: dark ? AppTheme.dark() : AppTheme.light(),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: const TextScaler.linear(2)),
                  child: child!,
                ),
                home: page,
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
        }

        await show(const TasksPage());
        expect(tester.takeException(), isNull);
        await show(const TaskDetailPage(id: 'task-1'));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }

  testWidgets(
    'new task dialog keeps command and actions reachable with keyboard',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 240);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            commandTaskControllerProvider.overrideWith(_UiTasks.new),
            taskConversationsProvider.overrideWith(
              (ref) => Stream.value([
                Conversation(
                  id: 'conversation-1',
                  title: 'Service',
                  workspaceId: 'conversation-1',
                  createdAt: DateTime(2026),
                  updatedAt: DateTime(2026),
                ),
              ]),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(body: TaskStartDialog()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('启动'), findsOneWidget);
      expect(find.text('取消'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
