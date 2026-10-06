import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:phase/data/models/chat_message.dart';
import 'package:phase/data/models/chat_request.dart';
import 'package:phase/data/models/chat_chunk.dart';
import 'package:phase/data/models/command_task.dart';
import 'package:phase/data/models/message_part.dart';
import 'package:phase/data/models/tool_call_record.dart';
import 'package:phase/data/models/workspace.dart';
import 'package:phase/data/repositories/command_task_repository.dart';
import 'package:phase/data/repositories/workspace_repository.dart';
import 'package:phase/data/repositories/conversation_repository.dart';
import 'package:phase/features/tasks/command_task_controller.dart';
import 'package:phase/data/repositories/provider_profile_repository.dart';
import 'package:phase/core/error/failure.dart';
import 'package:phase/core/utils/id.dart';

import '../tools/tool_loop_harness.dart';
import 'controlled_process_driver.dart';

Future<void> _until(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw StateError('Completion flow did not settle');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

Future<(ToolLoopHarness, ControlledProcessDriver, CommandTaskController)>
_setup() async {
  final driver = ControlledProcessDriver();
  addTearDown(driver.dispose);
  final harness = await ToolLoopHarness.create(processes: driver);
  final workspace = await harness.container.read(
    workspaceRepositoryProvider.future,
  );
  await workspace.saveEnvironment(
    RuntimeEnvironment(
      phase: EnvironmentPhase.ready,
      rootPath: workspace.filesystem.layout.rootfs,
      revision: 'fixture',
    ),
  );
  final tasks = harness.container.read(commandTaskControllerProvider.notifier);
  harness.onConfirmation = (_) async => ToolDecision.approved;
  final conversations = await harness.conversations();
  final owner = await conversations.createConversation(title: 'Jobs');
  await conversations.appendMessage(
    ChatMessage(
      id: generateId(),
      conversationId: owner.id,
      role: ChatRole.user,
      parts: const [TextPart(text: 'Existing conversation')],
      createdAt: DateTime.now(),
    ),
  );
  await harness.controller().openConversation(owner.id);
  return (harness, driver, tasks);
}

Future<void> _launch(
  ToolLoopHarness harness, {
  int count = 1,
  bool notify = true,
}) async {
  harness.provider.turns.addAll([
    multiToolTurn([
      for (var i = 0; i < count; i++)
        (
          callId: 'start-$i',
          toolName: 'shell',
          arguments: jsonEncode({
            'command': 'sleep 60',
            'background': true,
            'title': 'job-$i',
            'notifyOnCompletion': notify,
          }),
        ),
    ]),
    textTurn('Started.'),
  ]);
  await harness.controller().send('Run the background job.');
  final conversations = await harness.conversations();
  await conversations.renameConversation(harness.conversationId()!, 'Jobs');
}

String _requestText(ChatRequest request) => request.messages
    .expand((message) => message.parts)
    .whereType<ResolvedText>()
    .map((part) => part.text)
    .join('\n');

void main() {
  test(
    'idle completion creates another AI run without another user message',
    () async {
      final (h, driver, tasks) = await _setup();
      await _launch(h);
      final task = tasks.tasks.single;
      final firstRun = (await h.latestRun()).id;
      h.provider.turns.add(textTurn('Background job finished.'));
      driver.processes.single.complete();
      await _until(
        () =>
            tasks.task(task.id).completionDelivery ==
                TaskCompletionDelivery.delivered &&
            !h.state().isConversationRunning(task.conversationId),
      );
      final thread = await (await h.conversations()).getThread(
        task.conversationId,
      );
      expect(
        thread!.branch.where((message) => message.role == ChatRole.user),
        hasLength(2),
      );
      expect(thread.branch.last.text, 'Background job finished.');
      expect((await h.latestRun()).id, isNot(firstRun));
      expect(
        _requestText(h.provider.requests.last),
        contains('section="task_completion"'),
      );
      expect(_requestText(h.provider.requests.last), contains(task.id));
      expect(driver.calls, hasLength(1));
    },
  );

  test('completion during a running answer is claimed in the same run before it ends', () async {
    final (h, driver, tasks) = await _setup();
    await _launch(h);
    final task = tasks.tasks.single;
    final answer = StreamController<ChatChunk>();
    h.provider.turns.addAll([
      answer.stream,
      textTurn('I also handled the completed job.'),
    ]);
    final pending = h.controller().send('Continue independent work.');
    await _until(() => h.state().isConversationRunning(task.conversationId));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    driver.processes.single.complete();
    await _until(
      () =>
          tasks.task(task.id).completionDelivery ==
          TaskCompletionDelivery.pending,
    );
    final currentRun = (await h.latestRun()).id;
    for (final event in await textTurn('Independent work done.').toList()) {
      answer.add(event);
    }
    await answer.close();
    await pending;
    expect((await h.latestRun()).id, currentRun);
    expect(
      tasks.task(task.id).completionDelivery,
      TaskCompletionDelivery.delivered,
    );
    expect((await h.branch()).last.text, 'I also handled the completed job.');
  });

  test(
    'same-session simultaneous completions are delivered as one batch',
    () async {
      final (h, driver, tasks) = await _setup();
      await _launch(h, count: 2);
      final owner = h.conversationId()!;
      final gate = StreamController<ChatChunk>();
      h.provider.turns.addAll([gate.stream, textTurn('Both jobs finished.')]);
      final working = h.controller().send('Work while waiting.');
      await _until(() => h.state().isConversationRunning(owner));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      for (final process in driver.processes) {
        process.complete();
      }
      await _until(() => tasks.pendingCompletions(owner).length == 2);
      for (final event in await textTurn('Other work done.').toList()) {
        gate.add(event);
      }
      await gate.close();
      await working;
      final notices = (await h.branch())
          .expand((message) => message.parts)
          .whereType<RuntimeContextPart>()
          .where((part) => part.section == 'task_completion')
          .toList();
      expect(notices, hasLength(1));
      for (final task in tasks.tasks) {
        expect(notices.single.text, contains(task.id));
      }
    },
  );

  test('completion targets its original session without switching the current page', () async {
    final (h, driver, tasks) = await _setup();
    await _launch(h);
    final owner = h.conversationId()!;
    final other = await (await h.conversations()).createConversation(
      title: 'Other',
    );
    await h.controller().openConversation(other.id);
    h.provider.turns.add(textTurn('Reply in the original session.'));
    driver.processes.single.complete();
    await _until(
      () =>
          tasks.tasks.single.completionDelivery ==
              TaskCompletionDelivery.delivered &&
          !h.state().isConversationRunning(owner),
    );
    expect(h.conversationId(), other.id);
    expect(
      (await (await h.conversations()).getThread(owner))!.branch.last.text,
      'Reply in the original session.',
    );
    expect(
      (await (await h.conversations()).getThread(other.id))!.messages,
      isEmpty,
    );
  });

  test('quiet tasks do not wake the model', () async {
    final (h, driver, tasks) = await _setup();
    await _launch(h, notify: false);
    final before = h.provider.requests.length;
    driver.processes.single.complete();
    await _until(() => !tasks.tasks.single.status.active);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(
      tasks.tasks.single.completionDelivery,
      TaskCompletionDelivery.suppressed,
    );
    expect(h.provider.requests.length, before);
  });

  test('nonzero exit and execution timeout both wake the owner with the final status', () async {
    final (h, driver, tasks) = await _setup();
    await _launch(h, count: 2);
    h.provider.turns.addAll([
      textTurn('Failure handled.'),
      textTurn('Timeout handled.'),
    ]);
    driver.processes[0].complete(exitCode: 7);
    await _until(
      () =>
          tasks.tasks
                  .where(
                    (task) =>
                        task.completionDelivery ==
                        TaskCompletionDelivery.delivered,
                  )
                  .length ==
              1 &&
          !h.state().isConversationRunning(h.conversationId()!),
    );
    expect(
      _requestText(h.provider.requests.last),
      contains('"status":"failed"'),
    );
    driver.processes[1].complete(timedOut: true);
    await _until(
      () =>
          tasks.tasks.every(
            (task) =>
                task.completionDelivery == TaskCompletionDelivery.delivered,
          ) &&
          !h.state().isConversationRunning(h.conversationId()!),
    );
    expect(
      _requestText(h.provider.requests.last),
      contains('"status":"timedOut"'),
    );
    expect(driver.calls, hasLength(2));
  });

  test(
    'a wait which times out does not suppress the later automatic completion',
    () async {
      final (h, driver, tasks) = await _setup();
      await _launch(h);
      final task = tasks.tasks.single;
      h.provider.turns.addAll([
        toolTurn(
          callId: 'wait',
          toolName: 'task_output',
          arguments: jsonEncode({'taskId': task.id, 'waitMs': 20}),
        ),
        textTurn('Still running.'),
      ]);
      await h.controller().send('Wait briefly.');
      expect(task.status.active, isTrue);
      h.provider.turns.add(textTurn('Now completed.'));
      driver.processes.single.complete();
      await _until(
        () =>
            tasks.tasks.single.completionDelivery ==
                TaskCompletionDelivery.delivered &&
            !h.state().isConversationRunning(h.conversationId()!),
      );
      expect((await h.branch()).last.text, 'Now completed.');
    },
  );

  test(
    'human stopping a task wakes AI but model stopping it does not',
    () async {
      final (h, driver, tasks) = await _setup();
      await _launch(h);
      h.provider.turns.add(textTurn('The task was stopped.'));
      await tasks.stop(tasks.tasks.single.id);
      await _until(
        () =>
            tasks.tasks.single.completionDelivery ==
                TaskCompletionDelivery.delivered &&
            !h.state().isConversationRunning(h.conversationId()!),
      );
      expect((await h.branch()).last.text, 'The task was stopped.');
      expect(driver.calls, hasLength(1));
    },
  );

  test(
    'stopping an AI run parks pending completions until explicit retry',
    () async {
      final (h, driver, tasks) = await _setup();
      await _launch(h);
      final owner = h.conversationId()!;
      final gate = StreamController<ChatChunk>();
      h.provider.turns.add(gate.stream);
      final work = h.controller().send('Independent work.');
      await _until(() => h.state().isConversationRunning(owner));
      h.controller().stopConversation(owner);
      await gate.close();
      await work;
      driver.processes.single.complete();
      await _until(
        () =>
            tasks.tasks.single.completionDelivery ==
            TaskCompletionDelivery.pending,
      );
      final before = h.provider.requests.length;
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(h.provider.requests.length, before);
      h.provider.turns.add(textTurn('Resumed completion reply.'));
      tasks.retryCompletionDelivery();
      await _until(
        () =>
            tasks.tasks.single.completionDelivery ==
                TaskCompletionDelivery.delivered &&
            !h.state().isConversationRunning(owner),
      );
      expect((await h.branch()).last.text, 'Resumed completion reply.');
    },
  );

  test('missing provider keeps the notification pending and explicit retry delivers it once', () async {
    final (h, driver, tasks) = await _setup();
    await _launch(h);
    final owner = h.conversationId()!;
    final profiles = await h.container.read(
      providerProfileRepositoryProvider.future,
    );
    await profiles.deleteProfile(h.profile.id);
    final before = h.provider.requests.length;
    driver.processes.single.complete();
    await _until(
      () => h.container
          .read(commandTaskControllerProvider)
          .completionErrors
          .containsKey(owner),
    );
    expect(
      tasks.tasks.single.completionDelivery,
      TaskCompletionDelivery.pending,
    );
    expect(driver.owners, isEmpty);
    expect(h.provider.requests.length, before);
    await profiles.saveProfile(h.profile);
    h.provider.turns.add(textTurn('Retried completion.'));
    tasks.retryCompletionDelivery();
    await _until(
      () =>
          tasks.tasks.single.completionDelivery ==
              TaskCompletionDelivery.delivered &&
          !h.state().isConversationRunning(owner),
    );
    expect(h.provider.requests.length, before + 1);
    tasks.retryCompletionDelivery();
    await tasks.refresh();
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(h.provider.requests.length, before + 1);
  });

  test('persisted completion is delivered at initialization without restarting its command', () async {
    final (h, driver, tasks) = await _setup();
    final owner = h.conversationId()!;
    final workspaces = await h.container.read(
      workspaceRepositoryProvider.future,
    );
    final binding = await workspaces.snapshot(owner);
    final repository = await h.container.read(
      commandTaskRepositoryProvider.future,
    );
    await repository.add(
      CommandTask(
        id: 'saved-completion',
        conversationId: owner,
        workspace: binding,
        title: 'Saved',
        command: 'sleep 60',
        cwd: binding.executionRoot,
        createdAt: DateTime.now(),
        status: CommandTaskStatus.succeeded,
        completionDelivery: TaskCompletionDelivery.pending,
      ),
    );
    h.provider.turns.add(textTurn('Recovered completion notice.'));
    await h.controller().initializeTaskContinuations();
    await _until(
      () =>
          tasks.task('saved-completion').completionDelivery ==
              TaskCompletionDelivery.delivered &&
          !h.state().isConversationRunning(owner),
    );
    expect(driver.calls, isEmpty);
    expect((await h.branch()).last.text, 'Recovered completion notice.');
  });

  test(
    'completed notification claim rolls back if appending the notice fails',
    () async {
      final (h, _, tasks) = await _setup();
      final owner = h.conversationId()!;
      final workspaces = await h.container.read(
        workspaceRepositoryProvider.future,
      );
      final binding = await workspaces.snapshot(owner);
      final repository = await h.container.read(
        commandTaskRepositoryProvider.future,
      );
      await repository.add(
        CommandTask(
          id: 'atomic',
          conversationId: owner,
          workspace: binding,
          title: 'Atomic',
          command: 'true',
          cwd: binding.executionRoot,
          createdAt: DateTime.now(),
          status: CommandTaskStatus.succeeded,
          completionDelivery: TaskCompletionDelivery.pending,
        ),
      );
      await tasks.initialize();
      final failing = _FailAppend(h.database, workspaces: workspaces);
      await expectLater(
        tasks.deliverCompletions(owner, 'test-run', failing),
        throwsA(isA<StorageFailure>()),
      );
      expect(
        (await repository.get('atomic'))!.task.completionDelivery,
        TaskCompletionDelivery.pending,
      );
      final messages = (await h.branch()).length;
      expect(
        await tasks.deliverCompletions(
          owner,
          'test-run',
          await h.conversations(),
        ),
        isTrue,
      );
      expect(
        await tasks.deliverCompletions(
          owner,
          'test-run',
          await h.conversations(),
        ),
        isFalse,
      );
      expect((await h.branch()).length, messages + 1);
    },
  );

  test('model cancelling a running task does not schedule a second completion reply', () async {
    final (h, _, tasks) = await _setup();
    await _launch(h);
    final task = tasks.tasks.single;
    h.provider.turns.addAll([
      toolTurn(
        callId: 'stop',
        toolName: 'task_stop',
        arguments: jsonEncode({'taskId': task.id}),
      ),
      textTurn('Stopped without wake.'),
    ]);
    await h.controller().send('Stop the task.');
    final before = h.provider.requests.length;
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(
      tasks.task(task.id).completionDelivery,
      TaskCompletionDelivery.suppressed,
    );
    expect(h.provider.requests.length, before);
  });

  test(
    'waiting for the terminal result suppresses a redundant automatic reply',
    () async {
      final (h, driver, tasks) = await _setup();
      await _launch(h);
      final task = tasks.tasks.single;
      h.provider.turns.addAll([
        toolTurn(
          callId: 'wait',
          toolName: 'task_output',
          arguments: jsonEncode({'taskId': task.id, 'waitMs': 1000}),
        ),
        textTurn('Read the final output.'),
      ]);
      final waiting = h.controller().send('Wait for the task.');
      await _until(() => h.provider.requests.length >= 3);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      await driver.processes.single.emit('finished output');
      driver.processes.single.complete();
      await waiting;
      expect(
        tasks.task(task.id).completionDelivery,
        TaskCompletionDelivery.suppressed,
      );
      expect((await h.branch()).last.text, 'Read the final output.');
      expect(driver.owners, isEmpty);
    },
  );
}

class _FailAppend extends ConversationRepository {
  _FailAppend(super.db, {required super.workspaces});
  @override
  Future<ChatMessage> appendMessage(
    ChatMessage message, {
    bool updateTitle = false,
  }) => Future.error(const StorageFailure('fixture append failed'));
}
