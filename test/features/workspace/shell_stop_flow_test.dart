import 'dart:convert';
import 'dart:io';

import 'package:phase/data/repositories/workspace_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase/data/models/agent_run.dart';
import 'package:phase/data/models/tool_call_record.dart';
import 'package:phase/data/models/workspace.dart';
import 'package:phase/data/repositories/assistant_repository.dart';
import 'package:phase/data/repositories/conversation_repository.dart';

import '../tools/tool_loop_harness.dart';
import 'local_process_driver.dart';

void main() {
  test('stop a real idle process after output: no replay, output and file references persist', () async {
    final processes = LocalProcessDriver();
    addTearDown(processes.dispose);
    final h = await ToolLoopHarness.create(processes: processes);
    final repository = await h.container.read(
      workspaceRepositoryProvider.future,
    );
    await repository.saveEnvironment(
      const RuntimeEnvironment(
        phase: EnvironmentPhase.ready,
        rootPath: '/fixture',
        revision: 'fixture',
      ),
    );
    final assistants = await h.container.read(
      assistantRepositoryProvider.future,
    );
    final assistant = await assistants.ensureDefault();
    await assistants.save(assistant.copyWith());
    final chats = await h.container.read(conversationRepositoryProvider.future);
    final chat = await chats.createConversation(assistantId: assistant.id);
    final workspace = (await repository.get(chat.workspaceId!))!;
    await h.controller().openConversation(chat.id);
    h.onConfirmation = (_) async => ToolDecision.approved;
    h.provider.turns.add(
      toolTurn(
        callId: 'shell-stop',
        toolName: 'shell',
        arguments: jsonEncode({
          'command': 'mkdir -p /workspace/output; printf saved > /workspace/output/saved.txt; printf partial; touch /workspace/started; sleep 60',
        }),
      ),
    );
    final send = h.controller().send('开始可停止任务');
    for (
      var i = 0;
      i < 200 && !await File('${workspace.rootPath}/started').exists();
      i++
    ) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(await File('${workspace.rootPath}/started').exists(), isTrue);
    h.controller().stop();
    await send;
    final run = await h.latestRun();
    expect(run.status, RunStatus.stopped);
    final records = await (await h.toolCalls()).getByRun(run.id);
    expect(records.single.status, ToolCallStatus.cancelled);
    expect(records.single.result, contains('partial'));
    expect(records.single.artifacts, hasLength(1));
    expect(processes.calls, hasLength(1));
    expect(processes.active, isEmpty);
    expect(repository.busy, isFalse);
    final attachments = await chats.attachmentsFor(chat.id);
    expect(attachments.any((a) => a.name == 'saved.txt'), isTrue);
  });
}
