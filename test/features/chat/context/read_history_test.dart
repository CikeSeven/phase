import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:phase/data/models/chat_message.dart';
import 'package:phase/data/models/message_part.dart';
import 'package:phase/features/chat/chat_controller.dart';
import 'package:phase/features/chat/context/read_history_tool.dart';
import 'package:phase/features/tools/tool.dart';

import '../../tools/tool_loop_harness.dart';

void main() {
  test('UTF-8 分页包含元数据和续读开销，中文/表情/超长行不重复或截断字符', () {
    final content = '${'多语言🌙' * 3000}\n第二行\n';
    final output = StringBuffer();
    String? cursor;
    var count = 0;
    do {
      final page = historyPage(
        sourceId: 'source',
        content: content,
        cursor: cursor,
        maxBytes: 512,
      );
      expect(page.ok, isTrue);
      expect(utf8.encode(page.content).length, lessThanOrEqualTo(512));
      final value = jsonDecode(page.content) as Map;
      output.write(value['content']);
      cursor = value['nextCursor'] as String?;
      count++;
      expect(count, lessThan(1000));
    } while (cursor != null);
    expect(output.toString(), content);
    expect(count, greaterThan(1));
  });

  test('游标绑定来源与修订，变化需从头读取', () {
    final first = historyPage(sourceId: 'source', content: 'a' * 9000);
    final cursor = (jsonDecode(first.content) as Map)['nextCursor'] as String;
    expect(
      historyPage(
        sourceId: 'other',
        content: 'a' * 9000,
        cursor: cursor,
      ).errorCode,
      'historyCursor',
    );
    expect(
      historyPage(
        sourceId: 'source',
        content: 'b' * 9000,
        cursor: cursor,
      ).errorCode,
      'historyCursor',
    );
    expect(
      historyPage(
        sourceId: 'source',
        content: 'a' * 9000,
        cursor: 'garbage',
      ).ok,
      isFalse,
    );
  });

  test('只读取当前会话分支，不回传签名、加密状态或其他会话内容', () async {
    final h = await ToolLoopHarness.create(registry: ToolRegistry([]));
    h.provider.turns.add(textTurn('原回答'));
    await h.controller().send('当前任务');
    final repository = await h.conversations();
    final firstBranch = await h.branch();
    await repository.updateMessage(
      messageId: firstBranch.last.id,
      parts: const [
        TextPart(text: '公开正文'),
        ReasoningPart(
          publicText: '公开思考',
          providerData: {
            'signature': 'private-signature',
            'encrypted_content': 'private-cipher',
          },
        ),
      ],
      status: MessageStatus.completed,
    );
    final tool = ReadHistoryTool(repository, await h.toolCalls());
    final context = ToolContext(
      conversationId: h.conversationId()!,
      runId: (await h.latestRun()).id,
      toolCallId: 'fixture',
      storage: await h.container.read(artifactStorageProvider.future),
      attachments: [],
    );
    final page = await tool.execute(
      {'sourceId': firstBranch.last.id},
      context,
      RunCancellation(),
    );
    expect(page.ok, isTrue);
    expect(page.content, contains('公开正文'));
    expect(page.content, contains('公开思考'));
    expect(page.content, isNot(contains('private-signature')));
    expect(page.content, isNot(contains('private-cipher')));
    final other = await repository.createConversation(title: 'other');
    await repository.appendMessage(
      ChatMessage(
        id: 'other-message',
        conversationId: other.id,
        role: ChatRole.user,
        parts: const [TextPart(text: 'outside-scope')],
        createdAt: DateTime(2026),
      ),
    );
    expect(
      (await tool.execute(
        {'sourceId': 'other-message'},
        context,
        RunCancellation(),
      )).errorCode,
      'historyScope',
    );
    await repository.setCurrentMessage(
      h.conversationId()!,
      firstBranch.first.id,
    );
    expect(
      (await tool.execute(
        {'sourceId': firstBranch.last.id},
        context,
        RunCancellation(),
      )).errorCode,
      'historyScope',
    );
  });
}
