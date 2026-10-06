import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:phase/data/models/chat_request.dart';
import 'package:phase/data/models/tool_call_record.dart';
import 'package:phase/data/models/workspace.dart';
import 'package:phase/data/repositories/workspace_repository.dart';
import 'package:phase/features/tasks/command_task_controller.dart';

import '../tools/tool_loop_harness.dart';
import '../workspace/local_process_driver.dart';

void main() {
  test('model starts a service, finishes a run, then reads and stops it in another run', () async {
    final driver = LocalProcessDriver();
    addTearDown(driver.dispose);
    final harness = await ToolLoopHarness.create(processes: driver);
    final workspaces = await harness.container.read(
      workspaceRepositoryProvider.future,
    );
    await workspaces.saveEnvironment(
      RuntimeEnvironment(
        phase: EnvironmentPhase.ready,
        rootPath: workspaces.filesystem.layout.rootfs,
        revision: 'fixture',
      ),
    );
    final tasks = harness.container.read(
      commandTaskControllerProvider.notifier,
    );
    addTearDown(tasks.stopAll);
    harness.onConfirmation = (_) async => ToolDecision.approved;
    harness.provider.turns.addAll([
      toolTurn(
        callId: 'service',
        toolName: 'shell',
        arguments: jsonEncode({
          'command': 'printf service-ready; sleep 60',
          'background': true,
          'title': 'service',
        }),
      ),
      textTurn('Service started.'),
    ]);
    await harness.controller().send('Start the service.');
    final task = tasks.tasks.single;
    expect(task.status.active, isTrue);
    expect(driver.active, hasLength(1));
    final firstRun = await harness.latestRun();
    final firstCalls = await (await harness.toolCalls()).getByRun(firstRun.id);
    expect(firstCalls.single.status, ToolCallStatus.succeeded);
    expect(firstCalls.single.result, contains(task.id));
    harness.provider.turns.addAll([
      toolTurn(
        callId: 'logs',
        toolName: 'task_output',
        arguments: jsonEncode({'taskId': task.id, 'waitMs': 500}),
      ),
      toolTurn(
        callId: 'stop',
        toolName: 'task_stop',
        arguments: jsonEncode({'taskId': task.id}),
      ),
      textTurn('Service stopped.'),
    ]);
    await harness.controller().send('Read the logs and stop the service.');
    expect(tasks.task(task.id).status.active, isFalse);
    expect(driver.active, isEmpty);
    expect(driver.calls, hasLength(1));
    final secondCalls = await (await harness.toolCalls()).getByRun(
      (await harness.latestRun()).id,
    );
    expect(secondCalls.map((call) => call.toolName), [
      'task_output',
      'task_stop',
    ]);
    expect(
      secondCalls.every((call) => call.status == ToolCallStatus.succeeded),
      isTrue,
    );
    final text = harness.provider.requests.last.messages
        .expand((message) => message.parts)
        .whereType<ResolvedText>()
        .map((part) => part.text)
        .join('\n');
    expect(text, contains('section="tasks"'));
    expect(text, contains(task.id));
    final results = harness.provider.requests.last.messages
        .expand((message) => message.parts)
        .whereType<ResolvedToolResult>()
        .map((part) => part.content)
        .join('\n');
    expect(results, contains('service-ready'));
    expect(workspaces.busy, isFalse);
  });
}
