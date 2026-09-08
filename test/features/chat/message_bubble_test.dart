import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:phase/core/theme/app_theme.dart';
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

  group('思考区块', () {
    ChatMessage reasoningMessage({
      String? reasoning = '推演过程',
      ChatMessageStatus status = ChatMessageStatus.done,
    }) {
      return ChatMessage(
        role: ChatRole.assistant,
        content: '答案',
        reasoning: reasoning,
        status: status,
        modelName: 'model-a',
      );
    }

    Widget buildBubble(ChatMessage message) {
      return MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: MessageBubble(message: message)),
      );
    }

    testWidgets('有 reasoning 时渲染思考区块，完成后默认收起', (tester) async {
      await tester.pumpWidget(buildBubble(reasoningMessage()));

      expect(find.byIcon(Symbols.psychology), findsOneWidget);
      expect(find.text('已思考'), findsOneWidget);
      // 完成后默认收起，思考全文不可见。
      expect(find.text('推演过程'), findsNothing);

      // 手动展开后可见。
      await tester.tap(find.text('已思考'));
      await tester.pumpAndSettle();
      expect(find.text('推演过程'), findsOneWidget);
    });

    testWidgets('reasoning 流式中显示「思考中…」且默认展开', (tester) async {
      await tester.pumpWidget(
        buildBubble(
          reasoningMessage(status: ChatMessageStatus.streaming),
        ),
      );
      // 有持续的光标动画，不能 pumpAndSettle。
      await tester.pump();

      expect(find.text('思考中…'), findsOneWidget);
      expect(find.text('推演过程'), findsOneWidget);
    });

    testWidgets('无 reasoning 时不渲染思考区块', (tester) async {
      await tester.pumpWidget(buildBubble(reasoningMessage(reasoning: null)));

      expect(find.byIcon(Symbols.psychology), findsNothing);
      expect(find.text('已思考'), findsNothing);
      expect(find.text('思考中…'), findsNothing);
    });

    testWidgets('空串 reasoning 同样不渲染思考区块', (tester) async {
      await tester.pumpWidget(buildBubble(reasoningMessage(reasoning: '')));

      expect(find.byIcon(Symbols.psychology), findsNothing);
    });
  });
}
