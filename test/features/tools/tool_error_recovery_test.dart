import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/error/failure.dart';
import 'package:phase/data/models/agent_run.dart';
import 'package:phase/data/models/chat_request.dart';
import 'package:phase/data/models/tool_call_record.dart';
import 'package:phase/features/execution/channel_driver.dart';
import 'package:phase/features/execution/execution_api.g.dart';
import 'package:phase/features/execution/platform_tools.dart';
import 'package:phase/features/tools/file_tools.dart';
import 'package:phase/features/tools/tool.dart';

import '../../support/fake_channel_driver.dart';
import 'tool_loop_harness.dart';

void main() {
  for (final failure in [
    const NetworkFailure('private fixture'),
    const OperationFailure('工具没有返回完整内容'),
    const ExecutionFailure(ExecutionFailureCode.timeout),
  ]) {
    test('${failure.runtimeType} 是可回填的工具错误，而不是存储故障', () async {
      final tool = RecordingTool(name: 'read_file');
      tool.executeAsync = (_, _) async => throw failure;
      final h = await ToolLoopHarness.create(registry: ToolRegistry([tool]));
      h.provider.turns.addAll([
        toolTurn(callId: 'read', toolName: tool.name, arguments: '{}'),
        textTurn('收到工具错误，继续处理'),
      ]);
      await h.controller().send('test');
      final record = (await h.recordsByCall())['read']!;
      expect(record.status, ToolCallStatus.failed);
      expect(record.errorCode, isNot('storageError'));
      expect(record.resultMessageId, isNotNull);
      final result = h.provider.requests.last.messages
          .expand((m) => m.parts)
          .whereType<ResolvedToolResult>()
          .single;
      expect(result.isError, isTrue);
      expect(result.content, failure.userMessage);
      expect(result.content, isNot(contains('private fixture')));
      expect(tool.executions, hasLength(1));
      expect((await h.latestRun()).status, RunStatus.completed);
    });
  }

  test('原生读取缺少文件内容：回填实际错误，AI 可以继续回答', () async {
    late FakeChannelDriver driver;
    final h = await ToolLoopHarness.create(
      registry: ToolRegistry([
        ScopedFileTool(const ReadFileTool(), () => driver),
      ]),
    );
    driver = h.container.read(channelDriverProvider) as FakeChannelDriver;
    driver.executeHandler = (request, _) async => ExecutionResult(
      toolCallId: request.toolCallId,
      status: ExecutionStatus.succeeded,
      result: {},
      artifacts: [
        ExecutionArtifact(
          uri: 'content://fixture/doc',
          name: 'doc.txt',
          size: 1,
        ),
      ],
    );
    h.provider.turns.addAll([
      toolTurn(
        callId: 'read',
        toolName: 'read_file',
        arguments: '{"path":"content://fixture/doc"}',
      ),
      textTurn('读取没有返回内容'),
    ]);
    await h.controller().send('test');
    final record = (await h.recordsByCall())['read']!;
    expect(record.result, contains('文件内容没有返回'));
    expect(record.errorCode, isNot('storageError'));
    expect(record.resultMessageId, isNotNull);
    expect((await h.latestRun()).status, RunStatus.completed);
  });

  test('设备宿主失败不取消根任务，其他工具仍可用', () async {
    final device = RecordingTool(
      name: 'read_file',
      channel: ExecutionChannel.accessibility,
    );
    final local = RecordingTool(name: 'system_info');
    final h = await ToolLoopHarness.create(
      registry: ToolRegistry([device, local]),
    );
    final driver = h.container.read(channelDriverProvider) as FakeChannelDriver;
    driver.startFailure = const ExecutionFailure(
      ExecutionFailureCode.unavailable,
    );
    h.provider.turns.addAll([
      toolTurn(callId: 'device', toolName: device.name, arguments: '{}'),
      toolTurn(callId: 'local', toolName: local.name, arguments: '{}'),
      textTurn('已使用其他可用工具'),
    ]);
    await h.controller().send('test');
    expect(device.executions, isEmpty);
    expect(local.executions, hasLength(1));
    expect((await h.recordsByCall())['device']!.resultMessageId, isNotNull);
    expect((await h.latestRun()).status, RunStatus.completed);
  });

  test('真正的 StorageFailure 仍停止循环，不伪装成可恢复工具失败', () async {
    final tool = RecordingTool(name: 'write_file');
    tool.executeAsync = (_, _) async => throw const StorageFailure('fixture');
    final h = await ToolLoopHarness.create(registry: ToolRegistry([tool]));
    h.provider.turns.add(
      toolTurn(callId: 'write', toolName: tool.name, arguments: '{}'),
    );
    await expectLater(
      h.controller().send('test'),
      throwsA(isA<StorageFailure>()),
    );
    expect(h.provider.requests, hasLength(1));
    expect((await h.latestRun()).finishReason, RunFinishReason.storageError);
    expect((await h.recordsByCall())['write']!.errorCode, 'storageError');
    expect(h.state().isGenerating, isFalse);
  });
}
