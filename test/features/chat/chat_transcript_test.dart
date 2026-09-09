import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
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
    bool dark = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: dark ? AppTheme.dark() : AppTheme.light(),
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
    expect(find.byTooltip('回到底部'), findsNothing);
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
    expect(find.byTooltip('回到底部'), findsOneWidget);

    final muchLonger = reply.copyWith(content: '${'不应打断历史阅读。\n' * 30}末尾');
    await pumpTranscript(tester, [...history, muchLonger]);
    expect(position(tester).pixels, closeTo(readingOffset, 0.5));
    expect(find.byTooltip('回到底部'), findsOneWidget);

    await tester.tap(find.byTooltip('回到底部'));
    await tester.pumpAndSettle();
    expect(position(tester).extentAfter, lessThan(1));
    expect(find.byTooltip('回到底部'), findsNothing);

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

  testWidgets('流式思考完成仍展示全文且无越界，未回看时保持末端', (tester) async {
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
    final reasoningHeight = tester.getSize(find.text(reply.reasoning!)).height;
    final panelState = tester.state(find.byType(ThinkingPanel));

    await pumpTranscript(tester, [
      ...history,
      reply.copyWith(status: ChatMessageStatus.done),
    ], scale: 1.3);
    expect(find.text('已思考'), findsOneWidget);
    expect(find.text(reply.reasoning!), findsOneWidget);
    expect(tester.state(find.byType(ThinkingPanel)), same(panelState));
    expect(tester.getSize(find.text(reply.reasoning!)).height, reasoningHeight);
    expect(position(tester).outOfRange, isFalse);
    expect(position(tester).extentAfter, lessThan(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('回看时下方思考完成不收起也不强拉到底部', (tester) async {
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
    expect(find.byTooltip('回到底部'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final expanded in [false, true]) {
    testWidgets('手动${expanded ? '展开' : '折叠'}思考跨消息更新、滚动回收与完成仍保留', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final history = _history();
      const reply = ChatMessage(
        id: 'manual',
        role: ChatRole.assistant,
        content: '正文答案',
        reasoning: '手动状态应保留的思考原文',
        status: ChatMessageStatus.streaming,
      );
      await pumpTranscript(tester, [...history, reply]);
      await tester.tap(find.text('思考中…'));
      await tester.pumpAndSettle();
      if (expanded) {
        await tester.tap(find.text('思考中…'));
        await tester.pumpAndSettle();
      }
      final thinkingState = tester.state(find.byType(ThinkingPanel));
      expect(
        find.text(reply.reasoning!),
        expanded ? findsOneWidget : findsNothing,
      );

      await tester.drag(
        find.byKey(const ValueKey('transcript-first')),
        const Offset(0, 1800),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('回到底部'), findsOneWidget);
      final updated = reply.copyWith(
        content: '完整正文答案',
        reasoning: '第一步分析\n第二步验证\n完整推演结论',
        status: ChatMessageStatus.done,
      );
      await pumpTranscript(tester, [...history, updated]);
      await tester.tap(find.byTooltip('回到底部'));
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(ThinkingPanel)), same(thinkingState));
      expect(
        find.text(updated.reasoning!),
        expanded ? findsOneWidget : findsNothing,
      );
      expect(find.text('已思考'), findsOneWidget);
      expect(find.text('完整正文答案', findRichText: true), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final width in [320.0, 360.0]) {
    testWidgets('${width}dp 已贴底短答展开 300 行思考保留标题与内容起点', (tester) async {
      tester.view.physicalSize = Size(width, 680);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final history = _history();
      const reply = ChatMessage(
        id: 'long-reasoning',
        role: ChatRole.assistant,
        content: '短答',
        reasoning: '简短思考',
        status: ChatMessageStatus.streaming,
      );
      final longReasoning = List.generate(
        300,
        (index) => '推演第 $index 行',
      ).join('\n');
      await pumpTranscript(tester, [...history, reply], scale: 1.3);
      await tester.tap(find.text('思考中…'));
      await tester.pumpAndSettle();
      final updated = reply.copyWith(
        reasoning: longReasoning,
        status: ChatMessageStatus.done,
      );
      await pumpTranscript(tester, [...history, updated], scale: 1.3);
      expect(position(tester).extentAfter, lessThan(1));
      expect(find.text(longReasoning), findsNothing);
      final header = find.text('已思考');
      final before = tester.getTopLeft(header).dy;
      final oldOffset = position(tester).pixels;
      final viewport = tester.getRect(
        find.byKey(const ValueKey('transcript-first')),
      );

      await tester.tap(header);
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(header).dy, closeTo(before, 0.5));
      expect(tester.getTopLeft(header).dy, greaterThanOrEqualTo(viewport.top));
      expect(tester.getBottomRight(header).dy, lessThan(viewport.bottom));
      expect(
        tester.getTopLeft(find.text(longReasoning)).dy,
        lessThan(viewport.bottom),
      );
      expect(position(tester).pixels, closeTo(oldOffset, 0.5));
      expect(position(tester).extentAfter, greaterThan(1000));
      expect(find.byTooltip('回到底部'), findsOneWidget);

      await pumpTranscript(tester, [
        ...history,
        updated.copyWith(content: '新的正文增量\n不应打断阅读'),
      ], scale: 1.3);
      expect(tester.getTopLeft(header).dy, closeTo(before, 0.5));
      await tester.tap(header);
      await tester.pumpAndSettle();
      expect(find.text(longReasoning), findsNothing);
      expect(tester.getRect(header).overlaps(viewport), isTrue);
      expect(position(tester).outOfRange, isFalse);
      await tester.tap(header);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('回到底部'));
      await tester.pumpAndSettle();
      expect(position(tester).extentAfter, lessThan(1));
      expect(tester.takeException(), isNull);
    });
  }

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
    expect(find.byTooltip('回到底部'), findsOneWidget);

    await pumpTranscript(
      tester,
      _history(prefix: 'b', count: 22),
      conversationId: 'second',
    );
    expect(position(tester, id: 'second').extentAfter, lessThan(1));
    expect(find.byKey(const ValueKey('b-21')), findsOneWidget);
    expect(find.byTooltip('回到底部'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final dark in [false, true]) {
    for (final size in [
      const Size(320, 640),
      const Size(360, 760),
      const Size(800, 360),
      const Size(1000, 700),
    ]) {
      testWidgets('$dark $size 大字回到底部仅有图标，触区、语义与对比度完整', (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.reset);
        await pumpTranscript(tester, _history(), scale: 2, dark: dark);
        final transcript = find.byKey(const ValueKey('transcript-first'));
        await tester.drag(transcript, const Offset(0, 450));
        await tester.pumpAndSettle();

        final button = find.byKey(const ValueKey('chat-scroll-to-bottom'));
        expect(find.text('回到底部'), findsNothing);
        expect(find.byTooltip('回到底部'), findsOneWidget);
        expect(
          find.descendant(of: button, matching: find.byType(Text)),
          findsNothing,
        );
        expect(find.byIcon(Symbols.arrow_downward), findsOneWidget);
        expect(tester.getSize(button), const Size.square(48));
        final viewport = tester.getRect(transcript);
        final bounds = tester.getRect(button);
        expect(bounds.right, closeTo(viewport.right - 16, 0.01));
        expect(bounds.bottom, closeTo(viewport.bottom - 12, 0.01));
        expect(
          tester.getSemantics(button),
          matchesSemantics(
            tooltip: '回到底部',
            isButton: true,
            hasEnabledState: true,
            isEnabled: true,
            isFocusable: true,
            hasTapAction: true,
            hasFocusAction: true,
          ),
        );
        final style = tester.widget<IconButton>(button).style!;
        final background = style.backgroundColor!.resolve({})!;
        final foreground = style.foregroundColor!.resolve({})!;
        final luminances = [
          background.computeLuminance(),
          Color.alphaBlend(foreground, background).computeLuminance(),
        ]..sort();
        expect(
          (luminances.last + 0.05) / (luminances.first + 0.05),
          greaterThanOrEqualTo(4.5),
        );
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(position(tester).extentAfter, lessThan(1));
        expect(find.byTooltip('回到底部'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
