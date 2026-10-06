import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:phase/data/datasources/local/settings_storage.dart';
import 'package:phase/data/models/permission_mode.dart';
import 'package:phase/data/models/tool_call_record.dart';
import 'package:phase/data/models/tool_permission.dart';
import 'package:phase/data/models/tool_policy.dart';
import 'package:phase/data/models/tool_source.dart';
import 'package:phase/features/execution/channel_driver.dart';
import 'package:phase/features/execution/execution_api.g.dart';
import 'package:phase/features/tools/tool.dart';

import '../../support/fake_channel_driver.dart';
import 'tool_loop_harness.dart';

void main() {
  const rule = ToolPermissionRule(
    sourceKind: ToolSourceKind.builtIn,
    sourceId: 'builtIn',
    toolName: 'open_app',
    policy: ToolPolicy.ask,
  );

  test('真实聊天固定规则快照，模型输出期间放宽只影响下一运行', () async {
    final h = await ToolLoopHarness.create(
      permissionRules: [rule.withPolicy(ToolPolicy.deny)],
    );
    await h.controller().setPermissionMode(PermissionMode.fullAccess);
    final driver = h.container.read(channelDriverProvider) as FakeChannelDriver;
    var dispatched = 0;
    driver.executeHandler = (request, _) async {
      dispatched++;
      return ExecutionResult(
        toolCallId: request.toolCallId,
        status: ExecutionStatus.succeeded,
        result: {},
        artifacts: [],
      );
    };
    final settings = h.container.read(settingsStorageProvider);
    h.provider.turns.addAll([
      (() async* {
        await settings.writeToolPermissionRules([
          rule.withPolicy(ToolPolicy.allow),
        ]);
        yield* toolTurn(
          callId: 'fixed',
          toolName: 'open_app',
          arguments: '{"packageName":"fixture.app"}',
        );
      })(),
      textTurn('原运行保持禁止'),
    ]);
    await h.controller().send('打开应用');
    expect((await h.recordsByCall())['fixed']!.status, ToolCallStatus.rejected);
    expect(
      (await h.latestRun()).configuration.permissionRules.single.policy,
      ToolPolicy.deny,
    );
    expect(dispatched, 0);
    h.provider.turns.addAll([
      toolTurn(
        callId: 'next',
        toolName: 'open_app',
        arguments: '{"packageName":"fixture.app"}',
      ),
      textTurn('已打开'),
    ]);
    await h.controller().send('再次打开应用');
    expect((await h.recordsByCall())['next']!.status, ToolCallStatus.succeeded);
    expect(
      (await h.latestRun()).configuration.permissionRules.single.policy,
      ToolPolicy.allow,
    );
    expect(dispatched, 1);
  });

  test('本轮授权沿用、会话复制重映射授权来源，副本的新运行重新确认', () async {
    final h = await ToolLoopHarness.create();
    final driver = h.container.read(channelDriverProvider) as FakeChannelDriver;
    driver.executeHandler = (request, _) async => ExecutionResult(
      toolCallId: request.toolCallId,
      status: ExecutionStatus.succeeded,
      result: {},
      artifacts: [],
    );
    var confirmations = 0;
    h.onConfirmation = (_) async {
      confirmations++;
      return ToolDecision.approvedForRun;
    };
    h.provider.turns.addAll([
      multiToolTurn([
        (
          callId: 'first',
          toolName: 'open_app',
          arguments: '{"packageName":"fixture.app"}',
        ),
        (
          callId: 'second',
          toolName: 'open_app',
          arguments: '{"packageName":"fixture.other"}',
        ),
      ]),
      textTurn('已完成'),
    ]);
    await h.controller().send('打开应用');
    expect(confirmations, 1);
    final records = await h.recordsByCall();
    expect(records['second']!.decision, isNull);
    expect(
      records['second']!.permission!.grantSourceCallId,
      records['first']!.id,
    );
    final copied = await (await h.conversations()).duplicateConversation(
      h.conversationId()!,
    );
    final runs = await (h.database.select(
      h.database.agentRuns,
    )..where((row) => row.conversationId.equals(copied.id))).get();
    final calls = await (await h.toolCalls()).getByRun(runs.single.id);
    final first = calls.firstWhere((call) => call.providerCallId == 'first');
    final second = calls.firstWhere((call) => call.providerCallId == 'second');
    expect(first.id, isNot(records['first']!.id));
    expect(second.permission!.grantSourceCallId, first.id);
    expect(first.permission!.grantSourceCallId, first.id);
    expect(second.permission!.grantScope, PermissionGrantScope.run);
    await h.controller().openConversation(copied.id);
    h.provider.turns.addAll([
      toolTurn(
        callId: 'copied-new',
        toolName: 'open_app',
        arguments: '{"packageName":"fixture.app"}',
      ),
      textTurn('已完成'),
    ]);
    await h.controller().send('再执行');
    expect(confirmations, 2);
  });

  test('未知工具即使默认 allow 仍询问，显式规则可批准且记录完整来源', () async {
    final tool = _UnknownTool();
    final h = await ToolLoopHarness.create(registry: ToolRegistry([tool]));
    h.onConfirmation = (request) async {
      expect(request.permission!.request.effects, {ToolEffect.unknown});
      return ToolDecision.rejected;
    };
    h.provider.turns.addAll([
      toolTurn(callId: 'unknown', toolName: tool.name, arguments: '{}'),
      textTurn('未执行'),
    ]);
    await h.controller().send('调用工具');
    expect(tool.calls, 0);
    final record = (await h.recordsByCall())['unknown']!;
    expect(record.status, ToolCallStatus.rejected);
    expect(record.permission!.policy, ToolPolicy.ask);
    expect(jsonEncode(record.permission!.toJson()), contains('unknown'));
  });
}

class _UnknownTool extends Tool {
  int calls = 0;
  @override
  String get name => 'custom_unknown';
  @override
  String get description => 'Fixture';
  @override
  Map<String, dynamic> get inputSchema => const {
    'type': 'object',
    'properties': <String, dynamic>{},
  };
  @override
  Set<String> get requiredCapabilities => const {};
  @override
  ToolPolicy get defaultPolicy => ToolPolicy.allow;
  @override
  String describeAction(Map<String, dynamic> arguments) => 'Fixture';
  @override
  Future<ToolOutcome> execute(
    Map<String, dynamic> arguments,
    ToolContext context,
    RunCancellation cancellation, {
    ToolProgress? onProgress,
  }) async {
    calls++;
    return const ToolOutcome.success('Executed');
  }
}
