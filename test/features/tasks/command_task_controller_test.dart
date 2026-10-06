import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/error/failure.dart';
import 'package:phase/data/datasources/local/app_database.dart';
import 'package:phase/data/models/command_task.dart';
import 'package:phase/data/models/permission_mode.dart';
import 'package:phase/data/models/tool_policy.dart';
import 'package:phase/features/tools/tool_permission_policy.dart';
import 'package:phase/data/models/workspace.dart';
import 'package:phase/data/repositories/command_task_repository.dart';
import 'package:phase/data/repositories/conversation_repository.dart';
import 'package:phase/data/repositories/workspace_repository.dart';
import 'package:phase/features/tasks/command_task_controller.dart';
import 'package:phase/features/tasks/task_tools.dart';
import 'package:phase/features/tasks/task_output_buffer.dart';
import 'package:phase/features/tools/tool.dart';
import 'package:phase/features/workspace/process_driver.dart';
import 'package:phase/features/workspace/shell_tool.dart';
import 'package:phase/features/workspace/workspace_files.dart';

import '../../support/test_database.dart';
import '../workspace/local_process_driver.dart';

class _Fixture {
  _Fixture(
    this.container,
    this.workspaceRepository,
    this.conversations,
    this.driver,
    this.owner,
    this.binding,
  );
  final ProviderContainer container;
  final WorkspaceRepository workspaceRepository;
  final ConversationRepository conversations;
  final LocalProcessDriver driver;
  final String owner;
  final WorkspaceSnapshot binding;
  CommandTaskController get tasks =>
      container.read(commandTaskControllerProvider.notifier);

  Future<CommandTask> start(
    String command, {
    RunCancellation? cancellation,
    int? timeoutMs,
    bool notifyOnCompletion = false,
  }) => tasks.start(
    conversationId: owner,
    workspace: binding,
    command: command,
    runId: 'run-one',
    cancellation: cancellation ?? RunCancellation(),
    timeoutMs: timeoutMs,
    notifyOnCompletion: notifyOnCompletion,
  );
}

Future<_Fixture> _create({
  LocalProcessDriver? processes,
  CommandTaskRepository Function(AppDatabase)? repository,
}) async {
  final fixture = createTestDatabase(name: 'tasks');
  final workspaces = WorkspaceRepository(fixture.database, fixture.directory);
  final conversations = ConversationRepository(
    fixture.database,
    workspaces: workspaces,
  );
  final owner = await conversations.createConversation(title: 'tasks');
  await workspaces.saveEnvironment(
    RuntimeEnvironment(
      phase: EnvironmentPhase.ready,
      rootPath: workspaces.filesystem.layout.rootfs,
      revision: 'fixture',
    ),
  );
  final driver = processes ?? LocalProcessDriver();
  final container = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWith((ref) => fixture.database),
      workspaceRepositoryProvider.overrideWith((ref) => workspaces),
      conversationRepositoryProvider.overrideWith((ref) => conversations),
      processDriverProvider.overrideWith((ref) => driver),
      if (repository != null)
        commandTaskRepositoryProvider.overrideWith(
          (ref) => repository(fixture.database),
        ),
    ],
  );
  final controller = container.read(commandTaskControllerProvider.notifier);
  await controller.initialize();
  addTearDown(() async {
    await controller.stopAll();
    container.dispose();
    await driver.dispose();
    await fixture.database.close();
    await fixture.directory.delete(recursive: true);
  });
  return _Fixture(
    container,
    workspaces,
    conversations,
    driver,
    owner.id,
    await workspaces.snapshot(owner.workspaceId!),
  );
}

Future<CommandTaskOutput> _untilOutput(
  _Fixture fixture,
  String id,
  String text,
) async {
  final end = DateTime.now().add(const Duration(seconds: 5));
  while (DateTime.now().isBefore(end)) {
    final output = await fixture.tasks.output(id);
    if (output.stdout.text.contains(text)) return output;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  throw StateError('Command did not produce expected output');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'plan mode permits task observation and denies commands and task mutation',
    () {
      expect(
        policyForMode(PermissionMode.plan, const TaskTool(TaskToolAction.list)),
        ToolPolicy.allow,
      );
      expect(
        policyForMode(
          PermissionMode.plan,
          const TaskTool(TaskToolAction.output),
        ),
        ToolPolicy.allow,
      );
      expect(
        policyForMode(PermissionMode.plan, const TaskTool(TaskToolAction.stop)),
        ToolPolicy.deny,
      );
      expect(
        policyForMode(PermissionMode.plan, const ShellTool()),
        ToolPolicy.deny,
      );
      expect(
        const TaskTool(TaskToolAction.output)
            .validateArguments({'maxBytes': 1}),
        isNotNull,
      );
      expect(
        const TaskTool(TaskToolAction.list).validateArguments({'limit': 100}),
        isNotNull,
      );
      expect(
        const TaskTool(TaskToolAction.output)
            .validateArguments({'waitMs': 30001}),
        isNotNull,
      );
    },
  );

  test('owner admission limit is enforced before dispatch', () async {
    final fixture = await _create();
    for (var i = 0; i < CommandTaskController.maxActivePerConversation; i++) {
      await fixture.start('sleep 60');
    }
    await expectLater(
      fixture.start('sleep 60'),
      throwsA(isA<OperationFailure>()),
    );
    expect(
      fixture.driver.calls,
      hasLength(CommandTaskController.maxActivePerConversation),
    );
  });

  test('restart creates a new identity while repeated tool admission reuses the existing task', () async {
    final fixture = await _create();
    Future<CommandTask> start() => fixture.tasks.start(
      conversationId: fixture.owner,
      workspace: fixture.binding,
      command: 'printf once',
      toolCallId: 'one-call',
      cancellation: RunCancellation(),
    );
    final first = await start();
    await fixture.tasks.wait(
      first.id,
      const Duration(seconds: 5),
      conversationId: fixture.owner,
    );
    expect((await start()).id, first.id);
    expect(fixture.driver.calls, hasLength(1));
    final restart = await fixture.tasks.restart(first.id, RunCancellation());
    expect(restart.id, isNot(first.id));
    await fixture.tasks.wait(
      restart.id,
      const Duration(seconds: 5),
      conversationId: fixture.owner,
    );
    expect(fixture.driver.calls, hasLength(2));
  });

  test(
    'background process survives run cleanup and cancellation after admission',
    () async {
      final fixture = await _create();
      final cancellation = RunCancellation();
      final task = await fixture.start(
        'printf ready; sleep 60',
        cancellation: cancellation,
      );
      await _untilOutput(fixture, task.id, 'ready');
      cancellation.cancel();
      await fixture.driver.endTask('run-one');
      expect(fixture.tasks.task(task.id).status, CommandTaskStatus.running);
      expect(fixture.driver.active, hasLength(1));
      expect(fixture.driver.calls.single.outputLimitBytes, isNull);
      final lease = await fixture.workspaceRepository.acquire(
        fixture.binding.id,
      );
      lease.close();
      expect(fixture.workspaceRepository.inUse(fixture.binding.id), isTrue);
      expect(
        () => fixture.workspaceRepository.beginEnvironmentChange(),
        throwsA(isA<OperationFailure>()),
      );
      await expectLater(
        fixture.conversations.deleteConversation(fixture.owner),
        throwsA(isA<OperationFailure>()),
      );
      final stopped = await fixture.tasks.stop(task.id);
      expect(stopped.status, CommandTaskStatus.cancelled);
      expect(fixture.workspaceRepository.busy, isFalse);
      expect(fixture.driver.owners, isEmpty);
      expect((await fixture.tasks.output(task.id)).stdout.text, 'ready');
      expect(
        (await fixture.tasks.stop(task.id)).status,
        CommandTaskStatus.cancelled,
      );
      await fixture.tasks.remove(task.id);
      expect(fixture.tasks.tasks, isEmpty);
    },
  );

  test(
    'successful and nonzero completion persist split logs and release leases',
    () async {
      final fixture = await _create();
      for (final code in [0, 7]) {
        final task = await fixture.start(
          'printf output; printf diagnostic >&2; exit $code',
        );
        final result = await fixture.tasks.wait(
          task.id,
          const Duration(seconds: 5),
          conversationId: fixture.owner,
        );
        expect(
          result.status,
          code == 0 ? CommandTaskStatus.succeeded : CommandTaskStatus.failed,
        );
        expect(result.exitCode, code);
        final output = await fixture.tasks.output(task.id);
        expect(output.stdout.text, 'output');
        expect(output.stderr.text, 'diagnostic');
        expect(fixture.workspaceRepository.busy, isFalse);
      }
    },
  );

  test(
    'long output is retained as a bounded tail without terminating the service',
    () async {
      final fixture = await _create();
      final task = await fixture.start(
        'head -c 9000000 /dev/zero; printf done; sleep 60',
      );
      final output = await _untilOutput(fixture, task.id, 'done');
      expect(output.stdout.totalBytes, 9000004);
      expect(
        output.stdout.oldestOffset,
        9000004 - TaskOutputBuffer.retainBytes,
      );
      expect(fixture.tasks.task(task.id).status, CommandTaskStatus.running);
      final old = await fixture.tasks.output(
        task.id,
        stdoutOffset: 0,
        stderrOffset: 0,
        maxBytes: 5,
      );
      expect(old.stdout.truncated, isTrue);
      expect(old.stdout.nextOffset, old.stdout.oldestOffset + 5);
      await fixture.tasks.stop(task.id);
      final saved = await (await fixture.container.read(
        commandTaskRepositoryProvider.future,
      )).get(task.id);
      expect(saved!.stdout.length, TaskOutputBuffer.retainBytes);
    },
  );

  test('waiting and cancelling a log read leave the process running', () async {
    final fixture = await _create();
    final task = await fixture.start('sleep 60');
    final timeout = await fixture.tasks.wait(
      task.id,
      const Duration(milliseconds: 10),
      conversationId: fixture.owner,
    );
    expect(timeout.status, CommandTaskStatus.running);
    final cancellation = RunCancellation();
    final waiting = fixture.tasks.wait(
      task.id,
      const Duration(seconds: 5),
      conversationId: fixture.owner,
      cancellation: cancellation,
    );
    cancellation.cancel();
    await expectLater(waiting, throwsA(isA<ToolCancelled>()));
    expect(fixture.tasks.task(task.id).status, CommandTaskStatus.running);
  });

  test(
    'execution timeout stops the process independently of wait windows',
    () async {
      final fixture = await _create();
      final task = await fixture.start(
        'printf started; sleep 60',
        timeoutMs: 100,
      );
      final result = await fixture.tasks.wait(
        task.id,
        const Duration(seconds: 5),
        conversationId: fixture.owner,
      );
      expect(result.status, CommandTaskStatus.timedOut);
      expect(fixture.workspaceRepository.busy, isFalse);
    },
  );

  test('foreign sessions cannot read or stop a task', () async {
    final fixture = await _create();
    final task = await fixture.start('sleep 60');
    await expectLater(
      fixture.tasks.output(task.id, conversationId: 'foreign'),
      throwsA(isA<OperationFailure>()),
    );
    await expectLater(
      fixture.tasks.stop(task.id, conversationId: 'foreign'),
      throwsA(isA<OperationFailure>()),
    );
    expect(fixture.tasks.task(task.id).status, CommandTaskStatus.running);
  });

  test('cancellation while preparing leaves no dispatched command', () async {
    final driver = _GatedDriver();
    final fixture = await _create(processes: driver);
    final cancellation = RunCancellation();
    final starting = fixture.start('sleep 60', cancellation: cancellation);
    await driver.preparing.future;
    cancellation.cancel();
    driver.release.complete();
    await expectLater(starting, throwsA(isA<ToolCancelled>()));
    expect(driver.calls, isEmpty);
    expect(fixture.tasks.tasks.single.status, CommandTaskStatus.cancelled);
    expect(fixture.workspaceRepository.busy, isFalse);
  });

  test(
    'parallel stops are idempotent and invalid cwd does not orphan a task',
    () async {
      final fixture = await _create();
      final task = await fixture.start('sleep 60');
      await Future.wait([
        fixture.tasks.stop(task.id),
        fixture.tasks.stop(task.id),
      ]);
      expect(fixture.tasks.task(task.id).status, CommandTaskStatus.cancelled);
      await expectLater(
        fixture.tasks.start(
          conversationId: fixture.owner,
          workspace: fixture.binding,
          command: 'true',
          cwd: '/missing-directory',
          cancellation: RunCancellation(),
        ),
        throwsA(isA<Failure>()),
      );
      expect(fixture.tasks.tasks.first.status, CommandTaskStatus.failed);
      expect(fixture.workspaceRepository.busy, isFalse);
      expect(fixture.driver.owners, isEmpty);
    },
  );

  test(
    'recovery marks uncompleted records interrupted without dispatching',
    () async {
      final fixture = await _create();
      final repository = await fixture.container.read(
        commandTaskRepositoryProvider.future,
      );
      final now = DateTime.now();
      for (final status in [
        CommandTaskStatus.starting,
        CommandTaskStatus.running,
        CommandTaskStatus.stopping,
      ]) {
        await repository.add(
          CommandTask(
            id: status.name,
            conversationId: fixture.owner,
            workspace: fixture.binding,
            title: status.name,
            command: 'sleep 60',
            cwd: fixture.binding.executionRoot,
            createdAt: now,
            status: status,
          ),
        );
      }
      await repository.recover();
      expect(
        (await repository.list()).every(
          (task) => task.status == CommandTaskStatus.interrupted,
        ),
        isTrue,
      );
      expect(fixture.driver.calls, isEmpty);
    },
  );

  test('failed terminal persistence retains logs and can be retried', () async {
    late _FailTerminalSave repository;
    final fixture = await _create(
      repository: (db) => repository = _FailTerminalSave(db),
    );
    final task = await fixture.start('printf preserved');
    await fixture.tasks.wait(
      task.id,
      const Duration(seconds: 5),
      conversationId: fixture.owner,
    );
    expect(
      fixture.container.read(commandTaskControllerProvider).error,
      isA<StorageFailure>(),
    );
    expect((await fixture.tasks.output(task.id)).stdout.text, 'preserved');
    expect(fixture.tasks.task(task.id).status, CommandTaskStatus.succeeded);
    repository.fail = false;
    await fixture.tasks.refresh();
    expect(fixture.container.read(commandTaskControllerProvider).error, isNull);
    expect(
      (await repository.get(task.id))!.task.status,
      CommandTaskStatus.succeeded,
    );
  });

  test(
    'shell yields a task ID and task tools only expose the current session',
    () async {
      final fixture = await _create();
      final storage = _NoArtifacts();
      final context = ToolContext(
        conversationId: fixture.owner,
        runId: 'run-one',
        toolCallId: 'call-one',
        storage: storage,
        attachments: const [],
      );
      final shell = ShellTool(
        workspace: fixture.binding,
        driver: fixture.driver,
        files: WorkspaceFiles(fixture.workspaceRepository),
        tasks: fixture.tasks,
      );
      final outcome = await shell.execute(
        {'command': 'printf ready; sleep 60', 'yieldMs': 10},
        context,
        RunCancellation(),
      );
      final result = jsonDecode(outcome.content) as Map<String, dynamic>;
      expect(outcome.ok, isTrue);
      expect(result['background'], isTrue);
      expect(result['taskId'], isA<String>());
      final listed = await TaskTool(
        TaskToolAction.list,
        controller: fixture.tasks,
      ).execute({}, context, RunCancellation());
      expect((jsonDecode(listed.content) as Map)['total'], 1);
      final stopped = await TaskTool(
        TaskToolAction.stop,
        controller: fixture.tasks,
      ).execute({'taskId': result['taskId']}, context, RunCancellation());
      expect((jsonDecode(stopped.content) as Map)['status'], 'cancelled');
    },
  );
}

class _GatedDriver extends LocalProcessDriver {
  final preparing = Completer<void>();
  final release = Completer<void>();
  @override
  Future<void> beginTask(String owner, String label) async {
    preparing.complete();
    await release.future;
    await super.beginTask(owner, label);
  }
}

class _FailTerminalSave extends CommandTaskRepository {
  _FailTerminalSave(super.db);
  bool fail = true;
  @override
  Future<void> save(CommandTaskData data) async {
    if (fail && !data.task.status.active) {
      throw const StorageFailure('fixture storage failure');
    }
    await super.save(data);
  }
}

class _NoArtifacts implements ToolStorage {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('No artifacts expected');
}
