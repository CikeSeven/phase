import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/error/failure.dart';
import 'package:phase/data/models/agent_run.dart';
import 'package:phase/data/models/chat_message.dart';
import 'package:phase/data/models/chat_request.dart';
import 'package:phase/data/models/tool_call_record.dart';
import 'package:phase/data/models/tool_policy.dart';
import 'package:phase/data/repositories/agent_run_repository.dart';
import 'package:phase/features/chat/chat_controller.dart';
import 'package:phase/features/tools/run_recovery_controller.dart';
import 'package:phase/features/tools/tool.dart';

import 'tool_loop_harness.dart';

import 'run_recovery_fixture.dart';

void main() {
  test('启动将中断调用转为失败，保留 prepared，按原期限拒绝过期确认', () async {
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
    expect(entry.calls.map((c) => c.status), [
      ToolCallStatus.failed,
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
    expect(records['call-0']!.status, ToolCallStatus.failed);
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
    h.onConfirmation = (request) async {
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
    expect(h.provider.requests.single.systemPrompt, startsWith('saved prompt'));
    expect(h.provider.requests.single.systemPrompt, contains('工具响应和错误由你处理'));
    final stored = (await (await h.runs()).getById(run.id))!;
    expect(stored.status, RunStatus.completed);
    expect(stored.turnCount, 2);
    expect(stored.modelAttemptCount, 2);
    expect(
      (await h.branch()).where((m) => m.role == ChatRole.tool),
      hasLength(3),
    );
  });

  test('中断后的失败自动回填给 AI，不填写状态也不重发旧动作', () async {
    final echo = RecordingTool(name: 'echo');
    final h = await ToolLoopHarness.create(registry: ToolRegistry([echo]));
    final run = await seedInterrupted(h, [ToolCallStatus.executing]);
    h.provider.turns.add(textTurn('我会根据错误和当前状态继续处理'));
    await h.controller().resumeRun(run.id);
    expect(echo.executions, isEmpty);
    expect(h.provider.requests, hasLength(1));
    expect((await h.recordsByCall())['call-0']!.result, contains('上次运行中断'));
    expect(
      (await h.branch())
          .where((message) => message.role == ChatRole.tool)
          .single
          .text,
      contains('上次运行中断'),
    );
    expect(
      (await (await h.runs()).getById(run.id))!.status,
      RunStatus.completed,
    );
  });

  test('不限轮次的长任务在第 30 轮后恢复，只回填已有结果并继续', () async {
    final echo = RecordingTool(name: 'echo');
    final h = await ToolLoopHarness.create(registry: ToolRegistry([echo]));
    final run = await seedInterrupted(h, [
      ToolCallStatus.succeeded,
    ], turnCount: 30);
    h.provider.turns.add(textTurn('根据已有结果完成任务'));

    await h.controller().resumeRun(run.id);

    expect(echo.executions, isEmpty);
    expect(h.provider.requests, hasLength(1));
    final result = h.provider.requests.single.messages.last.parts
        .whereType<ResolvedToolResult>()
        .single;
    expect(result.callId, 'call-0');
    expect(result.content, 'already done');
    final stored = (await (await h.runs()).getById(run.id))!;
    expect(stored.status, RunStatus.completed);
    expect(stored.turnCount, 31);
    expect(stored.modelAttemptCount, 31);
    expect(stored.maxTurns, 0);
    expect((await h.branch()).last.text, '根据已有结果完成任务');
  });

  for (final spent in [1, 2, 3]) {
    test('显式 2 轮预算已用 $spent 轮：耗尽时持久显示原因，不能伪装完成', () async {
      final echo = RecordingTool(name: 'echo');
      final h = await ToolLoopHarness.create(registry: ToolRegistry([echo]));
      final run = await seedInterrupted(
        h,
        [ToolCallStatus.succeeded],
        turnCount: spent,
        maxTurns: 2,
      );
      h.onConfirmation = (_) async => ToolDecision.approved;
      h.provider.turns.add(
        toolTurn(callId: 'next-call', toolName: 'echo', arguments: '{}'),
      );

      await h.controller().resumeRun(run.id);

      final expectedRequests = spent < 2 ? 1 : 0;
      expect(h.provider.requests, hasLength(expectedRequests));
      expect(echo.executions, hasLength(expectedRequests));
      final stored = (await (await h.runs()).getById(run.id))!;
      expect(stored.status, RunStatus.failed);
      expect(stored.finishReason, RunFinishReason.turnLimit);
      expect(stored.turnCount, spent + expectedRequests);
      expect(stored.modelAttemptCount, spent + expectedRequests);
      expect(stored.activeToolCallId, isNull);
      final branch = await h.branch();
      expect(branch.last.role, ChatRole.assistant);
      expect(branch.last.status, MessageStatus.failed);
      expect(branch.last.text, contains('应用已达到本次运行的 2 轮上限'));
      expect(branch.last.text, contains('并不代表工作已完成'));
      expect(branch.last.parentId, branch[branch.length - 2].id);
      expect(stored.currentMessageId, branch.last.id);
      final repository = await h.conversations();
      final thread = (await repository.getThread(run.conversationId))!;
      final visible = visibleMessages(thread, h.state());
      expect(visible.last.status, MessageStatus.failed);
      expect(visible.last.text, contains('可发送“继续”'));
      expect(h.state().isGenerating, isFalse);
    });
  }

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
