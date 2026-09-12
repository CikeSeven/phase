import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/error/failure.dart';
import 'package:phase/data/models/agent_run.dart';
import 'package:phase/data/models/chat_message.dart';
import 'package:phase/data/models/tool_call_record.dart';
import 'package:phase/data/models/tool_policy.dart';
import 'package:phase/data/repositories/agent_run_repository.dart';
import 'package:phase/features/tools/run_recovery_controller.dart';
import 'package:phase/features/tools/tool.dart';

import 'tool_loop_harness.dart';

import 'run_recovery_fixture.dart';

void main() {
  test('启动将 executing 转为 unknown，保留 prepared，按原期限拒绝过期确认', () async {
    final echo = RecordingTool(name: 'echo');
    final h = await ToolLoopHarness.create(registry: ToolRegistry([echo]));
    final expired = DateTime.now().subtract(const Duration(seconds: 1));
    final run = await seedInterrupted(h, [
      ToolCallStatus.executing,
      ToolCallStatus.prepared,
      ToolCallStatus.awaitingConfirmation,
    ], expiresAt: expired);
    final recovery = h.container.read(runRecoveryControllerProvider.notifier);
    await recovery.initialize();
    final entry = h.container
        .read(runRecoveryControllerProvider)
        .requireValue
        .single;
    expect(entry.needsVerification, isTrue);
    expect(entry.calls.map((c) => c.status), [
      ToolCallStatus.unknown,
      ToolCallStatus.prepared,
      ToolCallStatus.rejected,
    ]);
    expect(entry.calls.last.decision, ToolDecision.expired);
    expect(
      entry.calls.last.confirmationExpiresAt!.millisecondsSinceEpoch,
      expired.millisecondsSinceEpoch ~/ 1000 * 1000,
    );
    expect(echo.executions, isEmpty);
    expect(h.provider.requests, isEmpty);
    await h.controller().openConversation(run.conversationId);
    await expectLater(
      h.controller().send('new work'),
      throwsA(isA<OperationFailure>()),
    );
    await recovery.stop(run.id);
    expect(
      h.container.read(runRecoveryControllerProvider).requireValue,
      isEmpty,
    );
    final records = await h.recordsByCall();
    expect(records['call-0']!.status, ToolCallStatus.unknown);
    expect(records['call-1']!.status, ToolCallStatus.cancelled);
    expect((await (await h.runs()).getById(run.id))!.status, RunStatus.stopped);
  });

  test('继续只执行未派发调用，保留配置、计数及未决确认期限', () async {
    final echo = RecordingTool(name: 'echo', policy: ToolPolicy.ask);
    final h = await ToolLoopHarness.create(registry: ToolRegistry([echo]));
    final expiry = DateTime.now().add(const Duration(seconds: 30));
    final run = await seedInterrupted(h, [
      ToolCallStatus.succeeded,
      ToolCallStatus.prepared,
      ToolCallStatus.awaitingConfirmation,
    ], expiresAt: expiry);
    final confirmed = <String>[];
    h.controller().onToolConfirmation = (request) async {
      confirmed.add(request.record.id);
      if (request.record.id == 'record-2') {
        expect(
          request.expiresAt.millisecondsSinceEpoch,
          expiry.millisecondsSinceEpoch ~/ 1000 * 1000,
        );
      }
      return ToolDecision.approved;
    };
    h.provider.turns.add(textTurn('finished'));
    await h.controller().resumeRun(run.id);
    expect(confirmed, ['record-1', 'record-2']);
    expect(echo.executions, hasLength(2));
    expect(h.provider.requests, hasLength(1));
    expect(h.provider.requests.single.temperature, 0.4);
    expect(h.provider.requests.single.maxOutputTokens, 300);
    expect(h.provider.requests.single.systemPrompt, 'saved prompt');
    final stored = (await (await h.runs()).getById(run.id))!;
    expect(stored.status, RunStatus.completed);
    expect(stored.turnCount, 2);
    expect(stored.modelAttemptCount, 2);
    expect(
      (await h.branch()).where((m) => m.role == ChatRole.tool),
      hasLength(3),
    );
  });

  test('未知结果先人工核验，再回填已知事实；不得重做动作', () async {
    final echo = RecordingTool(name: 'echo');
    final h = await ToolLoopHarness.create(registry: ToolRegistry([echo]));
    final run = await seedInterrupted(h, [ToolCallStatus.executing]);
    await expectLater(
      h.controller().resumeRun(run.id),
      throwsA(isA<OperationFailure>()),
    );
    final recovery = h.container.read(runRecoveryControllerProvider.notifier);
    await recovery.verify('record-0', succeeded: true, result: '目标已经保存');
    h.provider.turns.add(textTurn('verified'));
    await h.controller().resumeRun(run.id);
    expect(echo.executions, isEmpty);
    expect(h.provider.requests, hasLength(1));
    expect((await h.recordsByCall())['call-0']!.result, '人工核验：目标已经保存');
    expect(
      (await (await h.runs()).getById(run.id))!.status,
      RunStatus.completed,
    );
  });

  test('确认过期后继续只回填拒绝，迟到批准不能执行', () async {
    final echo = RecordingTool(name: 'echo', policy: ToolPolicy.ask);
    final h = await ToolLoopHarness.create(registry: ToolRegistry([echo]));
    final run = await seedInterrupted(h, [
      ToolCallStatus.awaitingConfirmation,
    ], expiresAt: DateTime.now().subtract(const Duration(seconds: 1)));
    final calls = await h.toolCalls();
    final decision = await calls.recordDecision(
      'record-0',
      ToolDecision.approved,
    );
    expect(decision.decision, ToolDecision.expired);
    h.provider.turns.add(textTurn('not executed'));
    await h.controller().resumeRun(run.id);
    expect(echo.executions, isEmpty);
    expect(
      (await h.recordsByCall())['call-0']!.status,
      ToolCallStatus.rejected,
    );
  });

  test('保存了工具成功但结果消息缺失时只补结果，不重试工具', () async {
    final echo = RecordingTool(name: 'echo');
    final h = await ToolLoopHarness.create(registry: ToolRegistry([echo]));
    final run = await seedInterrupted(h, [
      ToolCallStatus.succeeded,
    ], saveKnownResults: false);
    h.provider.turns.add(textTurn('finished'));
    await h.controller().resumeRun(run.id);
    expect(echo.executions, isEmpty);
    expect(
      (await h.branch()).where((m) => m.role == ChatRole.tool).single.text,
      'already done',
    );
  });

  test('恢复失败可重试，不把读取失败当作空列表', () async {
    final h = await ToolLoopHarness.create();
    final repository = _FlakyRuns(h.database);
    final container = ProviderContainer(
      overrides: [agentRunRepositoryProvider.overrideWith((_) => repository)],
    );
    addTearDown(container.dispose);
    final recovery = container.read(runRecoveryControllerProvider.notifier);
    await expectLater(recovery.initialize(), throwsA(isA<Failure>()));
    expect(container.read(runRecoveryControllerProvider).hasError, isTrue);
    await recovery.initialize();
    expect(container.read(runRecoveryControllerProvider).requireValue, isEmpty);
    expect(repository.attempts, 2);
  });
}

class _FlakyRuns extends AgentRunRepository {
  _FlakyRuns(super.db);
  int attempts = 0;
  @override
  Future<List<RecoveredRun>> recover({
    bool afterRestart = false,
    String? activeRunId,
  }) {
    if (++attempts == 1) return Future.error(const OperationFailure('读取失败'));
    return super.recover(afterRestart: afterRestart, activeRunId: activeRunId);
  }
}
