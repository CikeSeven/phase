import 'package:phase/data/models/permission_mode.dart';
import 'package:drift/drift.dart' show Value;
import 'package:phase/data/datasources/local/app_database.dart';
import 'package:phase/data/models/tool_source.dart';
import 'package:phase/features/mcp/mcp_tool.dart';
import 'package:phase/features/chat/planning/planning_tools.dart';

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/error/failure.dart';
import 'package:phase/data/models/agent_plan.dart';
import 'package:phase/data/models/agent_run.dart';
import 'package:phase/data/models/tool_call_record.dart';
import 'package:phase/data/models/tool_policy.dart';
import 'package:phase/data/repositories/assistant_repository.dart';
import 'package:phase/data/repositories/plan_repository.dart';
import 'package:phase/features/tools/tool.dart';

import '../../tools/tool_loop_harness.dart';

void main() {
  test('MCP 自称只读也不成为 Plan Mode 的宿主授权', () {
    final tool = McpTool(
      definition: ToolSnapshot(
        name: 'read_file',
        description: 'read-only safe',
        inputSchema: const {'type': 'object'},
        source: const ToolSource(
          kind: ToolSourceKind.mcp,
          id: 'server',
          originalName: 'read_file',
          definitionRevision: 'r1',
          effectClass: ToolEffectClass.readOnly,
        ),
      ),
      serverName: 'test',
    );
    expect(allowedInPlan(tool), isFalse);
  });

  test('计划模式宿主拒绝 shell、仿冒只读工具，提交后无额外模型轮', () async {
    final shell = RecordingTool(name: 'shell');
    final spoof = RecordingTool(name: 'read_file');
    final h = await ToolLoopHarness.create(
      registry: ToolRegistry([shell, spoof, const SystemInfoTool()]),
    );
    await h.controller().setPermissionMode(PermissionMode.plan);
    h.provider.turns.addAll([
      multiToolTurn([
        (callId: 'shell', toolName: 'shell', arguments: '{}'),
        (callId: 'spoof', toolName: 'read_file', arguments: '{}'),
      ]),
      toolTurn(
        callId: 'plan',
        toolName: 'submit_plan',
        arguments: jsonEncode({
          'title': '调查',
          'steps': ['读取文件', '报告结果'],
        }),
      ),
    ]);
    await h.controller().send('先制定计划');
    expect(shell.executions, isEmpty);
    expect(spoof.executions, isEmpty);
    expect(h.provider.requests.first.tools.map((t) => t.name).toSet(), {
      'system_info',
      'submit_plan',
      'read_history',
    });
    final records = await h.recordsByCall();
    expect(records['shell']!.status, ToolCallStatus.rejected);
    expect(records['spoof']!.status, ToolCallStatus.rejected);
    final run = await h.latestRun();
    expect(run.configuration.mode, PermissionMode.plan);
    expect(run.status, RunStatus.completed);
    expect(run.modelAttemptCount, 2);
    final plan = await PlanRepository(h.database)
        .watch(h.conversationId()!)
        .first;
    expect(plan.single.status, PlanStatus.draft);
    expect(plan.single.sourceMessageId, records['plan']!.assistantMessageId);
  });

  test('修订后旧批准失败，新批准原子创建运行并读取最新权限，动作仍询问', () async {
    final action = RecordingTool(name: 'write_file', policy: ToolPolicy.ask);
    final h = await ToolLoopHarness.create(registry: ToolRegistry([action]));
    await h.controller().setPermissionMode(PermissionMode.plan);
    h.provider.turns.add(
      toolTurn(
        callId: 'p',
        toolName: 'submit_plan',
        arguments: '{"title":"原计划","steps":["原步骤"]}',
      ),
    );
    await h.controller().send('请规划');
    final repository = PlanRepository(h.database);
    final old = (await repository.watch(h.conversationId()!).first).single;
    final latest = await repository.edit(old.id, old.revision, '新计划', [
      '写测试文件',
    ]);
    await expectLater(
      h.controller().approvePlan(old),
      throwsA(isA<OperationFailure>()),
    );
    expect((await h.database.select(h.database.agentRuns).get()), hasLength(1));
    final assistants = await h.container.read(
      assistantRepositoryProvider.future,
    );
    final assistant = await assistants.ensureDefault();
    await assistants.save(assistant.copyWith(systemPrompt: '最新配置'));
    h.provider.turns.addAll([
      toolTurn(callId: 'write', toolName: 'write_file', arguments: '{}'),
      textTurn('完成'),
    ]);
    var asks = 0;
    h.onConfirmation = (_) async {
      asks++;
      return ToolDecision.approved;
    };
    await h.controller().approvePlan(latest);
    expect(asks, 1);
    expect(action.executions, hasLength(1));
    final run = await h.latestRun();
    expect(run.configuration.mode, PermissionMode.basic);
    expect(run.configuration.planId, latest.id);
    expect(run.configuration.planRevision, 2);
    expect(run.configuration.systemPrompt, '最新配置');
    expect(
      h.provider.requests[1].messages.expand((m) => m.parts).toString(),
      isNotEmpty,
    );
    expect((await h.branch()).any((m) => m.text.contains('新计划')), isTrue);
    await expectLater(
      h.controller().approvePlan(latest),
      throwsA(isA<OperationFailure>()),
    );
    await expectLater(
      repository.cancel(latest.id, latest.revision),
      throwsA(isA<OperationFailure>()),
    );
    expect((await repository.latest(latest.id)).status, PlanStatus.approved);
    final revised = await repository.edit(latest.id, 2, '再次修改', ['观察']);
    expect(revised.status, PlanStatus.draft);
    expect(revised.executionRunId, isNull);
    await repository.cancel(revised.id, revised.revision);
    await expectLater(
      h.controller().approvePlan(revised),
      throwsA(isA<OperationFailure>()),
    );
  });

  test('重启前已保存计划与工具结果，恢复只收尾，不再请求模型或提交修订', () async {
    final h = await ToolLoopHarness.create(registry: ToolRegistry([]));
    await h.controller().setPermissionMode(PermissionMode.plan);
    h.provider.turns.add(
      toolTurn(
        callId: 'plan',
        toolName: 'submit_plan',
        arguments: '{"title":"等待批准","steps":["读取现状"]}',
      ),
    );
    await h.controller().send('只规划');
    final run = await h.latestRun();
    // 模拟工具结果已落库、运行终态尚未保存时进程终止。
    await (h.database.update(
      h.database.agentRuns,
    )..where((t) => t.id.equals(run.id))).write(
      const AgentRunsCompanion(
        status: Value(RunStatus.running),
        maxTurns: Value(1),
        finishReason: Value(null),
        finishedAt: Value(null),
      ),
    );
    await h.controller().resumeRun(run.id);
    expect(h.provider.requests, hasLength(1));
    expect(
      (await (await h.runs()).getById(run.id))!.status,
      RunStatus.completed,
    );
    final plans = await PlanRepository(h.database)
        .watch(h.conversationId()!)
        .first;
    expect(plans.single.revision, 1);
    expect(plans.single.status, PlanStatus.draft);
  });

  test('来源分支变化不能批准；无效结构不产生计划卡；复制独立归属', () async {
    final h = await ToolLoopHarness.create(registry: ToolRegistry([]));
    await h.controller().setPermissionMode(PermissionMode.plan);
    h.provider.turns.addAll([
      toolTurn(
        callId: 'bad',
        toolName: 'submit_plan',
        arguments: '{"title":"","steps":[]}',
      ),
      toolTurn(
        callId: 'good',
        toolName: 'submit_plan',
        arguments: '{"title":"有效","steps":["观察"]}',
      ),
    ]);
    await h.controller().send('计划');
    final originalId = h.conversationId()!;
    final repository = PlanRepository(h.database);
    final p = (await repository.watch(originalId).first).single;
    expect((await h.recordsByCall())['bad']!.status, ToolCallStatus.failed);
    final copyId = await h.controller().duplicateFrom(originalId);
    final copied = (await repository.watch(copyId).first).single;
    expect(copied.id, isNot(p.id));
    expect(copied.sourceRunId, isNot(p.sourceRunId));
    expect(copied.sourceMessageId, isNot(p.sourceMessageId));
    await h.controller().openConversation(originalId);
    final branch = await h.branch();
    await (await h.conversations()).setCurrentMessage(
      originalId,
      branch.first.id,
    );
    await expectLater(
      h.controller().approvePlan(p),
      throwsA(isA<OperationFailure>()),
    );
  });
}
