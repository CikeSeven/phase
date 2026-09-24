import 'package:phase/data/models/chat_chunk.dart';
import 'package:phase/data/models/permission_mode.dart';

import 'dart:convert';

import 'package:phase/data/models/chat_request.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/error/failure.dart';
import 'package:phase/data/models/memory_entry.dart';
import 'package:phase/data/models/tool_call_record.dart';
import 'package:phase/data/repositories/assistant_repository.dart';
import 'package:phase/data/repositories/memory_repository.dart';
import 'package:phase/features/tools/tool.dart';

import '../tools/tool_loop_harness.dart';

void main() {
  test('检索先限制助手/全局和启用范围；修改保留来源，删除不被迟到编辑复活', () async {
    final h = await ToolLoopHarness.create(registry: ToolRegistry([]));
    final repository = MemoryRepository(h.database);
    final a = await repository.add(
      content: '茶 月相记录',
      assistantId: 'a',
      sourceMessageId: 'm',
      sourceRunId: 'r',
    );
    await repository.add(content: '茶 不同助手', assistantId: 'b');
    await repository.add(content: '茶 全局');
    expect(
      await repository.search(
        '茶',
        assistantId: 'a',
        scope: MemoryScope.disabled,
      ),
      isEmpty,
    );
    expect(
      (await repository.search(
        '茶',
        assistantId: 'a',
        scope: MemoryScope.assistant,
      )).map((e) => e.id),
      [a.id],
    );
    expect(
      await repository.search(
        '茶',
        assistantId: 'a',
        scope: MemoryScope.assistantAndGlobal,
      ),
      hasLength(2),
    );
    expect(
      await repository.search(
        '茶',
        assistantId: 'a',
        scope: MemoryScope.assistantAndGlobal,
        maxCharacters: 1,
      ),
      isEmpty,
    );
    await repository.update(a.id, content: '茶 改过', enabled: false);
    final updated = (await repository.watch().first).firstWhere(
      (e) => e.id == a.id,
    );
    expect(updated.sourceMessageId, 'm');
    expect(updated.sourceRunId, 'r');
    expect(
      await repository.search(
        '茶',
        assistantId: 'a',
        scope: MemoryScope.assistant,
      ),
      isEmpty,
    );
    await repository.delete(a.id);
    await expectLater(
      repository.update(a.id, content: '迟到内容', enabled: true),
      throwsA(isA<OperationFailure>()),
    );
    expect((await repository.watch().first).any((e) => e.id == a.id), isFalse);
  });

  for (final mode in PermissionMode.values) {
    test('记忆写入服从 ${mode.name}，来源与下一轮检索完整', () async {
      final h = await ToolLoopHarness.create(registry: ToolRegistry([]));
      final assistants = await h.container.read(
        assistantRepositoryProvider.future,
      );
      final assistant = await assistants.ensureDefault();
      await assistants.save(
        assistant.copyWith(memoryScope: MemoryScope.assistant),
      );
      await h.controller().setPermissionMode(mode);
      h.provider.turns.addAll([
        toolTurn(
          callId: 'write',
          toolName: 'write_memory',
          arguments: '{"content":"偏好茶","scope":"assistant"}',
        ),
        toolTurn(
          callId: 'read',
          toolName: 'read_memory',
          arguments: '{"query":"茶"}',
        ),
        textTurn('完成'),
      ]);
      var asks = 0;
      h.onConfirmation = (_) async {
        asks++;
        return ToolDecision.approved;
      };
      await h.controller().send('记住我喜欢茶');
      expect(asks, 0);
      final entries = await MemoryRepository(h.database).watch().first;
      if (mode != PermissionMode.plan) {
        expect(entries, hasLength(1));
        final run = await h.latestRun();
        expect(entries.single.sourceRunId, run.id);
        expect(entries.single.sourceMessageId, run.inputMessageId);
        expect((await h.recordsByCall())['read']!.result, contains('偏好茶'));
        expect(
          (await h.recordsByCall())['read']!.result,
          contains(run.inputMessageId),
        );
      } else {
        expect(entries, isEmpty);
      }
    });
  }

  test('中文记忆检索按条目预算，不被通用工具预览二次截断', () async {
    final h = await ToolLoopHarness.create(registry: ToolRegistry([]));
    final assistants = await h.container.read(
      assistantRepositoryProvider.future,
    );
    final assistant = await assistants.ensureDefault();
    await assistants.save(
      assistant.copyWith(memoryScope: MemoryScope.assistant),
    );
    final repository = MemoryRepository(h.database);
    await repository.add(
      content: '${'月' * 1750}第一条末尾',
      assistantId: assistant.id,
    );
    await repository.add(
      content: '${'相' * 1750}第二条末尾',
      assistantId: assistant.id,
    );
    h.provider.turns.addAll([
      toolTurn(
        callId: 'read',
        toolName: 'read_memory',
        arguments: '{"query":""}',
      ),
      textTurn('已读取'),
    ]);
    await h.controller().send('读取我启用的记忆');
    final record = (await h.recordsByCall())['read']!;
    expect(utf8.encode(record.result!).length, greaterThan(8 * 1024));
    final replay = h.provider.requests.last.messages
        .expand((m) => m.parts)
        .whereType<ResolvedToolResult>()
        .single;
    expect(replay.content, record.result);
    expect(replay.content, contains('第一条末尾'));
    expect(replay.content, contains('第二条末尾'));
  });

  test('模型输出期间收紧作用域立即阻止全局写入，不因模型请求扩大范围', () async {
    final h = await ToolLoopHarness.create(registry: ToolRegistry([]));
    final assistants = await h.container.read(
      assistantRepositoryProvider.future,
    );
    final assistant = await assistants.ensureDefault();
    await assistants.save(
      assistant.copyWith(memoryScope: MemoryScope.assistantAndGlobal),
    );
    Stream<ChatChunk> narrowedScope() async* {
      await assistants.save(
        assistant.copyWith(memoryScope: MemoryScope.assistant),
      );
      yield* toolTurn(
        callId: 'write',
        toolName: 'write_memory',
        arguments: '{"content":"全局偏好","scope":"global"}',
      );
    }

    h.provider.turns.addAll([narrowedScope(), textTurn('范围不足')]);
    await h.controller().send('保存记忆');
    expect(await MemoryRepository(h.database).watch().first, isEmpty);
    expect((await h.recordsByCall())['write']!.status, ToolCallStatus.failed);
  });
}
