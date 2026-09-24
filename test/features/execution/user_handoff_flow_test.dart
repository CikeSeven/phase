import 'package:phase/data/models/permission_mode.dart';
import 'package:phase/features/tools/tool_call_display.dart';

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/error/failure.dart';
import 'package:phase/data/models/agent_run.dart';
import 'package:phase/data/models/chat_chunk.dart';
import 'package:phase/data/models/message_part.dart';
import 'package:phase/data/models/tool_call_record.dart';
import 'package:phase/features/execution/channel_driver.dart';
import 'package:phase/features/execution/execution_api.g.dart';
import 'package:phase/features/execution/execution_controller.dart';

import '../../support/fake_channel_driver.dart';
import '../tools/tool_loop_harness.dart';
import '../tools/run_recovery_fixture.dart';

void main() {
  test('计划模式禁止等待工具不会启服务；无效提示的失败记录也能安全显示', () async {
    final h = await ToolLoopHarness.create();
    await h.controller().setPermissionMode(PermissionMode.plan);
    h.provider.turns.addAll([
      toolTurn(
        callId: 'denied',
        toolName: 'wait_for_user',
        arguments: '{"prompt":42}',
      ),
      textTurn('等待工具已被禁止'),
    ]);
    await h.controller().send('请求等待');
    final driver = h.container.read(channelDriverProvider) as FakeChannelDriver;
    expect(driver.starts, isEmpty);
    final record = (await h.recordsByCall())['denied']!;
    expect(record.status, ToolCallStatus.rejected);
    expect(
      h.provider.requests.first.tools.map((t) => t.name),
      isNot(contains('wait_for_user')),
    );
    expect(ToolCallDisplay.detail(record), isNull);
    expect(ToolCallDisplay.fromRecord(record).call, contains('42'));
  });

  test('等待状态在重启后回收为中断结果，不重放等待或猜测用户已完成', () async {
    final h = await ToolLoopHarness.create();
    final driver = h.container.read(channelDriverProvider) as FakeChannelDriver;
    final run = await seedInterrupted(
      h,
      [ToolCallStatus.executing],
      toolName: 'wait_for_user',
      arguments: {'prompt': '请登录'},
      channel: ExecutionChannel.accessibility,
    );
    final runs = await h.runs();
    await runs.awaitUser(run.id, 'record-0');
    expect((await runs.unfinished()).single.status, RunStatus.awaitingUser);
    final conversations = await h.conversations();
    await expectLater(
      conversations.deleteConversation(run.conversationId),
      throwsA(isA<OperationFailure>()),
    );
    await expectLater(
      conversations.duplicateConversation(run.conversationId),
      throwsA(isA<OperationFailure>()),
    );
    final recovered = await runs.recover(afterRestart: true);
    expect(recovered.single.calls.single.status, ToolCallStatus.failed);
    expect(recovered.single.calls.single.result, contains('未收到继续指令'));
    expect(h.provider.requests, isEmpty);
    expect(driver.starts, isEmpty);
    h.provider.turns.add(textTurn('等待中断了，需要重新观察'));
    await h.controller().resumeRun(run.id);
    expect(h.provider.requests, hasLength(1));
    expect(driver.starts, isEmpty);
    expect((await h.recordsByCall())['call-0']!.status, ToolCallStatus.failed);
  });

  test('继续后的运行状态写入失败按存储故障收尾，不执行下一调用', () async {
    final h = await ToolLoopHarness.create();
    h.provider.turns.add(
      multiToolTurn([
        (
          callId: 'handoff',
          toolName: 'wait_for_user',
          arguments: '{"prompt":"请操作"}',
        ),
        (callId: 'after', toolName: 'system_info', arguments: '{}'),
      ]),
    );
    final sending = h.controller().send('操作后继续');
    await h.waitUntil(
      () => h.container.read(executionControllerProvider).userAction != null,
    );
    await h.database.customStatement('''
      CREATE TRIGGER fail_handoff_resume BEFORE UPDATE ON agent_runs
      WHEN OLD.status = 'awaitingUser' AND NEW.status = 'running'
      BEGIN SELECT RAISE(ABORT, 'test failure'); END;
    ''');
    final pending = h.container.read(executionControllerProvider).userAction!;
    h.container
        .read(executionControllerProvider.notifier)
        .continueRun(pending.runId, pending.toolCallId);
    await expectLater(sending, throwsA(isA<StorageFailure>()));
    expect((await h.latestRun()).finishReason, RunFinishReason.storageError);
    final records = await h.recordsByCall();
    expect(records['handoff']!.errorCode, 'storageError');
    expect(records['after']!.status, ToolCallStatus.prepared);
    expect(h.provider.requests, hasLength(1));
    expect(h.container.read(executionControllerProvider).userAction, isNull);
    expect(h.state().isGenerating, isFalse);
  });

  test('真实工具循环暂停同轮后续调用，继续后落库并交回模型', () async {
    final h = await ToolLoopHarness.create();
    final driver = h.container.read(channelDriverProvider) as FakeChannelDriver;
    h.provider.turns.addAll([
      multiToolTurn([
        (
          callId: 'handoff',
          toolName: 'wait_for_user',
          arguments: '{"prompt":"请完成登录，然后点击继续"}',
        ),
        (callId: 'after', toolName: 'system_info', arguments: '{}'),
      ]),
      textTurn('接下来我会重新观察界面'),
    ]);
    final sending = h.controller().send('帮我登录后继续');
    await h.waitUntil(
      () => h.container.read(executionControllerProvider).userAction != null,
    );
    final run = await h.latestRun();
    final waiting = h.container.read(executionControllerProvider).userAction!;
    expect(run.status, RunStatus.awaitingUser);
    expect(run.activeToolCallId, waiting.toolCallId);
    expect(h.provider.requests, hasLength(1));
    final before = await h.recordsByCall();
    expect(before['handoff']!.status, ToolCallStatus.executing);
    expect(before['after']!.status, ToolCallStatus.prepared);
    expect(driver.panels.last.phase, TaskPanelPhase.waitingUser);
    expect(driver.panels.last.userPrompt, '请完成登录，然后点击继续');
    final controller = h.container.read(executionControllerProvider.notifier);
    controller.setForeground(false);
    driver.eventsController.add(NativeContinue(run.id, 'old-call'));
    driver.eventsController.add(NativeContinue('old-run', waiting.toolCallId));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect((await h.recordsByCall())['after']!.status, ToolCallStatus.prepared);
    driver.eventsController.add(NativeContinue(run.id, waiting.toolCallId));
    driver.eventsController.add(NativeContinue(run.id, waiting.toolCallId));
    await sending;
    final records = await h.recordsByCall();
    expect(records['handoff']!.status, ToolCallStatus.succeeded);
    expect(records['after']!.status, ToolCallStatus.succeeded);
    expect(await h.resultTextOf(records['handoff']!), contains('不表示之前的操作一定成功'));
    expect(h.provider.requests, hasLength(2));
    expect((await h.latestRun()).status, RunStatus.completed);
    expect(h.container.read(executionControllerProvider).userAction, isNull);
    expect(driver.ends, [run.id]);
  });

  test('等待中停止保留取消结果，不执行后续动作或启动新模型轮', () async {
    final h = await ToolLoopHarness.create();
    h.provider.turns.add(
      multiToolTurn([
        (
          callId: 'handoff',
          toolName: 'wait_for_user',
          arguments: '{"prompt":"请手动操作"}',
        ),
        (callId: 'after', toolName: 'system_info', arguments: '{}'),
      ]),
    );
    final sending = h.controller().send('等待');
    await h.waitUntil(
      () => h.container.read(executionControllerProvider).userAction != null,
    );
    final pending = h.container.read(executionControllerProvider).userAction!;
    final control = h.container.read(executionControllerProvider.notifier);
    control.stopRun(pending.runId);
    expect(control.continueRun(pending.runId, pending.toolCallId), isFalse);
    await sending;
    final records = await h.recordsByCall();
    expect(records['handoff']!.status, ToolCallStatus.cancelled);
    expect(records['handoff']!.resultMessageId, isNotNull);
    expect(records['after']!.status, ToolCallStatus.cancelled);
    expect(h.provider.requests, hasLength(1));
    expect((await h.latestRun()).status, RunStatus.stopped);
    expect(h.container.read(executionControllerProvider).userAction, isNull);
  });

  test('提示无效不启动宿主；权限缺失回填失败而不悬空等待', () async {
    final h = await ToolLoopHarness.create();
    final driver = h.container.read(channelDriverProvider) as FakeChannelDriver;
    h.provider.turns.addAll([
      toolTurn(
        callId: 'bad',
        toolName: 'wait_for_user',
        arguments: '{"prompt":"${'字' * 501}"}',
      ),
      textTurn('提示过长'),
    ]);
    await h.controller().send('等待');
    expect(driver.starts, isEmpty);
    expect((await h.recordsByCall())['bad']!.errorCode, 'invalidArguments');
    driver.startFailure = const ExecutionFailure(
      ExecutionFailureCode.permissionRequired,
    );
    h.provider.turns.addAll([
      toolTurn(
        callId: 'unavailable',
        toolName: 'wait_for_user',
        arguments: '{"prompt":"请手动操作"}',
      ),
      textTurn('需要先启用设备任务权限'),
    ]);
    await h.controller().send('再次等待');
    expect(h.container.read(executionControllerProvider).userAction, isNull);
    expect(
      (await h.recordsByCall())['unavailable']!.errorCode,
      'permissionRequired',
    );
  });

  test('真实公开思考与完成快照到达面板，正文不与思考混合', () async {
    final h = await ToolLoopHarness.create();
    final driver = h.container.read(channelDriverProvider) as FakeChannelDriver;
    final response = StreamController<ChatChunk>();
    h.provider.turns.addAll([
      toolTurn(
        callId: 'handoff',
        toolName: 'wait_for_user',
        arguments: '{"prompt":"请操作"}',
      ),
      response.stream,
    ]);
    final sending = h.controller().send('等待后回答');
    await h.waitUntil(
      () => h.container.read(executionControllerProvider).userAction != null,
    );
    final pending = h.container.read(executionControllerProvider).userAction!;
    h.container
        .read(executionControllerProvider.notifier)
        .continueRun(pending.runId, pending.toolCallId);
    await h.waitUntil(() => h.provider.requests.length == 2);
    await h.waitUntil(
      () => driver.panels.last.phase == TaskPanelPhase.waitingModel,
    );
    expect(driver.panels.last.status, '执行了等待用户操作');
    expect(driver.panels.last.messages.last.label, '执行了等待用户操作');
    response.add(const ReasoningDelta(partId: 'r', text: '公开的思考片段'));
    await h.waitUntil(
      () => driver.panels.any((p) => p.phase == TaskPanelPhase.thinking),
    );
    expect(driver.panels.last.messages.last.text, '公开的思考片段');
    expect(
      driver.panels.last.messages.where(
        (entry) => entry.kind == TaskPanelMessageKind.text,
      ),
      isEmpty,
    );
    response.add(
      const PartEnd(
        partId: 'r',
        part: ReasoningPart(
          publicText: '最终公开摘要',
          providerData: {'encrypted': 'not-visible'},
        ),
      ),
    );
    response.add(const TextDelta(partId: 't', text: '这是正文'));
    await h.waitUntil(
      () => driver.panels.any((p) => p.phase == TaskPanelPhase.responding),
    );
    expect(
      driver.panels.last.messages
          .where((entry) => entry.kind == TaskPanelMessageKind.reasoning)
          .single
          .text,
      '最终公开摘要',
    );
    expect(driver.panels.last.messages.last.text, '这是正文');
    expect(driver.panels.last.messages.map((m) => m.kind), [
      TaskPanelMessageKind.tool,
      TaskPanelMessageKind.reasoning,
      TaskPanelMessageKind.text,
    ]);
    expect(
      driver.panels.last.messages.map((m) => m.id).toSet().length,
      driver.panels.last.messages.length,
    );
    expect(
      driver.panels.last.messages.map((m) => m.text).join(),
      isNot(contains('not-visible')),
    );
    response.add(const ResponseEnd());
    await response.close();
    await sending;
  });
}
