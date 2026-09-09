import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/theme/app_theme.dart';
import 'package:phase/data/models/chat_message.dart';
import 'package:phase/features/chat/chat_transcript.dart';
import 'package:phase/features/chat/message_bubble.dart';
import 'package:phase/features/chat/thinking_panel.dart';

List<ChatMessage> _history({int count = 36, String prefix = 'a'}) {
  return List.generate(
    count,
    (index) => ChatMessage(
      id: '$prefix-$index',
      role: index.isEven ? ChatRole.user : ChatRole.assistant,
      content: '第 $index 条消息\n${'用于回看历史的内容。' * (index % 4 + 1)}',
      modelName: 'reading-model',
    ),
  );
}

void main() {
  Future<void> pumpTranscript(
    WidgetTester tester,
    List<ChatMessage> messages, {
    String conversationId = 'first',
    double scale = 1,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: true,
            textScaler: TextScaler.linear(scale),
          ),
          child: child!,
        ),
        home: Scaffold(
          body: ChatTranscript(
            conversationId: conversationId,
            messages: messages,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  ScrollPosition position(WidgetTester tester, {String id = 'first'}) => tester
      .widget<ListView>(find.byKey(ValueKey('transcript-$id')))
      .controller!
      .position;

  testWidgets('首次进入长会话定位真实末端，并惰性创建消息', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final messages = _history(count: 240);
    await pumpTranscript(tester, messages);

    expect(position(tester).extentAfter, lessThan(1));
    expect(find.byKey(const ValueKey('a-239')), findsOneWidget);
    expect(find.byType(MessageBubble).evaluate().length, lessThan(24));
    expect(find.text('回到底部'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('底部跟随流式，回看不抢滚动，点击回到底部后恢复跟随', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final history = _history();
    const reply = ChatMessage(
      id: 'reply',
      role: ChatRole.assistant,
      content: '答案开始',
      status: ChatMessageStatus.streaming,
      modelName: 'streaming-model',
    );
    await pumpTranscript(tester, [...history, reply]);
    final replyElement = tester.element(find.byKey(const ValueKey('reply')));
    final firstBottom = position(tester).pixels;

    final longer = reply.copyWith(content: '答案开始\n${'新的正文段落。\n' * 8}');
    await pumpTranscript(tester, [...history, longer]);
    expect(position(tester).pixels, greaterThan(firstBottom));
    expect(position(tester).extentAfter, lessThan(1));
    expect(
      tester.element(find.byKey(const ValueKey('reply'))),
      same(replyElement),
    );

    await tester.drag(
      find.byKey(const ValueKey('transcript-first')),
      const Offset(0, 430),
    );
    await tester.pumpAndSettle();
    final readingOffset = position(tester).pixels;
    expect(position(tester).extentAfter, greaterThan(96));
    expect(find.text('回到底部'), findsOneWidget);

    final muchLonger = reply.copyWith(content: '${'不应打断历史阅读。\n' * 30}末尾');
    await pumpTranscript(tester, [...history, muchLonger]);
    expect(position(tester).pixels, closeTo(readingOffset, 0.5));
    expect(find.text('回到底部'), findsOneWidget);

    await tester.tap(find.text('回到底部'));
    await tester.pumpAndSettle();
    expect(position(tester).extentAfter, lessThan(1));
    expect(find.text('回到底部'), findsNothing);

    await pumpTranscript(tester, [
      ...history,
      muchLonger.copyWith(content: '${muchLonger.content}\n继续生成\n再增加两行'),
    ]);
    expect(position(tester).extentAfter, lessThan(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('底部附近的小幅回看仍能在下一次增量后跟随', (tester) async {
    await pumpTranscript(tester, _history());
    await tester.drag(
      find.byKey(const ValueKey('transcript-first')),
      const Offset(0, 40),
    );
    await tester.pumpAndSettle();
    final messages = _history();
    await pumpTranscript(tester, [
      ...messages,
      const ChatMessage(
        id: 'new',
        role: ChatRole.assistant,
        content: '紧接着的回复\n第二行',
      ),
    ]);
    expect(position(tester).extentAfter, lessThan(1));
  });

  testWidgets('流式思考完成自动折叠后没有越界，仍停在末端', (tester) async {
    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final history = _history();
    final reply = ChatMessage(
      id: 'reasoning',
      role: ChatRole.assistant,
      content: '答案',
      reasoning: '很长的推演过程。\n' * 24,
      status: ChatMessageStatus.streaming,
    );
    await pumpTranscript(tester, [...history, reply], scale: 1.3);
    final expandedBottom = position(tester).pixels;

    await pumpTranscript(tester, [
      ...history,
      reply.copyWith(status: ChatMessageStatus.done),
    ], scale: 1.3);
    expect(find.text('已思考'), findsOneWidget);
    expect(find.text(reply.reasoning!), findsNothing);
    expect(position(tester).pixels, lessThan(expandedBottom));
    expect(position(tester).outOfRange, isFalse);
    expect(position(tester).extentAfter, lessThan(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('回看时下方思考自动折叠不强拉到底部', (tester) async {
    final history = _history(count: 50);
    final reply = ChatMessage(
      id: 'reasoning',
      role: ChatRole.assistant,
      content: '答案',
      reasoning: '思考过程\n' * 12,
      status: ChatMessageStatus.streaming,
    );
    await pumpTranscript(tester, [...history, reply]);
    await tester.drag(
      find.byKey(const ValueKey('transcript-first')),
      const Offset(0, 900),
    );
    await tester.pumpAndSettle();
    final readingOffset = position(tester).pixels;

    await pumpTranscript(tester, [
      ...history,
      reply.copyWith(status: ChatMessageStatus.done),
    ]);
    expect(position(tester).pixels, closeTo(readingOffset, 0.5));
    expect(position(tester).extentAfter, greaterThan(96));
    expect(find.text('回到底部'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('手动展开的思考经过滚动回收与流式状态切换仍保留', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final history = _history();
    const reply = ChatMessage(
      id: 'manual',
      role: ChatRole.assistant,
      content: '正文答案',
      reasoning: '手动展开后应保留的思考原文',
    );
    await pumpTranscript(tester, [...history, reply]);
    await tester.tap(find.text('已思考'));
    await tester.pumpAndSettle();
    final thinkingState = tester.state(find.byType(ThinkingPanel));
    expect(find.text(reply.reasoning!), findsOneWidget);

    await tester.drag(
      find.byKey(const ValueKey('transcript-first')),
      const Offset(0, 1800),
    );
    await tester.pumpAndSettle();
    expect(find.text('回到底部'), findsOneWidget);
    await tester.tap(find.text('回到底部'));
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(ThinkingPanel)), same(thinkingState));
    expect(find.text(reply.reasoning!), findsOneWidget);

    await pumpTranscript(tester, [
      ...history,
      reply.copyWith(status: ChatMessageStatus.streaming, content: '正文增量'),
    ]);
    await pumpTranscript(tester, [...history, reply]);
    expect(tester.state(find.byType(ThinkingPanel)), same(thinkingState));
    expect(find.text(reply.reasoning!), findsOneWidget);
  });

  testWidgets('键盘缩小视口时底部跟随，回看时不跳转', (tester) async {
    tester.view.physicalSize = const Size(360, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await pumpTranscript(tester, _history());

    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await tester.pumpAndSettle();
    expect(position(tester).extentAfter, lessThan(1));
    await tester.drag(
      find.byKey(const ValueKey('transcript-first')),
      const Offset(0, 400),
    );
    await tester.pumpAndSettle();
    final readingOffset = position(tester).pixels;
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    await tester.pumpAndSettle();
    expect(position(tester).pixels, closeTo(readingOffset, 0.5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('切换会话会归位而不继承旧的回看位置', (tester) async {
    await pumpTranscript(tester, _history());
    await tester.drag(
      find.byKey(const ValueKey('transcript-first')),
      const Offset(0, 500),
    );
    await tester.pumpAndSettle();
    expect(find.text('回到底部'), findsOneWidget);

    await pumpTranscript(
      tester,
      _history(prefix: 'b', count: 22),
      conversationId: 'second',
    );
    expect(position(tester, id: 'second').extentAfter, lessThan(1));
    expect(find.byKey(const ValueKey('b-21')), findsOneWidget);
    expect(find.text('回到底部'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
