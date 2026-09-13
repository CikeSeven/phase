import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:phase/data/models/agent_run.dart';
import 'package:phase/data/models/chat_request.dart';
import 'package:phase/data/models/tool_call_record.dart';
import 'package:phase/data/models/tool_policy.dart';
import 'package:phase/features/execution/channel_driver.dart';
import 'package:phase/features/execution/execution_api.g.dart';
import 'package:phase/features/execution/platform_tools.dart';
import 'package:phase/features/tools/run_recovery_controller.dart';
import 'package:phase/features/tools/tool.dart';

import '../../support/fake_channel_driver.dart';
import 'tool_loop_harness.dart';

class _AllowedApplicationTool extends ApplicationTool {
  _AllowedApplicationTool(super.action, super.driver);
  @override
  ToolPolicy get defaultPolicy => ToolPolicy.allow;
}

void main() {
  test('读取抛出异常直接给 AI 错误，AI 可再次读取并回答，不进入人工核验', () async {
    final read = RecordingTool(name: 'read_file');
    var attempts = 0;
    read.executeAsync = (_, _) async {
      if (++attempts == 1) throw StateError('fake private error detail');
      return const ToolOutcome.success('真实读取内容');
    };
    final h = await ToolLoopHarness.create(registry: ToolRegistry([read]));
    h.onConfirmation = (_) => throw StateError('不应要求用户处理读取结果');
    h.provider.turns.addAll([
      toolTurn(callId: 'first', toolName: 'read_file', arguments: '{}'),
      toolTurn(callId: 'retry', toolName: 'read_file', arguments: '{}'),
      textTurn('已根据读取内容回答'),
    ]);
    await h.controller().send('读取文件');
    final calls = await h.recordsByCall();
    expect(calls['first']!.status, ToolCallStatus.failed);
    expect(calls['first']!.resultMessageId, isNotNull);
    expect(calls['retry']!.status, ToolCallStatus.succeeded);
    final error = h.provider.requests[1].messages
        .expand((m) => m.parts)
        .whereType<ResolvedToolResult>()
        .single;
    expect(error.isError, isTrue);
    expect(error.content, '没有收到这次操作的完整结果。');
    expect(error.content, isNot(contains('fake private error detail')));
    expect((await h.latestRun()).status, RunStatus.completed);
    expect(
      h.container.read(runRecoveryControllerProvider).requireValue,
      isEmpty,
    );
  });

  test('点击响应失败保留实际回调，AI 自行读取界面，不要求用户填写状态', () async {
    late FakeChannelDriver driver;
    final h = await ToolLoopHarness.create(
      registry: ToolRegistry([
        _AllowedApplicationTool(ExecutionAction.clickNode, () => driver),
        _AllowedApplicationTool(ExecutionAction.inspectUi, () => driver),
      ]),
    );
    driver = h.container.read(channelDriverProvider) as FakeChannelDriver;
    final actions = <ExecutionAction>[];
    driver.executeHandler = (request, _) async {
      actions.add(request.action);
      return ExecutionResult(
        toolCallId: request.toolCallId,
        status: request.action == ExecutionAction.clickNode
            ? ExecutionStatus.failed
            : ExecutionStatus.succeeded,
        result: request.action == ExecutionAction.clickNode
            ? {'actionAccepted': true, 'reason': '响应超时'}
            : {
                'snapshot': {
                  'id': 'current',
                  'nodes': [],
                  'packageName': 'fixture.app',
                },
              },
        artifacts: [],
        error: request.action == ExecutionAction.clickNode
            ? ChannelError.timeout
            : null,
      );
    };
    h.onConfirmation = (_) => throw StateError('直接执行策略不应弹确认');
    h.provider.turns.addAll([
      toolTurn(
        callId: 'click',
        toolName: 'click_node',
        arguments: jsonEncode({
          'packageName': 'fixture.app',
          'snapshotId': 'before',
          'nodeId': 'n1',
        }),
      ),
      toolTurn(
        callId: 'observe',
        toolName: 'inspect_ui',
        arguments: '{"packageName":"fixture.app"}',
      ),
      textTurn('我已读取当前界面，没有重复点击'),
    ]);
    await h.controller().send('点击后查看页面');
    expect(actions, [ExecutionAction.clickNode, ExecutionAction.inspectUi]);
    final calls = await h.recordsByCall();
    expect(calls['click']!.status, ToolCallStatus.failed);
    expect(calls['click']!.result, contains('actionAccepted'));
    expect(calls['observe']!.status, ToolCallStatus.succeeded);
    expect(h.provider.requests, hasLength(3));
    expect((await h.latestRun()).status, RunStatus.completed);
    expect(
      h.container.read(runRecoveryControllerProvider).requireValue,
      isEmpty,
    );
  });
}
