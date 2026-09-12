import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/error/failure.dart';
import 'package:phase/data/models/agent_run.dart';
import 'package:phase/data/models/tool_call_record.dart';
import 'package:phase/data/models/tool_policy.dart';
import 'package:phase/features/execution/channel_driver.dart';
import 'package:phase/features/execution/execution_controller.dart';
import 'package:phase/features/tools/tool.dart';

import '../../support/fake_channel_driver.dart';
import '../tools/tool_loop_harness.dart';

void main() {
  test('原生停止进入真实 Loop 取消与落库，工具结果保留且不启动下一轮', () async {
    final tool = RecordingTool(
      name: 'device_action',
      channel: ExecutionChannel.accessibility,
    );
    final entered = Completer<void>();
    tool.executeAsync = (_, cancellation) async {
      entered.complete();
      await cancellation.whenCancelled;
      return const ToolOutcome.unknown('动作已派发，结果需核验');
    };
    final h = await ToolLoopHarness.create(registry: ToolRegistry([tool]));
    final driver = h.container.read(channelDriverProvider) as FakeChannelDriver;
    h.provider.turns.add(
      toolTurn(callId: 'provider-call', toolName: tool.name, arguments: '{}'),
    );
    final sending = h.controller().send('执行设备动作');
    await entered.future;
    final run = await h.latestRun();
    expect(driver.starts, [run.id]);
    driver.eventsController.add(NativeStop(run.id));
    await sending;
    final record = (await h.recordsByCall())['provider-call']!;
    expect(record.channel, ExecutionChannel.accessibility);
    expect(record.status, ToolCallStatus.unknown);
    expect(record.id, isNot('provider-call'));
    expect(driver.ends, [run.id]);
    expect(h.provider.requests, hasLength(1));
    expect(h.state().isGenerating, isFalse);
    expect(h.container.read(executionControllerProvider).runId, isNull);
  });

  test('启动服务失败保存明确执行错误且不执行工具，下一次发送仍可用', () async {
    final tool = RecordingTool(
      name: 'device_action',
      channel: ExecutionChannel.accessibility,
    );
    final h = await ToolLoopHarness.create(registry: ToolRegistry([tool]));
    final driver = h.container.read(channelDriverProvider) as FakeChannelDriver;
    driver.startFailure = const ExecutionFailure(
      ExecutionFailureCode.permissionRequired,
    );
    h.provider.turns.add(
      toolTurn(callId: 'provider-call', toolName: tool.name, arguments: '{}'),
    );
    await expectLater(
      h.controller().send('执行设备动作'),
      throwsA(isA<ExecutionFailure>()),
    );
    expect(tool.executions, isEmpty);
    final record = (await h.recordsByCall())['provider-call']!;
    expect(record.status, ToolCallStatus.failed);
    expect(record.errorCode, 'permissionRequired');
    expect((await h.latestRun()).finishReason, RunFinishReason.executionError);
    expect(h.state().isGenerating, isFalse);
    h.provider.turns.add(textTurn('仅回答，不执行'));
    await h.controller().send('只回答');
    expect((await h.latestRun()).status, RunStatus.completed);
    expect(driver.starts, hasLength(1));
  });

  test('无效参数不启动服务；拒绝设备动作不会执行，任务结束释放已启动宿主', () async {
    final tool = RecordingTool(
      name: 'device_action',
      channel: ExecutionChannel.accessibility,
      policy: ToolPolicy.ask,
      schema: const {
        'type': 'object',
        'properties': {
          'node': {'type': 'string'},
        },
        'required': ['node'],
      },
    );
    final h = await ToolLoopHarness.create(registry: ToolRegistry([tool]));
    final driver = h.container.read(channelDriverProvider) as FakeChannelDriver;
    h.provider.turns.addAll([
      toolTurn(callId: 'bad', toolName: tool.name, arguments: '{}'),
      textTurn('参数不足'),
    ]);
    await h.controller().send('无效动作');
    expect(driver.starts, isEmpty);
    h.onConfirmation = (_) async => ToolDecision.rejected;
    h.provider.turns.addAll([
      toolTurn(
        callId: 'ask',
        toolName: tool.name,
        arguments: '{"node":"fixed"}',
      ),
      textTurn('已拒绝'),
    ]);
    await h.controller().send('需确认动作');
    expect(tool.executions, isEmpty);
    expect(driver.starts, hasLength(1));
    expect(driver.ends, driver.starts);
    expect((await h.recordsByCall())['ask']!.status, ToolCallStatus.rejected);
  });
}
