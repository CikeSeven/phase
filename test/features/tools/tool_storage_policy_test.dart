import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/error/failure.dart';
import 'package:phase/data/models/assistant.dart';
import 'package:phase/data/models/chat_request.dart';
import 'package:phase/data/models/message_part.dart';
import 'package:phase/data/models/profile_model.dart';
import 'package:phase/data/models/tool_call_record.dart';
import 'package:phase/data/repositories/assistant_repository.dart';
import 'package:phase/features/tools/tool.dart';

import 'tool_loop_harness.dart';

void main() {
  for (final deleteOriginal in [true, false]) {
    test('复制工具会话重映射运行、结果、产物，删除${deleteOriginal ? '原件' : '副本'}不影响另一份', () async {
      final h = await ToolLoopHarness.create();
      h.onConfirmation = (_) async => ToolDecision.approved;
      h.provider.turns.addAll([
        toolTurn(
          callId: 'write',
          toolName: 'write_file',
          arguments: '{"path":"summary.md","content":"saved"}',
        ),
        textTurn('done'),
      ]);
      await h.controller().send('save');
      final repository = await h.conversations();
      final sourceId = h.conversationId()!;
      final original = (await h.recordsByCall())['write']!;
      final copy = await repository.duplicateConversation(sourceId);
      final copiedThread = (await repository.getThread(copy.id))!;
      final copiedId = copiedThread.messages
          .expand((m) => m.parts)
          .whereType<ToolCallPart>()
          .single
          .toolCallId;
      final copied = (await repository.toolCallsByIds([copiedId]))[copiedId]!;
      expect(copied.id, isNot(original.id));
      expect(copied.runId, isNot(original.runId));
      final copiedRun = (await (await h.runs()).getById(copied.runId))!;
      final originalRun = (await (await h.runs()).getById(original.runId))!;
      expect(copiedRun.configuration.workspace!.id, copy.workspaceId);
      expect(
        copiedRun.configuration.workspace!.rootPath,
        isNot(originalRun.configuration.workspace!.rootPath),
      );
      expect(copied.assistantMessageId, isNot(original.assistantMessageId));
      expect(copied.resultMessageId, isNot(original.resultMessageId));
      expect(copied.artifacts.single, isNot(original.artifacts.single));
      final originalFile = (await repository.attachmentsFor(sourceId)).single;
      final copiedFile = (await repository.attachmentsFor(copy.id)).single;
      expect(copiedFile.localPath, isNot(originalFile.localPath));
      expect(File(copiedFile.localPath).readAsStringSync(), 'saved');
      await repository.deleteConversation(deleteOriginal ? sourceId : copy.id);
      final surviving = deleteOriginal ? copied : original;
      expect(
        await repository.toolCallsByIds([surviving.id]),
        contains(surviving.id),
      );
      expect(
        File(deleteOriginal ? copiedFile.localPath : originalFile.localPath)
            .readAsStringSync(),
        'saved',
      );
    });
  }

  test('复制工具记录失败时回滚副本及独立文件，不影响原件', () async {
    final h = await ToolLoopHarness.create();
    h.onConfirmation = (_) async => ToolDecision.approved;
    h.provider.turns.addAll([
      toolTurn(
        callId: 'write',
        toolName: 'write_file',
        arguments: '{"path":"summary.md","content":"saved"}',
      ),
      textTurn('done'),
    ]);
    await h.controller().send('save');
    final repository = await h.conversations();
    final before = h.tempDir
        .listSync(recursive: true)
        .whereType<File>()
        .map((f) => f.path)
        .toSet();
    await h.database.customStatement(
      "CREATE TRIGGER reject_tool_copy BEFORE INSERT ON tool_calls BEGIN SELECT RAISE(ABORT, 'test copy failure'); END",
    );
    await expectLater(
      repository.duplicateConversation(h.conversationId()!),
      throwsA(isA<Failure>()),
    );
    expect(await repository.watchConversations().first, hasLength(1));
    final after = h.tempDir
        .listSync(recursive: true)
        .whereType<File>()
        .map((f) => f.path)
        .toSet();
    expect(after.difference(before), isEmpty);
    expect(
      (await h.recordsByCall())['write']!.status,
      ToolCallStatus.succeeded,
    );
  });

  test('空工具范围和显式 deny 不下发定义，收到调用也不执行', () async {
    final echo = RecordingTool(name: 'echo');
    final h = await ToolLoopHarness.create(registry: ToolRegistry([echo]));
    final assistants = AssistantRepository(h.database);
    final assistant = (await assistants.getAssistants()).single;
    await assistants.save(
      assistant.copyWith(toolPolicy: const ToolPolicyConfig()),
    );
    h.provider.turns.addAll([
      toolTurn(callId: 'call', toolName: 'echo', arguments: '{}'),
      textTurn('denied'),
    ]);
    await h.controller().send('try');
    expect(h.provider.requests.first.tools, isEmpty);
    expect(echo.executions, isEmpty);
    expect((await h.recordsByCall())['call']!.status, ToolCallStatus.rejected);
    expect(
      h.provider.requests.last.messages
          .expand((m) => m.parts)
          .whereType<ResolvedToolResult>()
          .single
          .isError,
      isTrue,
    );
  });

  test('模型关闭工具能力时也不能执行未下发的调用', () async {
    final echo = RecordingTool(name: 'echo');
    final h = await ToolLoopHarness.create(
      registry: ToolRegistry([echo]),
      models: const [ProfileModel(id: 'model-a', supportsTools: false)],
    );
    h.provider.turns.addAll([
      toolTurn(callId: 'call', toolName: 'echo', arguments: '{}'),
      textTurn('denied'),
    ]);
    await h.controller().send('try');
    expect(h.provider.requests.first.tools, isEmpty);
    expect(echo.executions, isEmpty);
  });
}
