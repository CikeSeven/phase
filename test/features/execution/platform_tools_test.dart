import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/error/failure.dart';
import 'package:phase/data/datasources/local/settings_storage.dart';
import 'package:phase/data/models/agent_run.dart';
import 'package:phase/data/models/chat_request.dart';
import 'package:phase/data/models/execution_scope.dart';
import 'package:phase/data/models/tool_call_record.dart';
import 'package:phase/features/execution/channel_driver.dart';
import 'package:phase/features/execution/execution_api.g.dart';

import '../../support/fake_channel_driver.dart';
import '../tools/tool_loop_harness.dart';

void main() {
  const root = 'content://fixture/tree/root';
  const document = '$root/document/notes.txt';

  test('授权文件的合法长中文名不会因内部副本前缀而读取失败', () async {
    final h = await ToolLoopHarness.create();
    await h.container
        .read(settingsStorageProvider)
        .writeExecutionScope(const ExecutionScope(fileUris: [root]));
    final driver = h.container.read(channelDriverProvider) as FakeChannelDriver;
    final fileName = '${'月' * 80}.txt';
    expect(utf8.encode(fileName).length, lessThanOrEqualTo(255));
    final source = File('${h.tempDir.path}/native-copy')
      ..writeAsStringSync('授权文件正文');
    driver.executeHandler = (request, _) async => ExecutionResult(
      toolCallId: request.toolCallId,
      status: ExecutionStatus.succeeded,
      result: {'uri': document, 'name': fileName},
      artifacts: [
        ExecutionArtifact(
          uri: document,
          name: fileName,
          size: source.lengthSync(),
          localPath: source.path,
        ),
      ],
    );
    h.provider.turns.addAll([
      toolTurn(
        callId: 'read',
        toolName: 'read_file',
        arguments: jsonEncode({'reference': document}),
      ),
      textTurn('已读取授权文件'),
    ]);
    await h.controller().send('读取文件');
    expect((await h.recordsByCall())['read']!.status, ToolCallStatus.succeeded);
    final attachments = await (await h.conversations()).attachmentsFor(
      h.conversationId()!,
    );
    expect(attachments.single.name, fileName);
    expect(File(attachments.single.localPath).readAsStringSync(), '授权文件正文');
    expect((await h.latestRun()).status, RunStatus.completed);
  });

  test('原生临时文件丢失是读取失败：回填给 AI，不误报保存失败或停止任务', () async {
    final h = await ToolLoopHarness.create();
    await h.container
        .read(settingsStorageProvider)
        .writeExecutionScope(const ExecutionScope(fileUris: [root]));
    final driver = h.container.read(channelDriverProvider) as FakeChannelDriver;
    driver.executeHandler = (request, _) async => ExecutionResult(
      toolCallId: request.toolCallId,
      status: ExecutionStatus.succeeded,
      result: {'uri': document, 'name': 'notes.txt'},
      artifacts: [
        ExecutionArtifact(
          uri: document,
          name: 'notes.txt',
          size: 12,
          localPath: '${h.tempDir.path}/missing-native-copy',
        ),
      ],
    );
    h.provider.turns.addAll([
      toolTurn(
        callId: 'read',
        toolName: 'read_file',
        arguments: jsonEncode({'reference': document}),
      ),
      textTurn('这次没有读到 notes.txt 的内容'),
    ]);
    await h.controller().send('读取文件');
    final record = (await h.recordsByCall())['read']!;
    expect(record.status, ToolCallStatus.failed);
    expect(record.errorCode, 'fileReadFailed');
    expect(record.resultMessageId, isNotNull);
    final result = h.provider.requests.last.messages
        .expand((message) => message.parts)
        .whereType<ResolvedToolResult>()
        .single;
    expect(result.isError, isTrue);
    expect(result.content, contains('notes.txt'));
    expect(result.content, isNot(contains('已有操作不会自动重发')));
    expect((await h.latestRun()).status, RunStatus.completed);
  });

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

  test('外部文件已经写入，预览文件丢失不改写实际结果或重新执行写入', () async {
    final h = await ToolLoopHarness.create();
    final driver = h.container.read(channelDriverProvider) as FakeChannelDriver;
    h.onConfirmation = (_) async => ToolDecision.approved;
    var writes = 0;
    final external = File('${h.tempDir.path}/external.txt');
    driver.executeHandler = (request, _) async {
      writes++;
      await external.writeAsString('已写入内容');
      return ExecutionResult(
        toolCallId: request.toolCallId,
        status: ExecutionStatus.succeeded,
        result: {
          'uri': document,
          'name': 'notes.txt',
          'sha256': 'fixture-hash',
        },
        artifacts: [
          ExecutionArtifact(
            uri: document,
            name: 'notes.txt',
            size: 12,
            localPath: '${h.tempDir.path}/missing-native-copy',
          ),
        ],
      );
    };
    h.provider.turns.addAll([
      toolTurn(
        callId: 'write',
        toolName: 'write_file',
        arguments: jsonEncode({
          'directory': root,
          'path': 'notes.txt',
          'content': '已写入内容',
        }),
      ),
      textTurn('文件已保存'),
    ]);
    await h.controller().send('写入文件');
    final record = (await h.recordsByCall())['write']!;
    expect(writes, 1);
    expect(external.readAsStringSync(), '已写入内容');
    expect(record.status, ToolCallStatus.succeeded);
    expect(jsonDecode(record.result!)['warning'], contains('已写入'));
    expect((await h.latestRun()).status, RunStatus.completed);
  });

  test('文件读取正常而数据库写入失败时明确报告对话保存失败', () async {
    final h = await ToolLoopHarness.create();
    final driver = h.container.read(channelDriverProvider) as FakeChannelDriver;
    final source = File('${h.tempDir.path}/native-copy')
      ..writeAsStringSync('授权文件正文');
    driver.executeHandler = (request, _) async => ExecutionResult(
      toolCallId: request.toolCallId,
      status: ExecutionStatus.succeeded,
      result: {'uri': document, 'name': 'notes.txt'},
      artifacts: [
        ExecutionArtifact(
          uri: document,
          name: 'notes.txt',
          size: source.lengthSync(),
          localPath: source.path,
        ),
      ],
    );
    await h.database.customStatement(
      'CREATE TRIGGER fail_attachment BEFORE INSERT ON attachments '
      "BEGIN SELECT RAISE(ABORT, 'fixture database failure'); END",
    );
    h.provider.turns.add(
      toolTurn(
        callId: 'read',
        toolName: 'read_file',
        arguments: jsonEncode({'reference': document}),
      ),
    );
    await expectLater(
      h.controller().send('读取文件'),
      throwsA(isA<StorageFailure>()),
    );
    expect(h.provider.requests, hasLength(1));
    final record = (await h.recordsByCall())['read']!;
    expect(record.errorCode, 'storageError');
    expect(record.result, '相月未能保存这次对话，任务已停止。');
    expect((await h.latestRun()).finishReason, RunFinishReason.storageError);
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
