import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:phase/data/datasources/local/attachment_storage.dart';
import 'package:phase/data/models/agent_run.dart';
import 'package:phase/data/models/attachment.dart';
import 'package:phase/data/models/chat_chunk.dart';
import 'package:phase/data/models/chat_message.dart';
import 'package:phase/data/models/chat_request.dart';
import 'package:phase/data/models/message_part.dart';
import 'package:phase/data/models/tool_call_record.dart';
import 'package:phase/data/models/tool_policy.dart';
import 'package:phase/features/tools/tool.dart';
import 'package:phase/features/tools/tool_executor.dart';
import 'package:phase/features/tools/run_recovery_controller.dart';

import 'tool_loop_harness.dart';

void main() {
  test('工具闭环：调用 → 执行 → 结果回填 → 下一轮回答', () async {
    final harness = await ToolLoopHarness.create();
    final storage = await harness.container.read(
      attachmentStorageProvider.future,
    );
    final notes = await storage.save(
      name: 'notes.txt',
      mimeType: 'text/plain',
      kind: AttachmentKind.text,
      bytes: utf8.encode('第一行\n第二行'),
    );
    harness.provider.turns.addAll([
      toolTurn(
        callId: 'call_1',
        toolName: 'read_file',
        arguments: '{"reference":"notes.txt"}',
      ),
      textTurn('文件里有两行'),
    ]);

    await harness.controller().send('看看附件', attachments: [notes]);

    // 一次运行：一轮调用工具、一轮回答，两次真实请求。
    final run = await harness.latestRun();
    expect(run.status, RunStatus.completed);
    expect(run.finishReason, RunFinishReason.completed);
    expect(run.turnCount, 2);
    expect(run.modelAttemptCount, 2);

    // 工具记录：真实执行并成功。
    final record = (await harness.recordsByCall())['call_1']!;
    expect(record.toolName, 'read_file');
    expect(record.status, ToolCallStatus.succeeded);
    expect(record.result, contains('第一行'));

    // 消息树：助手消息只引用记录 id，结果另起一条 role: tool 的消息。
    final branch = await harness.branch();
    expect(branch.map((message) => message.role), [
      ChatRole.user,
      ChatRole.assistant,
      ChatRole.tool,
      ChatRole.assistant,
    ]);
    expect(
      branch[1].parts.whereType<ToolCallPart>().single.toolCallId,
      record.id,
    );
    expect(
      branch[2].parts.whereType<ToolResultPart>().single.toolCallId,
      record.id,
    );
    expect(branch[2].text, contains('第一行'));
    expect(record.resultMessageId, branch[2].id);
    expect(branch[3].text, '文件里有两行');
    expect(branch[3].status, MessageStatus.completed);

    // 第二轮的请求带上调用与结果，且按模型侧的调用 id 配对。
    final request = harness.provider.requests[1];
    final calls = [
      for (final message in request.messages)
        ...message.parts.whereType<ResolvedToolCall>(),
    ];
    final results = [
      for (final message in request.messages)
        ...message.parts.whereType<ResolvedToolResult>(),
    ];
    expect(calls.single.callId, 'call_1');
    expect(calls.single.toolName, 'read_file');
    expect(calls.single.arguments['reference'], 'notes.txt');
    expect(results.single.callId, 'call_1');
    expect(results.single.content, contains('第一行'));
    expect(results.single.isError, isFalse);
    // 工具定义随运行配置下发。
    expect(request.tools.map((tool) => tool.name), contains('read_file'));
  });

  test('一轮多个调用按顺序串行执行，结果按原调用配对', () async {
    final echo = RecordingTool(
      name: 'echo',
      schema: const {
        'type': 'object',
        'properties': {
          'value': {'type': 'string'},
        },
        'additionalProperties': false,
      },
    );
    echo.outcomeOf = (arguments) =>
        ToolOutcome.success('echo:${arguments['value']}');
    final harness = await ToolLoopHarness.create(
      registry: ToolRegistry([echo]),
    );
    harness.provider.turns.addAll([
      multiToolTurn([
        (callId: 'call_a', toolName: 'echo', arguments: '{"value":"A"}'),
        (callId: 'call_b', toolName: 'echo', arguments: '{"value":"B"}'),
      ]),
      textTurn('都执行完了'),
    ]);

    await harness.controller().send('依次执行');

    // 执行顺序与调用顺序一致。
    expect(echo.executions.map((arguments) => arguments['value']), ['A', 'B']);

    final records = await harness.recordsByCall();
    final first = records['call_a']!;
    final second = records['call_b']!;
    expect(first.status, ToolCallStatus.succeeded);
    expect(second.status, ToolCallStatus.succeeded);
    // 结果与调用配对：各自拿到自己那次的结果。
    expect(first.result, 'echo:A');
    expect(second.result, 'echo:B');
    expect(await harness.resultTextOf(first), 'echo:A');
    expect(await harness.resultTextOf(second), 'echo:B');

    final branch = await harness.branch();
    expect(
      branch[1].parts.whereType<ToolCallPart>().map((part) => part.toolCallId),
      [first.id, second.id],
    );
    // 结果消息按执行顺序串在助手消息之后。
    expect(branch[2].id, first.resultMessageId);
    expect(branch[3].id, second.resultMessageId);
    expect(branch[2].text, 'echo:A');
    expect(branch[3].text, 'echo:B');

    final request = harness.provider.requests[1];
    expect(
      request.messages
          .expand((message) => message.parts)
          .whereType<ResolvedToolCall>()
          .map((part) => part.callId),
      ['call_a', 'call_b'],
    );
    expect(
      request.messages
          .expand((message) => message.parts)
          .whereType<ResolvedToolResult>()
          .map((part) => part.callId),
      ['call_a', 'call_b'],
    );
  });

  test('ask 策略被拒绝：不执行工具，拒绝结果回填后继续下一轮', () async {
    final risky = RecordingTool(name: 'risky', policy: ToolPolicy.ask);
    final harness = await ToolLoopHarness.create(
      registry: ToolRegistry([risky]),
    );
    final asked = <ToolConfirmationRequest>[];
    harness.controller().onToolConfirmation = (request) async {
      asked.add(request);
      return ToolDecision.rejected;
    };
    harness.provider.turns.addAll([
      toolTurn(callId: 'call_1', toolName: 'risky', arguments: '{}'),
      textTurn('好，那就不动它'),
    ]);

    await harness.controller().send('执行危险操作');

    expect(asked.single.record.toolName, 'risky');
    expect(asked.single.summary, contains('risky'));
    // 拒绝即不执行。
    expect(risky.executions, isEmpty);
    final record = (await harness.recordsByCall())['call_1']!;
    expect(record.status, ToolCallStatus.rejected);
    expect(record.decision, ToolDecision.rejected);
    // 拒绝作为本次调用的结果回填。
    expect(await harness.resultTextOf(record), contains('拒绝'));
    final results = harness.provider.requests[1].messages
        .expand((message) => message.parts)
        .whereType<ResolvedToolResult>()
        .toList();
    expect(results.single.callId, 'call_1');
    expect(results.single.content, contains('拒绝'));
    // 拒绝不结束运行：继续到下一轮给出回答。
    final run = await harness.latestRun();
    expect(run.status, RunStatus.completed);
    expect(run.turnCount, 2);
    expect((await harness.branch()).last.text, '好，那就不动它');
  });

  test('批准后执行期间运行回到 running，不再停在等待确认', () async {
    final slow = RecordingTool(name: 'slow', policy: ToolPolicy.ask);
    final gate = Completer<void>();
    slow.executeAsync = (arguments, cancellation) async {
      await gate.future;
      return const ToolOutcome.success('已完成');
    };
    final harness = await ToolLoopHarness.create(
      registry: ToolRegistry([slow]),
    );
    harness.controller().onToolConfirmation = (request) async {
      // 面板展示的摘要来自工具自己的动作描述。
      expect(request.summary, contains('slow'));
      return ToolDecision.approved;
    };
    harness.provider.turns.addAll([
      toolTurn(callId: 'call_1', toolName: 'slow', arguments: '{}'),
      textTurn('完成'),
    ]);

    final sending = harness.controller().send('执行');
    await harness.waitUntil(() async {
      final record = (await harness.recordsByCall())['call_1'];
      return record?.status == ToolCallStatus.executing;
    });

    // 派发状态与 activeToolCallId 一起落库，恢复时能定位在途动作。
    final during = await harness.latestRun();
    expect(during.status, RunStatus.running);
    expect(
      during.activeToolCallId,
      (await harness.recordsByCall())['call_1']!.id,
    );

    gate.complete();
    await sending;
    expect(
      (await harness.recordsByCall())['call_1']!.status,
      ToolCallStatus.succeeded,
    );
    expect(slow.executions, hasLength(1));
    final finished = await harness.latestRun();
    expect(finished.status, RunStatus.completed);
    expect(finished.activeToolCallId, isNull);
  });

  test('拒绝后运行不再停在等待确认，继续下一轮', () async {
    final risky = RecordingTool(name: 'risky', policy: ToolPolicy.ask);
    final harness = await ToolLoopHarness.create(
      registry: ToolRegistry([risky]),
    );
    harness.controller().onToolConfirmation = (request) async =>
        ToolDecision.rejected;
    // 第二轮挂住：在拒绝之后、收口之前读取运行状态。
    final next = StreamController<ChatChunk>();
    harness.provider.turns.addAll([
      toolTurn(callId: 'call_1', toolName: 'risky', arguments: '{}'),
      next.stream,
    ]);

    final sending = harness.controller().send('执行危险操作');
    await harness.waitUntil(() => harness.provider.requests.length == 2);

    final resumed = await harness.latestRun();
    expect(resumed.status, RunStatus.running);
    expect(resumed.activeToolCallId, isNull);
    expect(risky.executions, isEmpty);

    next.add(const PartStart(partId: 'text_0', kind: PartKind.text));
    next.add(const TextDelta(partId: 'text_0', text: '那就不动它'));
    next.add(
      const PartEnd(
        partId: 'text_0',
        part: TextPart(text: '那就不动它', partId: 'text_0'),
      ),
    );
    next.add(const ResponseEnd());
    await next.close();
    await sending;

    expect(
      (await harness.recordsByCall())['call_1']!.status,
      ToolCallStatus.rejected,
    );
    expect((await harness.latestRun()).status, RunStatus.completed);
    expect((await harness.branch()).last.text, '那就不动它');
  });

  test('流式期间停止：保留已收内容，运行 stopped', () async {
    final harness = await ToolLoopHarness.create();
    final chunks = StreamController<ChatChunk>();
    harness.provider.turns.add(chunks.stream);

    final sending = harness.controller().send('你好');
    await harness.waitUntil(() => harness.state().isGenerating);
    chunks.add(const PartStart(partId: 'text_0', kind: PartKind.text));
    chunks.add(const TextDelta(partId: 'text_0', text: '部分内容'));
    await harness.waitUntil(
      () async => (await harness.branch()).last.text == '部分内容',
    );

    harness.controller().stop();
    await sending;

    final branch = await harness.branch();
    expect(branch.last.text, '部分内容');
    expect(branch.last.status, MessageStatus.cancelled);
    final run = await harness.latestRun();
    expect(run.status, RunStatus.stopped);
    expect(run.finishReason, RunFinishReason.cancelled);
    expect(harness.state().isGenerating, isFalse);
    await chunks.close();
  });

  test('执行中停止：请求工具取消，如实记录工具返回的结果', () async {
    final slow = RecordingTool(name: 'slow');
    slow.executeAsync = (arguments, cancellation) async {
      // 长动作在分段之间让出控制权，停止时按取消返回。
      await cancellation.whenCancelled;
      return const ToolOutcome.failure('执行已取消，未完成写入', errorCode: 'cancelled');
    };
    final harness = await ToolLoopHarness.create(
      registry: ToolRegistry([slow]),
    );
    harness.provider.turns.add(
      toolTurn(callId: 'call_1', toolName: 'slow', arguments: '{}'),
    );

    final sending = harness.controller().send('慢慢执行');
    await harness.waitUntil(() async {
      final record = (await harness.recordsByCall())['call_1'];
      return record?.status == ToolCallStatus.executing;
    });

    harness.controller().stop();
    await sending;

    // 工具实际返回的结果如实记录，不按「已撤销」改写。
    final record = (await harness.recordsByCall())['call_1']!;
    expect(record.status, ToolCallStatus.failed);
    expect(record.errorCode, 'cancelled');
    expect(await harness.resultTextOf(record), contains('取消'));
    final run = await harness.latestRun();
    expect(run.status, RunStatus.stopped);
    expect(run.finishReason, RunFinishReason.cancelled);
    expect(harness.state().isGenerating, isFalse);
  });

  test('等待确认期间停止：记录 cancelled 且不执行', () async {
    final risky = RecordingTool(name: 'risky', policy: ToolPolicy.ask);
    final harness = await ToolLoopHarness.create(
      registry: ToolRegistry([risky]),
    );
    // 界面一直不给出决定：确认在停止时才结束。
    harness.controller().onToolConfirmation = (request) =>
        Completer<ToolDecision>().future;
    harness.provider.turns.add(
      toolTurn(callId: 'call_1', toolName: 'risky', arguments: '{}'),
    );

    final sending = harness.controller().send('执行危险操作');
    await harness.waitUntil(() async {
      final record = (await harness.recordsByCall())['call_1'];
      return record?.status == ToolCallStatus.awaitingConfirmation;
    });
    // 等待期间运行标记为等待确认，位置指向待确认的调用。
    final waiting = await harness.latestRun();
    expect(waiting.status, RunStatus.awaitingConfirmation);
    expect(waiting.activeToolCallId, isNotNull);

    harness.controller().stop();
    await sending;

    expect(risky.executions, isEmpty);
    final record = (await harness.recordsByCall())['call_1']!;
    expect(record.status, ToolCallStatus.cancelled);
    expect(await harness.resultTextOf(record), contains('取消'));
    final run = await harness.latestRun();
    expect(run.status, RunStatus.stopped);
    expect(run.finishReason, RunFinishReason.cancelled);
  });

  test('工具参数 JSON 非法：记为参数错误、不执行工具', () async {
    final echo = RecordingTool(name: 'echo');
    final harness = await ToolLoopHarness.create(
      registry: ToolRegistry([echo]),
    );
    harness.provider.turns.addAll([
      toolTurn(callId: 'call_1', toolName: 'echo', arguments: '{"value": '),
      textTurn('参数不对，我重来'),
    ]);

    await harness.controller().send('调用工具');

    expect(echo.executions, isEmpty);
    final record = (await harness.recordsByCall())['call_1']!;
    expect(record.status, ToolCallStatus.failed);
    expect(record.errorCode, 'invalidArguments');
    expect(await harness.resultTextOf(record), contains('JSON'));
    // 循环继续：参数错误按失败结果回填。
    final results = harness.provider.requests[1].messages
        .expand((message) => message.parts)
        .whereType<ResolvedToolResult>()
        .toList();
    expect(results.single.callId, 'call_1');
    expect(results.single.isError, isTrue);
    expect((await harness.branch()).last.text, '参数不对，我重来');
  });

  test('轮次上限：每轮都调用工具时在 maxTurns 处停下', () async {
    final echo = RecordingTool(name: 'echo');
    final harness = await ToolLoopHarness.create(
      registry: ToolRegistry([echo]),
    );
    for (var turn = 0; turn < AgentRun.defaultMaxTurns + 2; turn++) {
      harness.provider.turns.add(
        toolTurn(callId: 'call_$turn', toolName: 'echo', arguments: '{}'),
      );
    }

    await harness.controller().send('一直调用');

    final run = await harness.latestRun();
    expect(run.turnCount, AgentRun.defaultMaxTurns);
    expect(run.status, RunStatus.failed);
    expect(run.finishReason, RunFinishReason.turnLimit);
    expect(echo.executions, hasLength(AgentRun.defaultMaxTurns));
    final branch = await harness.branch();
    expect(
      branch.where((message) => message.role == ChatRole.assistant),
      hasLength(AgentRun.defaultMaxTurns),
    );
    expect(
      branch.where((message) => message.role == ChatRole.tool),
      hasLength(AgentRun.defaultMaxTurns),
    );
  });

  test('工具结果未确认：挂起等待核验，不当作普通失败也不重做', () async {
    final risky = RecordingTool(
      name: 'risky',
      outcome: const ToolOutcome.unknown('动作已派发，结果未知'),
    );
    final harness = await ToolLoopHarness.create(
      registry: ToolRegistry([risky]),
    );
    harness.provider.turns.add(
      toolTurn(callId: 'call_1', toolName: 'risky', arguments: '{}'),
    );

    await harness.controller().send('执行');

    // 动作派发过一次，结果未确认。
    expect(risky.executions, hasLength(1));
    final record = (await harness.recordsByCall())['call_1']!;
    expect(record.status, ToolCallStatus.unknown);
    final run = await harness.latestRun();
    expect(run.status, RunStatus.awaitingResult);
    expect(run.finishReason, isNull);
    expect(run.activeToolCallId, record.id);
    // 没有结果就不是 Failed：不写结果消息，也不自动重做动作。
    final branch = await harness.branch();
    expect(branch.where((message) => message.role == ChatRole.tool), isEmpty);
    expect(branch, hasLength(2));
    expect(harness.state().isGenerating, isFalse);
    // 未结束的运行在启动恢复入口可见（状态不丢）。
    final unfinished = await harness.container.read(
      runRecoveryControllerProvider.future,
    );
    expect(unfinished.map((entry) => entry.run.id), contains(run.id));
  });
}
