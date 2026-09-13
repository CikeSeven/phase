import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:phase/data/datasources/local/settings_storage.dart';
import 'package:phase/data/models/execution_scope.dart';
import 'package:phase/data/models/tool_call_record.dart';
import 'package:phase/features/execution/channel_driver.dart';
import 'package:phase/features/execution/execution_api.g.dart';

import '../../support/fake_channel_driver.dart';
import '../tools/tool_loop_harness.dart';

void main() {
  const root = 'content://fixture/tree/root';
  const document = '$root/document/notes.txt';

  test('外部文档经真实工具和仓储变成独立私有附件，范围固定且不启动设备服务', () async {
    final h = await ToolLoopHarness.create();
    final driver = h.container.read(channelDriverProvider) as FakeChannelDriver;
    await h.container
        .read(settingsStorageProvider)
        .writeExecutionScope(const ExecutionScope(fileUris: [root]));
    final source = File('${h.tempDir.path}/native-copy')
      ..writeAsStringSync('AI Agent 笔记\n第二行');
    final requests = <ExecutionRequest>[];
    driver.executeHandler = (request, _) async {
      requests.add(request);
      return ExecutionResult(
        toolCallId: request.toolCallId,
        status: ExecutionStatus.succeeded,
        result: {'uri': document, 'sha256': 'fixture-hash'},
        artifacts: [
          ExecutionArtifact(
            uri: document,
            name: 'notes.txt',
            size: source.lengthSync(),
            localPath: source.path,
            sha256: 'fixture-hash',
          ),
        ],
      );
    };
    h.provider.turns.addAll([
      toolTurn(
        callId: 'read',
        toolName: 'read_file',
        arguments: jsonEncode({'reference': document}),
      ),
      textTurn('已读取'),
    ]);
    await h.controller().send('读取授权文档');
    final record = (await h.recordsByCall())['read']!;
    expect(record.status, ToolCallStatus.succeeded);
    expect(requests.single.toolCallId, record.id);
    expect(requests.single.target.uri, document);
    expect(driver.scopes.single.fileUris, [root]);
    expect(driver.deviceTasks, [false]);
    expect(source.existsSync(), isFalse);
    final attachments = await (await h.conversations()).attachmentsFor(
      h.conversationId()!,
    );
    expect(attachments, hasLength(1));
    expect(
      File(attachments.single.localPath).readAsStringSync(),
      'AI Agent 笔记\n第二行',
    );
    final result = jsonDecode(record.result!) as Map;
    expect(result['uri'], document);
    expect(result['text'], contains('AI Agent'));
    expect(h.provider.requests.last.systemPrompt, contains(root));
  });

  test('确认后写外部文件，设置中途改变不更换运行范围；落库失败前的未知结果保留 URI', () async {
    final h = await ToolLoopHarness.create();
    final driver = h.container.read(channelDriverProvider) as FakeChannelDriver;
    await h.container
        .read(settingsStorageProvider)
        .writeExecutionScope(const ExecutionScope(fileUris: [root]));
    h.onConfirmation = (request) async {
      expect(request.record.arguments['directory'], root);
      expect(request.record.arguments['overwrite'], false);
      await h.container
          .read(settingsStorageProvider)
          .writeExecutionScope(
            const ExecutionScope(fileUris: ['content://other/tree/root']),
          );
      return ToolDecision.approved;
    };
    driver.executeHandler = (request, _) async => ExecutionResult(
      toolCallId: request.toolCallId,
      status: ExecutionStatus.failed,
      result: {'uri': '$root/document/summary.txt', 'actionAccepted': true},
      artifacts: [],
      error: ChannelError.executionFailed,
    );
    h.provider.turns.add(
      toolTurn(
        callId: 'write',
        toolName: 'write_file',
        arguments: jsonEncode({
          'directory': root,
          'path': 'summary.txt',
          'content': '摘要',
          'overwrite': false,
        }),
      ),
    );
    h.provider.turns.add(textTurn('写入失败，我将先读取目标状态'));
    await h.controller().send('保存摘要');
    final record = (await h.recordsByCall())['write']!;
    expect(record.status, ToolCallStatus.failed);
    expect(record.result, contains('$root/document/summary.txt'));
    expect(driver.scopes.single.fileUris, [root]);
    expect(h.provider.requests, hasLength(2));
  });
}
