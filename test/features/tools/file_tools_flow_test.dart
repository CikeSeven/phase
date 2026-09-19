import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:phase/data/datasources/local/attachment_storage.dart';
import 'package:phase/data/models/attachment.dart';
import 'package:phase/data/models/agent_run.dart';
import 'package:phase/data/models/chat_request.dart';
import 'package:phase/data/models/tool_call_record.dart';

import 'tool_loop_harness.dart';

void main() {
  test('write_file 落到产物目录并登记为附件，read_file/list_files 能读回', () async {
    final harness = await ToolLoopHarness.create();
    final storage = await harness.container.read(
      attachmentStorageProvider.future,
    );
    final notes = await storage.save(
      name: 'notes.txt',
      mimeType: 'text/plain',
      kind: AttachmentKind.text,
      bytes: utf8.encode('笔记正文'),
    );
    // write_file 默认 ask：确认入口批准这次写入。
    harness.onConfirmation = (request) async => ToolDecision.approved;
    harness.provider.turns.addAll([
      toolTurn(
        callId: 'call_1',
        toolName: 'write_file',
        arguments: '{"path":"summary.md","content":"# 摘要\\n第一条"}',
      ),
      toolTurn(
        callId: 'call_2',
        toolName: 'read_file',
        arguments: '{"path":"summary.md"}',
      ),
      toolTurn(callId: 'call_3', toolName: 'list_files', arguments: '{}'),
      textTurn('已保存'),
    ]);

    await harness.controller().send('保存摘要', attachments: [notes]);

    final conversationId = harness.conversationId()!;
    final record = (await harness.recordsByCall())['call_1']!;
    expect(record.status, ToolCallStatus.succeeded);

    // 产物写在会话产物目录里。
    final artifact = File(
      p.join(harness.artifactsDir(conversationId).path, 'summary.md'),
    );
    expect(artifact.existsSync(), isTrue);
    expect(artifact.readAsStringSync(), '# 摘要\n第一条');

    // 产物登记为 artifact 类型附件，界面按附件索引就能查到。
    final repository = await harness.conversations();
    final attachments = await repository.attachmentsFor(conversationId);
    final registered = attachments.singleWhere(
      (attachment) => attachment.name == 'summary.md',
    );
    expect(registered.kind, AttachmentKind.artifact);
    expect(registered.localPath, artifact.path);
    expect(registered.conversationId, conversationId);
    expect(
      harness.state().attachments.values.map((attachment) => attachment.name),
      contains('summary.md'),
    );

    // read_file 读到自己刚写的产物。
    final read = (await harness.recordsByCall())['call_2']!;
    expect(read.status, ToolCallStatus.succeeded);
    expect(read.result, contains('第一条'));

    // list_files 同时列出已导入附件与本次产物。
    final listed = (await harness.recordsByCall())['call_3']!;
    expect(listed.status, ToolCallStatus.succeeded);
    expect(listed.result, contains('notes.txt'));
    expect(listed.result, contains('summary.md'));

    final run = await harness.latestRun();
    expect(run.status, RunStatus.completed);
    expect(run.turnCount, 4);
    expect((await harness.branch()).last.text, '已保存');
  });

  test('write_file 拒绝绝对路径与上跳路径，不落盘到产物目录之外', () async {
    final harness = await ToolLoopHarness.create();
    final outside = File(
      p.join(
        Directory.systemTemp.path,
        'phase-escape-${DateTime.now().microsecondsSinceEpoch}.md',
      ),
    );
    harness.onConfirmation = (request) async => ToolDecision.approved;
    harness.provider.turns.addAll([
      toolTurn(
        callId: 'call_1',
        toolName: 'write_file',
        arguments: '{"path":"${outside.path}","content":"越界"}',
      ),
      toolTurn(
        callId: 'call_2',
        toolName: 'write_file',
        arguments: '{"path":"../escape.md","content":"越界"}',
      ),
      textTurn('没有写入'),
    ]);

    await harness.controller().send('写到外面');

    final records = await harness.recordsByCall();
    final absolute = records['call_1']!;
    final relative = records['call_2']!;
    expect(absolute.status, ToolCallStatus.failed);
    expect(absolute.errorCode, 'invalidPath');
    expect(relative.status, ToolCallStatus.failed);
    expect(relative.errorCode, 'invalidPath');
    // 拒绝的理由如实回填给模型。
    expect(await harness.resultTextOf(absolute), contains('路径不合法'));
    expect(await harness.resultTextOf(relative), contains('路径不合法'));

    // 两处都没有落盘：拒绝是执行前的判断，不做「就近落盘」。
    expect(outside.existsSync(), isFalse);
    final conversationId = harness.conversationId()!;
    expect(
      File(
        p.join(harness.artifactsDir(conversationId).parent.path, 'escape.md'),
      ).existsSync(),
      isFalse,
    );
    expect(
      harness.artifactsDir(conversationId).existsSync()
          ? harness
                .artifactsDir(conversationId)
                .listSync(recursive: true)
                .whereType<File>()
                .toList()
          : const <File>[],
      isEmpty,
    );
    expect((await harness.latestRun()).status, RunStatus.completed);
  });
  test('AI creates an empty extensionless file, writes, edits and reads it through persisted results', () async {
    final h = await ToolLoopHarness.create();
    h.onConfirmation = (_) async => ToolDecision.approved;
    h.provider.turns.addAll([
      toolTurn(
        callId: 'empty',
        toolName: 'write_file',
        arguments: jsonEncode({'path': 'src/README', 'content': ''}),
      ),
      toolTurn(
        callId: 'write',
        toolName: 'write_file',
        arguments: jsonEncode({
          'path': 'src/README',
          'content': 'alpha\nbeta\ngamma',
        }),
      ),
      toolTurn(
        callId: 'edit',
        toolName: 'edit_file',
        arguments: jsonEncode({
          'path': 'src/README',
          'edits': [
            {'oldText': 'alpha', 'newText': 'ALPHA'},
            {'oldText': 'gamma', 'newText': ''},
          ],
        }),
      ),
      toolTurn(
        callId: 'read',
        toolName: 'read_file',
        arguments: jsonEncode({'path': 'src/README', 'offset': 2, 'limit': 1}),
      ),
      toolTurn(
        callId: 'list',
        toolName: 'list_files',
        arguments: jsonEncode({'path': 'src'}),
      ),
      textTurn('完成'),
    ]);
    await h.controller().send('修改文件');
    final records = await h.recordsByCall();
    expect(
      records.values.every(
        (record) => record.status == ToolCallStatus.succeeded,
      ),
      isTrue,
    );
    expect(records['empty']!.artifacts, records['edit']!.artifacts);
    final attachments = await (await h.conversations()).attachmentsFor(
      h.conversationId()!,
    );
    expect(attachments, hasLength(1));
    expect(attachments.single.name, 'src/README');
    expect(attachments.single.size, utf8.encode('ALPHA\nbeta\n').length);
    expect(
      await File(attachments.single.localPath).readAsString(),
      'ALPHA\nbeta\n',
    );
    expect(records['read']!.result, startsWith('beta\n'));
    expect(records['read']!.result, contains('offset=3'));
    expect(jsonDecode(records['list']!.result!)['files'], [
      {'path': 'src/README', 'type': 'file'},
    ]);
  });

  test(
    'read continuation survives the model context limit and subsequent turns',
    () async {
      final h = await ToolLoopHarness.create();
      h.onConfirmation = (_) async => ToolDecision.approved;
      h.provider.turns.addAll([
        toolTurn(
          callId: 'write',
          toolName: 'write_file',
          arguments: jsonEncode({
            'path': 'large',
            'content': List.filled(20, '月' * 1000).join('\n'),
          }),
        ),
        toolTurn(
          callId: 'read',
          toolName: 'read_file',
          arguments: jsonEncode({'path': 'large'}),
        ),
        toolTurn(callId: 'system', toolName: 'system_info', arguments: '{}'),
        textTurn('已读取第一页'),
      ]);
      await h.controller().send('查看大文件');
      for (final request in h.provider.requests.skip(2)) {
        final result = request.messages
            .expand((m) => m.parts)
            .whereType<ResolvedToolResult>()
            .singleWhere((r) => r.callId == 'read');
        expect(result.content, contains('offset=6'));
        expect(result.content, isNot(contains('结果已截断')));
      }
    },
  );
}
