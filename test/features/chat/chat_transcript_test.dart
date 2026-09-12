import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:phase/core/theme/app_theme.dart';
import 'package:phase/data/models/chat_message.dart';
import 'package:phase/data/models/message_part.dart';
import 'package:phase/features/chat/chat_transcript.dart';
import 'package:phase/features/chat/message_bubble.dart';
import 'package:phase/features/chat/thinking_panel.dart';

List<ChatMessage> _history({int count = 36, String prefix = 'a'}) {
  return List.generate(
    count,
    (index) => _message(
      id: '$prefix-$index',
      role: index.isEven ? ChatRole.user : ChatRole.assistant,
      text: '第 $index 条消息\n${'用于回看历史的内容。' * (index % 4 + 1)}',
    ),
  );
}

/// Part 结构下的消息构造；正文与思考各归一个 Part。
ChatMessage _message({
  required String id,
  ChatRole role = ChatRole.assistant,
  String text = '',
  String? thinking,
  MessageStatus status = MessageStatus.completed,
  String? modelLabel,
}) {
  return ChatMessage(
    id: id,
    conversationId: 'first',
    role: role,
    status: status,
    modelLabel: modelLabel,
    parts: [
      if (thinking != null) ReasoningPart(publicText: thinking),
      if (text.isNotEmpty) TextPart(text: text),
    ],
    createdAt: DateTime(2026),
  );
}

/// Part 结构下的局部更新：正文/思考替换（空串表示移除）与状态切换。
extension on ChatMessage {
  ChatMessage withParts({
    String? text,
    String? thinking,
    MessageStatus? status,
  }) {
    final next = <MessagePart>[];
    for (final part in parts) {
      switch (part) {
        case TextPart():
          if (text == null) next.add(part);
        case ReasoningPart():
          if (thinking == null) next.add(part);
        default:
          next.add(part);
      }
    }
    if (text != null && text.isNotEmpty) next.add(TextPart(text: text));
    if (thinking != null && thinking.isNotEmpty) {
      next.add(ReasoningPart(publicText: thinking));
    }
    return copyWith(parts: next, status: status);
  }

  String get thinkingText =>
      parts.whereType<ReasoningPart>().map((part) => part.publicText).join();
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
    final reply = _message(
      id: 'reply',
      text: '答案开始',
      status: MessageStatus.streaming,
      modelLabel: 'streaming-model',
    );
    await pumpTranscript(tester, [...history, reply]);
    final replyElement = tester.element(find.byKey(const ValueKey('reply')));
    final firstBottom = position(tester).pixels;

    final longer = reply.withParts(text: '答案开始\n${'新的正文段落。\n' * 8}');
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

    final muchLonger = reply.withParts(text: '${'不应打断历史阅读。\n' * 30}末尾');
    await pumpTranscript(tester, [...history, muchLonger]);
    expect(position(tester).pixels, closeTo(readingOffset, 0.5));
    expect(find.byTooltip('回到底部'), findsOneWidget);

    await tester.tap(find.byTooltip('回到底部'));
    await tester.pumpAndSettle();
    expect(position(tester).extentAfter, lessThan(1));
    expect(find.byTooltip('回到底部'), findsNothing);

    await pumpTranscript(tester, [
      ...history,
      muchLonger.withParts(
        text:
            '${muchLonger.parts.whereType<TextPart>().map((p) => p.text).join()}'
            '\n继续生成\n再增加两行',
      ),
    ]);
    expect(position(tester).extentAfter, lessThan(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('底部附近的小幅回看不被拉回，下一次增量也不解除阅读位置', (tester) async {
    await pumpTranscript(tester, _history());
    final bottom = position(tester).pixels;
    await tester.drag(
      find.byKey(const ValueKey('transcript-first')),
      const Offset(0, 40),
    );
    await tester.pumpAndSettle();
    final readingOffset = position(tester).pixels;
    // 离开底部一小段就是回看：停在原处，不因为离底部近而被拉回。
    expect(readingOffset, lessThan(bottom - 1));

    final messages = _history();
    await pumpTranscript(tester, [
      ...messages,
      _message(id: 'new', role: ChatRole.assistant, text: '紧接着的回复\n第二行'),
    ]);
    expect(position(tester).pixels, closeTo(readingOffset, 0.5));
    expect(position(tester).extentAfter, greaterThan(1));

    // 回到真正底部后才恢复跟随。
    await tester.drag(
      find.byKey(const ValueKey('transcript-first')),
      const Offset(0, -4000),
    );
    await tester.pumpAndSettle();
    expect(position(tester).extentAfter, lessThan(1));
  });

  testWidgets('空闲状态下的重建不会把回看位置拉回底部', (tester) async {
    final messages = _history();
    await pumpTranscript(tester, messages);
    await tester.drag(
      find.byKey(const ValueKey('transcript-first')),
      const Offset(0, 40),
    );
    await tester.pumpAndSettle();
    final readingOffset = position(tester).pixels;

    // 同一批消息重新构建（例如数据库流再次发出、尺寸变化）：位置保持。
    await pumpTranscript(tester, messages);
    expect(position(tester).pixels, closeTo(readingOffset, 0.5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('流式思考完成自动收起全文且无越界，未回看时保持末端', (tester) async {
    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final history = _history();
    final reply = _message(
      id: 'reasoning',
      role: ChatRole.assistant,
      text: '答案',
      thinking: '很长的推演过程。\n' * 24,
      status: MessageStatus.streaming,
    );
    await pumpTranscript(tester, [...history, reply], scale: 1.3);
    final panelState = tester.state(find.byType(ThinkingPanel));

    await pumpTranscript(tester, [
      ...history,
      reply.withParts(status: MessageStatus.completed),
    ], scale: 1.3);
    expect(find.text('已思考'), findsOneWidget);
    // 无手动操作时思考结束自动收起，内容不再展示。
    expect(find.text(reply.thinkingText), findsNothing);
    expect(tester.state(find.byType(ThinkingPanel)), same(panelState));
    expect(position(tester).outOfRange, isFalse);
    expect(position(tester).extentAfter, lessThan(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('回看时下方思考完成自动收起，但阅读位置不被打断', (tester) async {
    final history = _history(count: 50);
    final reply = _message(
      id: 'reasoning',
      role: ChatRole.assistant,
      text: '答案',
      thinking: '思考过程\n' * 12,
      status: MessageStatus.streaming,
    );
    await pumpTranscript(tester, [...history, reply]);
    await tester.drag(
      find.byKey(const ValueKey('transcript-first')),
      const Offset(0, 900),
    );
    await tester.pumpAndSettle();

    await pumpTranscript(tester, [
      ...history,
      reply.withParts(status: MessageStatus.completed),
    ]);
    // 收起的是列表末端内容：滚动范围随内容收窄，位置自然落到新末端，
    // 不发生动画式强拉（按钮不再出现=没有更多未读内容），内容已收起。
    expect(find.text(reply.thinkingText), findsNothing);
    expect(position(tester).pixels, position(tester).maxScrollExtent);
    expect(position(tester).outOfRange, isFalse);
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
      final reply = _message(
        id: 'manual',
        role: ChatRole.assistant,
        text: '正文答案',
        thinking: '手动状态应保留的思考原文',
        status: MessageStatus.streaming,
      );
      await pumpTranscript(tester, [...history, reply]);
      await tester.tap(find.textContaining('思考中…'));
      await tester.pumpAndSettle();
      if (expanded) {
        await tester.tap(find.textContaining('思考中…'));
        await tester.pumpAndSettle();
      }
      final thinkingState = tester.state(find.byType(ThinkingPanel));
      expect(
        find.text(reply.thinkingText),
        expanded ? findsOneWidget : findsNothing,
      );

      await tester.drag(
        find.byKey(const ValueKey('transcript-first')),
        const Offset(0, 1800),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('回到底部'), findsOneWidget);
      final updated = reply.withParts(
        text: '完整正文答案',
        thinking: '第一步分析\n第二步验证\n完整推演结论',
        status: MessageStatus.completed,
      );
      await pumpTranscript(tester, [...history, updated]);
      await tester.tap(find.byTooltip('回到底部'));
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(ThinkingPanel)), same(thinkingState));
      expect(
        find.text(updated.thinkingText),
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
      final reply = _message(
        id: 'long-reasoning',
        role: ChatRole.assistant,
        text: '短答',
        thinking: '简短思考',
        status: MessageStatus.streaming,
      );
      final longReasoning = List.generate(
        300,
        (index) => '推演第 $index 行',
      ).join('\n');
      await pumpTranscript(tester, [...history, reply], scale: 1.3);
      await tester.tap(find.textContaining('思考中…'));
      await tester.pumpAndSettle();
      final updated = reply.withParts(
        thinking: longReasoning,
        status: MessageStatus.completed,
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
      // 思考内容限高 260：展开 300 行也只增加一个限高视口的滚动范围。
      expect(position(tester).extentAfter, greaterThan(200));
      expect(position(tester).extentAfter, lessThan(400));
      expect(
        tester
            .getSize(
              find.descendant(
                of: find.byType(ThinkingPanel),
                matching: find.byType(SingleChildScrollView),
              ),
            )
            .height,
        lessThanOrEqualTo(260),
      );
      expect(find.byTooltip('回到底部'), findsOneWidget);

      await pumpTranscript(tester, [
        ...history,
        updated.withParts(text: '新的正文增量\n不应打断阅读'),
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
