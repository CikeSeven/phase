import 'package:phase/data/models/permission_mode.dart';

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:phase/data/models/profile_model.dart';
import 'package:phase/data/models/tool_call_record.dart';
import 'package:phase/data/models/workspace.dart';
import 'package:phase/data/repositories/workspace_repository.dart';

import '../tools/tool_loop_harness.dart';
import 'local_process_driver.dart';

void main() {
  test('first send can use workspace files without Ubuntu; subsequent chats own different files', () async {
    final h = await ToolLoopHarness.create();
    final workspaces = await h.container.read(
      workspaceRepositoryProvider.future,
    );
    expect(h.conversationId(), isNull);
    expect(await workspaces.list(), isEmpty);
    h.onConfirmation = (_) async => ToolDecision.approved;
    h.provider.turns.addAll([
      toolTurn(
        callId: 'first-file',
        toolName: 'write_file',
        arguments: '{"path":"/workspace/note","content":"first"}',
      ),
      textTurn('saved'),
    ]);
    await h.controller().send('save first');
    final firstRun = await h.latestRun();
    expect(firstRun.configuration.workspace, isNotNull);
    expect(firstRun.configuration.workspace!.linuxAvailable, isFalse);
    expect(firstRun.configuration.enabledTools, isNot(contains('shell')));
    final firstFile = File(
      '${firstRun.configuration.workspace!.rootPath}/note',
    );
    expect(await firstFile.readAsString(), 'first');
    expect(
      (await h.recordsByCall())['first-file']!.status,
      ToolCallStatus.succeeded,
    );

    h.controller().startNewConversation();
    expect(h.conversationId(), isNull);
    expect(await workspaces.list(), hasLength(1));
    h.provider.turns.addAll([
      toolTurn(
        callId: 'second-file',
        toolName: 'write_file',
        arguments: '{"path":"/workspace/note","content":"second"}',
      ),
      textTurn('saved'),
    ]);
    await h.controller().send('save second');
    final secondRun = await h.latestRun();
    expect(
      secondRun.configuration.workspace!.id,
      isNot(firstRun.configuration.workspace!.id),
    );
    expect(
      await File('${secondRun.configuration.workspace!.rootPath}/note')
          .readAsString(),
      'second',
    );
    expect(await firstFile.readAsString(), 'first');
    expect(await workspaces.list(), hasLength(2));
  });

  for (final supportsTools in [true, false]) {
    test(
      'automatic shell respects explicit deny and model tool capability ($supportsTools)',
      () async {
        final processes = LocalProcessDriver();
        addTearDown(processes.dispose);
        final h = await ToolLoopHarness.create(
          processes: processes,
          models: [
            ProfileModel(
              id: 'model-a',
              enabled: true,
              supportsTools: supportsTools,
            ),
          ],
        );
        final workspaces = await h.container.read(
          workspaceRepositoryProvider.future,
        );
        await workspaces.saveEnvironment(
          const RuntimeEnvironment(
            phase: EnvironmentPhase.ready,
            rootPath: '/fixture',
            revision: 'fixture',
          ),
        );
        if (supportsTools) {
          await h.controller().setPermissionMode(PermissionMode.plan);
        }
        h.provider.turns.add(textTurn('done'));
        await h.controller().send('hello');
        final run = await h.latestRun();
        expect(run.configuration.workspace, isNotNull);
        expect(run.configuration.enabledTools, isNot(contains('shell')));
        expect(
          run.configuration.toolSnapshots.where((tool) => tool.name == 'shell'),
          isEmpty,
        );
        if (!supportsTools) expect(run.configuration.toolSnapshots, isEmpty);
        expect(processes.active, isEmpty);
      },
    );
  }
}
