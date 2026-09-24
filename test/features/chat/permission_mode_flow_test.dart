import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/error/failure.dart';
import 'package:phase/data/models/permission_mode.dart';
import 'package:phase/data/models/tool_call_record.dart';
import 'package:phase/data/models/tool_policy.dart';
import 'package:phase/data/models/agent_plan.dart';
import 'package:phase/data/models/workspace.dart';
import 'package:phase/data/repositories/assistant_repository.dart';
import 'package:phase/data/repositories/plan_repository.dart';
import 'package:phase/data/repositories/skill_repository.dart';
import 'package:phase/data/repositories/workspace_repository.dart';
import 'package:phase/features/chat/chat_controller.dart';
import 'package:phase/features/tools/tool.dart';

import '../tools/tool_loop_harness.dart';
import '../skills/skill_test_support.dart' show sampleSkill;
import '../workspace/local_process_driver.dart';

void main() {
  test('批准落库失败时计划、会话模式和分支整体回滚，可重试', () async {
    final h = await ToolLoopHarness.create(registry: ToolRegistry([]));
    await h.controller().setPermissionMode(PermissionMode.fullAccess);
    await h.controller().setPermissionMode(PermissionMode.plan);
    h.provider.turns.add(
      toolTurn(
        callId: 'plan',
        toolName: 'submit_plan',
        arguments: '{"title":"计划","steps":["执行"]}',
      ),
    );
    await h.controller().send('规划');
    final id = h.conversationId()!;
    final repository = await h.conversations();
    final before = (await repository.getThread(id))!;
    final plans = PlanRepository(h.database);
    final plan = (await plans.watch(id).first).single;
    await h.database.customStatement(
      "CREATE TRIGGER reject_execution_run BEFORE INSERT ON agent_runs BEGIN SELECT RAISE(ABORT, 'test failure'); END",
    );
    await expectLater(
      h.controller().approvePlan(plan),
      throwsA(isA<StorageFailure>()),
    );
    final after = (await repository.getThread(id))!;
    expect(after.conversation.permissions, before.conversation.permissions);
    expect(after.currentMessageId, before.currentMessageId);
    expect(after.messages.map((m) => m.id), before.messages.map((m) => m.id));
    expect((await plans.latest(plan.id)).status, PlanStatus.draft);
    expect(await h.database.select(h.database.agentRuns).get(), hasLength(1));
    await h.database.customStatement('DROP TRIGGER reject_execution_run');
    h.provider.turns.add(textTurn('执行完成'));
    await h.controller().approvePlan(plan);
    expect(
      (await repository.getThread(id))!.conversation.permissions.mode,
      PermissionMode.fullAccess,
    );
  });

  for (final mode in [PermissionMode.basic, PermissionMode.fullAccess]) {
    test('${mode.name} Skill 读取无需确认，复制按文件写入策略且不执行脚本', () async {
      final processes = LocalProcessDriver();
      addTearDown(processes.dispose);
      final h = await ToolLoopHarness.create(processes: processes);
      final workspaces = await h.container.read(
        workspaceRepositoryProvider.future,
      );
      await workspaces.saveEnvironment(
        RuntimeEnvironment(
          phase: EnvironmentPhase.ready,
          rootPath: h.tempDir.path,
          revision: 'fixture',
        ),
      );
      final source = await Directory('${h.tempDir.path}/sample-skill').create();
      await File('${source.path}/SKILL.md').writeAsString(sampleSkill);
      final skills = await h.container.read(skillRepositoryProvider.future);
      final package = await skills.packages.prepare(
        source.path,
        zip: false,
        cancellation: RunCancellation(),
      );
      final skill = await skills.install(package, RunCancellation());
      await package.discard();
      final assistants = await h.container.read(
        assistantRepositoryProvider.future,
      );
      await assistants.save(
        (await assistants.ensureDefault()).copyWith(skillIds: {skill.id}),
      );
      await h.controller().setPermissionMode(mode);
      final confirmed = <String>[];
      h.onConfirmation = (request) async {
        confirmed.add(request.record.toolName);
        return ToolDecision.approved;
      };
      h.provider.turns.addAll([
        toolTurn(
          callId: 'read',
          toolName: 'read_skill',
          arguments: jsonEncode({'skillId': skill.id}),
        ),
        toolTurn(
          callId: 'copy',
          toolName: 'prepare_skill',
          arguments: jsonEncode({'skillId': skill.id}),
        ),
        textTurn('已准备'),
      ]);
      await h.controller().send('读取并复制 Skill');
      expect(
        confirmed,
        mode == PermissionMode.basic ? ['prepare_skill'] : isEmpty,
      );
      final records = await h.recordsByCall();
      expect(records['read']!.status, ToolCallStatus.succeeded);
      expect(records['copy']!.status, ToolCallStatus.succeeded);
      final copied = jsonDecode(records['copy']!.result!) as Map;
      expect(copied['executed'], isFalse);
      expect(processes.calls, isEmpty);
    });
  }

  test('空白模式是草稿；首发保存、切助手不改档、复制和新聊天独立', () async {
    final h = await ToolLoopHarness.create(registry: ToolRegistry([]));
    final controller = h.controller();
    final conversations = await h.conversations();
    await controller.setPermissionMode(PermissionMode.fullAccess);
    await controller.setPermissionMode(PermissionMode.plan);
    expect(await conversations.watchConversations().first, isEmpty);
    expect(await h.database.select(h.database.workspaces).get(), isEmpty);
    final assistant = await controller.createAssistant(name: '另一个助手');
    await controller.selectAssistant(assistant.id);
    expect(
      h.container.read(conversationPermissionsProvider).value,
      const PermissionSelection(
        mode: PermissionMode.plan,
        lastExecutionMode: PermissionMode.fullAccess,
      ),
    );
    h.provider.turns.add(textTurn('只规划'));
    await controller.send('规划');
    final first = h.conversationId()!;
    final saved = (await conversations.getThread(first))!.conversation;
    expect(saved.permissions.mode, PermissionMode.plan);
    expect(saved.permissions.lastExecutionMode, PermissionMode.fullAccess);
    expect(
      (await h.latestRun()).configuration.planExecutionMode,
      PermissionMode.fullAccess,
    );

    await controller.setPermissionMode(PermissionMode.basic);
    final copyId = await controller.duplicateFrom(first);
    await controller.setPermissionMode(PermissionMode.fullAccess);
    expect(
      (await conversations.getThread(first))!.conversation.permissions.mode,
      PermissionMode.basic,
    );
    expect(
      (await conversations.getThread(copyId))!.conversation.permissions.mode,
      PermissionMode.fullAccess,
    );
    await controller.openConversation(first);
    await h.waitUntil(
      () =>
          h.container.read(conversationPermissionsProvider).value?.mode ==
          PermissionMode.basic,
    );
    controller.startNewConversation();
    expect(
      h.container.read(conversationPermissionsProvider).value,
      const PermissionSelection(),
    );
    expect(await conversations.watchConversations().first, hasLength(2));
  });

  test('保存中不能发送或重复切换；切会话和改助手不会被迟到保存覆写', () async {
    final gate = Completer<void>();
    final entered = Completer<void>();
    final h = await ToolLoopHarness.create(
      beforePermissionSave: () async {
        entered.complete();
        await gate.future;
      },
    );
    final repository = await h.conversations();
    final a = await repository.createConversation();
    final b = await repository.createConversation();
    await h.controller().openConversation(a.id);
    final saving = h.controller().setPermissionMode(PermissionMode.fullAccess);
    await entered.future;
    expect(h.state().savingPermissionMode, isTrue);
    await expectLater(
      h.controller().send('不能按旧档发送'),
      throwsA(isA<OperationFailure>()),
    );
    await expectLater(
      h.controller().regenerate(),
      throwsA(isA<OperationFailure>()),
    );
    await expectLater(
      h.controller().setPermissionMode(PermissionMode.plan),
      throwsA(isA<OperationFailure>()),
    );
    final assistant = await h.controller().createAssistant(name: '并发选择');
    await h.controller().selectAssistant(assistant.id);
    await h.controller().openConversation(b.id);
    gate.complete();
    await saving;
    expect(h.conversationId(), b.id);
    expect(h.state().savingPermissionMode, isFalse);
    expect(
      (await repository.getThread(a.id))!.conversation.permissions.mode,
      PermissionMode.fullAccess,
    );
    expect(
      (await repository.getThread(a.id))!.conversation.assistantId,
      assistant.id,
    );
    expect(
      (await repository.getThread(b.id))!.conversation.permissions.mode,
      PermissionMode.basic,
    );
    expect(h.provider.requests, isEmpty);
  });

  test('模式保存失败保留原档与返回档，解除故障后可重试', () async {
    var fail = true;
    final h = await ToolLoopHarness.create(
      beforePermissionSave: () async {
        if (fail) throw const StorageFailure('保存权限模式失败');
      },
    );
    final repository = await h.conversations();
    final conversation = await repository.createConversation();
    await h.controller().openConversation(conversation.id);
    await expectLater(
      h.controller().setPermissionMode(PermissionMode.fullAccess),
      throwsA(isA<StorageFailure>()),
    );
    expect(
      (await repository.getThread(conversation.id))!.conversation.permissions,
      const PermissionSelection(),
    );
    expect(h.state().savingPermissionMode, isFalse);
    fail = false;
    await h.controller().setPermissionMode(PermissionMode.fullAccess);
    expect(
      (await repository.getThread(conversation.id))!.conversation.permissions,
      const PermissionSelection(
        mode: PermissionMode.fullAccess,
        lastExecutionMode: PermissionMode.fullAccess,
      ),
    );
  });

  test('A 的运行快照固定；切到 B 和新聊天不会被运行完成覆写', () async {
    final h = await ToolLoopHarness.create(registry: ToolRegistry([]));
    final repository = await h.conversations();
    final b = await repository.createConversation();
    final output = StreamController<Never>();
    h.provider.turns.add(output.stream);
    await h.controller().setPermissionMode(PermissionMode.fullAccess);
    final sending = h.controller().send('保持运行');
    await h.waitUntil(() => h.provider.requests.isNotEmpty);
    final a = h.conversationId()!;
    await expectLater(
      h.controller().setPermissionMode(PermissionMode.basic),
      throwsA(isA<OperationFailure>()),
    );
    await h.controller().openConversation(b.id);
    await h.waitUntil(
      () =>
          h.container.read(conversationPermissionsProvider).value?.mode ==
          PermissionMode.basic,
    );
    h.controller().startNewConversation();
    h.controller().stop();
    await sending;
    await output.close();
    expect(
      h.container.read(conversationPermissionsProvider).value,
      const PermissionSelection(),
    );
    expect(
      (await repository.getThread(a))!.conversation.permissions.mode,
      PermissionMode.fullAccess,
    );
    final runs = await h.database.select(h.database.agentRuns).get();
    expect(runs.single.configurationJson, contains('fullAccess'));
  });

  for (final executionMode in [
    PermissionMode.basic,
    PermissionMode.fullAccess,
  ]) {
    test('批准计划恢复来源的 ${executionMode.name}，不是后来选择的档位', () async {
      final write = RecordingTool(name: 'write_file', policy: ToolPolicy.ask);
      final h = await ToolLoopHarness.create(registry: ToolRegistry([write]));
      await h.controller().setPermissionMode(executionMode);
      await h.controller().setPermissionMode(PermissionMode.plan);
      h.provider.turns.add(
        toolTurn(
          callId: 'p',
          toolName: 'submit_plan',
          arguments: '{"title":"保存文件","steps":["写入"]}',
        ),
      );
      await h.controller().send('先规划');
      final repository = await h.conversations();
      final id = h.conversationId()!;
      final plan = (await PlanRepository(h.database).watch(id).first).single;
      await h.controller().setPermissionMode(
        executionMode == PermissionMode.basic
            ? PermissionMode.fullAccess
            : PermissionMode.basic,
      );
      var asks = 0;
      h.onConfirmation = (_) async {
        asks++;
        return ToolDecision.approved;
      };
      h.provider.turns.addAll([
        toolTurn(callId: 'write', toolName: 'write_file', arguments: '{}'),
        textTurn('完成'),
      ]);
      await h.controller().approvePlan(plan);
      expect(asks, executionMode == PermissionMode.basic ? 1 : 0);
      expect(write.executions, hasLength(1));
      expect((await h.latestRun()).configuration.mode, executionMode);
      expect(
        (await repository.getThread(id))!.conversation.permissions.mode,
        executionMode,
      );
      final count =
          (await h.database.select(h.database.agentRuns).get()).length;
      await h.controller().setPermissionMode(PermissionMode.plan);
      await expectLater(
        h.controller().approvePlan(plan),
        throwsA(isA<OperationFailure>()),
      );
      expect(
        (await repository.getThread(id))!.conversation.permissions.mode,
        PermissionMode.plan,
      );
      expect(
        await h.database.select(h.database.agentRuns).get(),
        hasLength(count),
      );
    });
  }
}
