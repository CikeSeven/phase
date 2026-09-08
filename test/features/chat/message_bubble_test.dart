import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase/data/models/chat_message.dart';
import 'package:phase/features/chat/message_bubble.dart';

ChatMessage _aiMessage(String content, ChatMessageStatus status) {
  return ChatMessage(
    id: 'm1',
    role: ChatRole.assistant,
    content: content,
    status: status,
    createdAt: DateTime(2026),
    modelName: 'test-model',
  );
}

void main() {
  Future<void> pumpBubble(WidgetTester tester, ChatMessage message) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [MessageBubble(message: message)],
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('流式占位（空内容）不报错', (tester) async {
    await pumpBubble(
      tester,
      _aiMessage('', ChatMessageStatus.streaming),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('流式半截 Markdown（未闭合代码块）不报错', (tester) async {
    await pumpBubble(
      tester,
      _aiMessage('好的，代码如下：\n```dart\nvoid main() {', ChatMessageStatus.streaming),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('流式半截表格不报错', (tester) async {
    await pumpBubble(
      tester,
      _aiMessage('| 列A | 列B |\n| --- |', ChatMessageStatus.streaming),
    );
    expect(tester.takeException(), isNull);
  });
}
