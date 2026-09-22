import 'package:phase/data/models/token_usage.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:phase/core/theme/app_theme.dart';
import 'package:phase/data/models/chat_message.dart';
import 'package:phase/data/models/conversation.dart';
import 'package:phase/data/models/message_part.dart';
import 'package:phase/data/models/profile_model.dart';
import 'package:phase/data/models/tool_call_record.dart';
import 'package:phase/data/models/tool_policy.dart';
import 'package:phase/data/repositories/conversation_repository.dart';
import 'package:phase/data/repositories/tool_call_repository.dart';
import 'package:phase/features/chat/chat_controller.dart';
import 'package:phase/features/chat/chat_page.dart';
import 'package:phase/features/chat/chat_transcript.dart';
import 'package:phase/features/chat/message_bubble.dart';
import 'package:phase/features/chat/thinking_panel.dart';
import 'package:phase/features/chat/tool_call_card.dart';
import 'package:phase/features/tools/tool.dart';
import 'package:phase/features/tools/tool_card.dart';

import '../tools/tool_loop_harness.dart';

/// 一次运行的连续助手消息合并为一个回答区：数据层仍是一轮一条消息，
/// 视图层按运行合并，工具卡片留在回答区里。边界：夹用户消息、重新生成、
/// 流式与缺少 runId 的老消息。
void main() {
  ChatMessage message({
    required String id,
    ChatRole role = ChatRole.assistant,
    String? runId,
    String text = '',
    String? thinking,
    List<MessagePart> extra = const [],
    MessageStatus status = MessageStatus.completed,
    String? modelLabel,
    TokenUsage? usage,
    int? thinkingDurationMs,
  }) {
    return ChatMessage(
      id: id,
      conversationId: 'c1',
      role: role,
      runId: runId,
      status: status,
      modelLabel: modelLabel,
      usage: usage,
      thinkingDurationMs: thinkingDurationMs,
      parts: [
        if (thinking != null && thinking.isNotEmpty)
          ReasoningPart(publicText: thinking),
        if (text.isNotEmpty) TextPart(text: text),
        ...extra,
      ],
      createdAt: DateTime(2026),
    );
  }

  ChatMessage user(String id, String text) =>
      message(id: id, role: ChatRole.user, text: text);

  /// 隐藏的工具结果消息：回填给模型的上下文，不作为正文展示。
  ChatMessage toolResult(String id, String callId, String text) => message(
    id: id,
    role: ChatRole.tool,
    text: text,
    extra: [ToolResultPart(toolCallId: callId)],
  );

  List<MessagePart> toolCall(String callId) => [
    ToolCallPart(toolCallId: callId),
  ];

  ConversationThread threadOf(List<ChatMessage> branch) {
    final tail = branch.isEmpty ? null : branch.last.id;
    return ConversationThread(
      conversation: Conversation(
        id: 'c1',
        title: '测试会话',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        currentMessageId: tail,
      ),
      messages: branch,
      branch: branch,
      currentMessageId: tail,
    );
  }

  List<String> textsOf(ChatMessage merged) => [
    for (final part in merged.parts.whereType<TextPart>()) part.text,
  ];

  /// 拼接后的正文：合并会在两轮之间插入段落分隔，逐段断言容易绑死实现细节。
  String joinedText(ChatMessage merged) =>
      merged.parts.whereType<TextPart>().map((part) => part.text).join().trim();

  List<String> idsOf(List<ChatMessage> messages) => [
    for (final item in messages) item.id,
  ];

  group('视图消息合并规则', () {
    test('单轮回答（无工具）不产生额外的合并消息', () {
      final answer = message(id: 'a1', runId: 'run-1', text: '一次性回答');
      final view = visibleMessages(
        threadOf([user('u1', '问题'), answer]),
        const ChatState(),
      );

      expect(idsOf(view), ['u1', 'a1']);
      expect(view.last, same(answer));
    });

    test('一次运行的两轮工具循环合并为一个回答区，Part 按顺序拼接', () {
      final first = message(
        id: 'm1',
        runId: 'run-1',
        text: '先读取文件',
        extra: toolCall('tool-1'),
      );
      final second = message(
        id: 'm2',
        runId: 'run-1',
        text: '文件里有三行',
        extra: toolCall('tool-2'),
      );
      final view = visibleMessages(
        threadOf([
          user('u1', '看下文件'),
          first,
          toolResult('t1', 'tool-1', '三行内容'),
          second,
        ]),
        const ChatState(),
      );

      // 用户输入 + 一个回答区；工具结果消息不出现在视图里。
      expect(idsOf(view), ['u1', 'm1']);
      final merged = view.last;
      // 合并消息沿用首条身份：流式新增一轮不重建气泡。
      expect(merged.id, 'm1');
      // 两轮正文留出空行，不连成一段；两次调用的引用都还在。
      expect(joinedText(merged), '先读取文件文件里有三行');
      final toolCallIds = [
        for (final part in merged.parts.whereType<ToolCallPart>())
          part.toolCallId,
      ];
      expect(toolCallIds, ['tool-1', 'tool-2']);
      // Part 顺序保持：第一轮正文 → 第一次调用 → 第二轮正文 → 第二次调用。
      expect(merged.parts.indexWhere((part) => part is ToolCallPart), 1);
      expect(
        merged.parts.lastIndexWhere(
          (part) => part is TextPart && part.text == '文件里有三行',
        ),
        merged.parts.length - 2,
      );
    });

    test('三次以上的轮次继续合并，各轮思考各自成区', () {
      final view = visibleMessages(
        threadOf([
          user('u1', '多轮'),
          message(id: 'm1', runId: 'run-1', text: '第一轮', thinking: '想第一步'),
          toolResult('t1', 'tool-1', '结果一'),
          message(id: 'm2', runId: 'run-1', text: '第二轮', thinking: '想第二步'),
          message(id: 'm3', runId: 'run-1', text: '第三轮'),
        ]),
        const ChatState(),
      );

      expect(idsOf(view), ['u1', 'm1']);
      // 每轮的思考各自成区：中间隔着那一轮的正文，不再拼成一段。
      final thinking = view.last.parts
          .whereType<ReasoningPart>()
          .map((part) => part.publicText)
          .toList();
      expect(thinking, ['想第一步', '想第二步']);
      // 两轮正文之间补一个空行（不留空行会连成一句话）。
      expect(joinedText(view.last), '第一轮第二轮\n\n第三轮');
    });

    test('状态取最后一次，任一轮流式则按流式展示', () {
      final completed = message(id: 'm1', runId: 'run-1', text: '第一轮');
      final streaming = message(
        id: 'm2',
        runId: 'run-1',
        text: '第二轮',
        status: MessageStatus.streaming,
      );
      final failed = message(
        id: 'm3',
        runId: 'run-2',
        text: '第三轮',
        status: MessageStatus.failed,
      );

      expect(
        visibleMessages(
          threadOf([completed, streaming]),
          const ChatState(),
        ).single.status,
        MessageStatus.streaming,
      );
      // 终态按最后一条：错误收场的那一轮不会被前面的 completed 盖掉；
      // runId 不同则不合并，两条各自保留自己的状态。
      final view = visibleMessages(
        threadOf([streaming, failed]),
        const ChatState(),
      );
      expect(view, hasLength(2));
      expect(view.first.status, MessageStatus.streaming);
      expect(view.last.status, MessageStatus.failed);
    });

    test('模型名取第一条有值的，用量取最后一次有值的，思考耗时合计', () {
      const firstUsage = TokenUsage(promptTokens: 10, outputTokens: 20);
      const lastUsage = TokenUsage(promptTokens: 30, outputTokens: 40);
      final view = visibleMessages(
        threadOf([
          message(
            id: 'm1',
            runId: 'run-1',
            text: '第一轮',
            thinking: '第一轮思考',
            modelLabel: 'model-a',
            usage: firstUsage,
            thinkingDurationMs: 1200,
          ),
          message(
            id: 'm2',
            runId: 'run-1',
            text: '第二轮',
            thinking: '第二轮思考',
            usage: lastUsage,
            thinkingDurationMs: 800,
          ),
        ]),
        const ChatState(),
      );

      final merged = view.single;
      expect(merged.modelLabel, 'model-a');
      expect(merged.usage, same(lastUsage));
      expect(merged.thinkingDurationMs, 2000);
      expect(
        merged.parts.whereType<ReasoningPart>().map((part) => part.durationMs),
        [1200, 800],
      );
    });

    test('模型名只有后一轮有值时取它，思考耗时缺一轮时为有值的那轮', () {
      final view = visibleMessages(
        threadOf([
          message(
            id: 'm1',
            runId: 'run-1',
            text: '第一轮',
            thinkingDurationMs: 900,
          ),
          message(id: 'm2', runId: 'run-1', text: '第二轮', modelLabel: 'model-b'),
        ]),
        const ChatState(),
      );

      expect(view.single.modelLabel, 'model-b');
      expect(view.single.thinkingDurationMs, 900);
    });

    test('两次运行之间夹着用户消息时不合并', () {
      final view = visibleMessages(
        threadOf([
          user('u1', '第一个问题'),
          message(id: 'a1', runId: 'run-1', text: '第一个回答'),
          user('u2', '第二个问题'),
          message(id: 'a2', runId: 'run-2', text: '第二个回答'),
        ]),
        const ChatState(),
      );

      expect(idsOf(view), ['u1', 'a1', 'u2', 'a2']);
    });

    test('重新生成产生的新回答与旧回答不合并', () {
      final view = visibleMessages(
        threadOf([
          user('u1', '同一个问题'),
          message(id: 'old', runId: 'run-1', text: '旧回答'),
          message(id: 'new', runId: 'run-2', text: '新回答'),
        ]),
        const ChatState(),
      );

      expect(idsOf(view), ['u1', 'old', 'new']);
    });

    test('缺少 runId 的老消息相邻时按同一次运行合并，与新消息不混同', () {
      final legacy = visibleMessages(
        threadOf([
          message(id: 'l1', text: '老回答上半段'),
          message(id: 'l2', text: '老回答下半段'),
        ]),
        const ChatState(),
      );
      expect(idsOf(legacy), ['l1']);
      expect(joinedText(legacy.single), '老回答上半段\n\n老回答下半段');

      final mixed = visibleMessages(
        threadOf([
          message(id: 'l1', runId: 'run-1', text: '有运行的回答'),
          message(id: 'l2', text: '没有运行信息的回答'),
        ]),
        const ChatState(),
      );
      expect(idsOf(mixed), ['l1', 'l2']);
    });

    test('流式增量留在上一轮时，不覆盖已落库的正文与工具卡片', () {
      // 工具结果消息刚落库、下一轮助手消息还没建立：此时流式内容属于上一轮，
      // 覆盖已落库的助手消息会把它的工具卡片抹掉。
      final view = visibleMessages(
        threadOf([
          user('u1', '看下文件'),
          message(
            id: 'm1',
            runId: 'run-1',
            text: '先读取文件',
            extra: toolCall('tool-1'),
          ),
          toolResult('t1', 'tool-1', '三行内容'),
        ]),
        const ChatState(
          isGenerating: true,
          streamingParts: [TextPart(text: '先读取文件')],
        ),
      );

      expect(idsOf(view), ['u1', 'm1']);
      expect(view.last.parts.whereType<ToolCallPart>(), hasLength(1));
      expect(textsOf(view.last), ['先读取文件']);
    });

    test('流式中的最后一条与已落库的前几轮合并，生成光标留在回答区末尾', () {
      final view = visibleMessages(
        threadOf([
          user('u1', '看下文件'),
          message(
            id: 'm1',
            runId: 'run-1',
            text: '先读取文件',
            extra: toolCall('tool-1'),
          ),
          toolResult('t1', 'tool-1', '三行内容'),
          message(id: 'm2', runId: 'run-1'),
        ]),
        const ChatState(
          isGenerating: true,
          streamingParts: [
            TextPart(text: '正在总结'),
            ToolCallPart(toolCallId: 'tool-2'),
          ],
          streamingMessageId: 'm2',
        ),
      );

      expect(idsOf(view), ['u1', 'm1']);
      final merged = view.last;
      expect(merged.status, MessageStatus.streaming);
      expect(joinedText(merged), '先读取文件正在总结');
      expect(merged.parts.last, isA<ToolCallPart>());
    });
  });

  group('聊天流渲染', () {
    /// 一次运行两轮工具循环的消息：m1（正文 + 调用）→ 隐藏的结果 → m2。
    List<ChatMessage> twoTurnBranch() => [
      user('u1', '读一下文件再总结'),
      message(
        id: 'm1',
        runId: 'run-1',
        text: '先读取文件',
        extra: toolCall('tool-1'),
      ),
      toolResult('t1', 'tool-1', '三行内容'),
      message(
        id: 'm2',
        runId: 'run-1',
        text: '文件里有三行',
        extra: toolCall('tool-2'),
      ),
    ];

    ToolCallRecord record(String id) => ToolCallRecord(
      id: id,
      runId: 'run-1',
      assistantMessageId: 'm1',
      toolName: 'read_file',
      arguments: const {},
      target: '读取文件「notes.md」',
      channel: ExecutionChannel.app,
      defaultPolicy: ToolPolicy.allow,
      status: ToolCallStatus.succeeded,
      result: '读到了三行',
      createdAt: DateTime(2026),
    );

    Future<void> pumpTranscript(
      WidgetTester tester,
      List<ChatMessage> messages, {
      Map<String, ToolCallRecord> records = const {},
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            toolCallRepositoryProvider.overrideWith(
              (ref) => _FakeToolCalls(records),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
            home: Scaffold(
              body: ChatTranscript(conversationId: 'c1', messages: messages),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('一次运行的两轮工具循环渲染成一个回答区，卡片在回答区内', (tester) async {
      final messages = visibleMessages(
        threadOf(twoTurnBranch()),
        const ChatState(),
      );
      await pumpTranscript(
        tester,
        messages,
        records: {'tool-1': record('tool-1'), 'tool-2': record('tool-2')},
      );

      // 用户输入 + 一个回答区：不出现「AI 消息 → 工具卡片 → 又一条 AI 消息」。
      final bubbles = tester
          .widgetList<MessageBubble>(find.byType(MessageBubble))
          .toList();
      expect(bubbles, hasLength(2));
      // 一个回答区只有一个操作入口，不与用户气泡凑成两个。
      expect(find.byTooltip('消息操作'), findsOneWidget);

      final answer = bubbles.last.message;
      expect(joinedText(answer), '先读取文件文件里有三行');
      // 正文按 Part 顺序交错：两段正文各自渲染，工具卡片插在中间。
      final markdowns = tester
          .widgetList<GptMarkdown>(find.byType(GptMarkdown))
          .toList();
      expect(markdowns, hasLength(2));
      expect(markdowns.first.data, '先读取文件');
      expect(markdowns.last.data, '文件里有三行');
      // 回答区内部按 Part 顺序：正文 → 该轮调用 → 下一轮正文 → 该轮调用。
      final markdownInAnswer = find.descendant(
        of: find.byType(MessageBubble).last,
        matching: find.byType(GptMarkdown),
      );
      final cardsInAnswer = find.descendant(
        of: find.byType(MessageBubble).last,
        matching: find.byType(ToolCard),
      );
      expect(markdownInAnswer, findsNWidgets(2));
      expect(cardsInAnswer, findsNWidgets(2));
      final firstText = tester.getRect(markdownInAnswer.at(0));
      final secondText = tester.getRect(markdownInAnswer.at(1));
      final firstCard = tester.getRect(cardsInAnswer.at(0));
      final secondCard = tester.getRect(cardsInAnswer.at(1));
      // 第一张卡片夹在两段正文之间，第二张跟在第二段正文之后。
      expect(firstCard.top, greaterThanOrEqualTo(firstText.bottom - 1));
      expect(firstCard.bottom, lessThanOrEqualTo(secondText.top + 1));
      expect(secondCard.top, greaterThanOrEqualTo(secondText.bottom - 1));

      // 两次调用都渲染成卡片，且都在回答区内。
      expect(find.byType(ToolCallCard), findsNWidgets(2));
      expect(find.byType(ToolCard), findsNWidgets(2));
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('tool-status-tool-1')))
            .data,
        '已完成',
      );
      final answerRect = tester.getRect(find.byType(MessageBubble).last);
      for (final index in [0, 1]) {
        final rect = tester.getRect(find.byType(ToolCard).at(index));
        expect(answerRect.contains(rect.center), isTrue);
        expect(rect.top, greaterThanOrEqualTo(answerRect.top));
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('每轮的思考各自成区，落在它那一轮的卡片之后', (tester) async {
      final messages = visibleMessages(
        threadOf([
          user('u1', '看下文件'),
          message(
            id: 'm1',
            runId: 'run-1',
            thinking: '先想第一步',
            text: '先读取文件',
            extra: toolCall('tool-1'),
          ),
          toolResult('t1', 'tool-1', '三行内容'),
          message(id: 'm2', runId: 'run-1', thinking: '再想第二步', text: '文件里有三行'),
        ]),
        const ChatState(),
      );
      await pumpTranscript(
        tester,
        messages,
        records: {'tool-1': record('tool-1')},
      );

      // 两个思考区，不是一个：第二轮的思考不叠到第一轮上面去。
      expect(find.byType(ThinkingPanel), findsNWidgets(2));
      expect(find.text('先想第一步'), findsNothing);
      await tester.tap(find.textContaining('已思考').first);
      await tester.pumpAndSettle();
      expect(find.text('先想第一步'), findsOneWidget);
      expect(find.text('再想第二步'), findsNothing);
      await tester.tap(find.textContaining('已思考').last);
      await tester.pumpAndSettle();
      expect(find.text('再想第二步'), findsOneWidget);
      expect(find.byType(ToolCard), findsOneWidget);
      // 顺序：第一轮思考 → 正文 → 卡片 → 第二轮思考 → 正文。
      final firstThinking = tester.getRect(find.byType(ThinkingPanel).first);
      final card = tester.getRect(find.byType(ToolCard));
      final secondThinking = tester.getRect(find.byType(ThinkingPanel).last);
      expect(firstThinking.bottom, lessThanOrEqualTo(card.top + 1));
      expect(card.bottom, lessThanOrEqualTo(secondThinking.top + 1));
      expect(
        tester.getRect(find.byType(GptMarkdown).last).top,
        greaterThanOrEqualTo(secondThinking.bottom - 1),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('两次运行分别渲染，各自一个回答区', (tester) async {
      final messages = visibleMessages(
        threadOf([
          user('u1', '第一个问题'),
          message(id: 'a1', runId: 'run-1', text: '第一个回答'),
          user('u2', '第二个问题'),
          message(id: 'a2', runId: 'run-2', text: '第二个回答'),
        ]),
        const ChatState(),
      );
      await pumpTranscript(tester, messages);

      expect(find.byType(MessageBubble), findsNWidgets(4));
      expect(find.byType(GptMarkdown), findsNWidgets(2));
      expect(find.text('第一个回答', findRichText: true), findsOneWidget);
      expect(find.text('第二个回答', findRichText: true), findsOneWidget);
      expect(find.byTooltip('消息操作'), findsNWidgets(2));
    });

    testWidgets('重新生成的新回答与旧回答分别是独立气泡', (tester) async {
      final messages = visibleMessages(
        threadOf([
          user('u1', '同一个问题'),
          message(id: 'old', runId: 'run-1', text: '旧回答'),
          message(id: 'new', runId: 'run-2', text: '新回答'),
        ]),
        const ChatState(),
      );
      await pumpTranscript(tester, messages);

      expect(find.byType(MessageBubble), findsNWidgets(3));
      expect(find.text('旧回答', findRichText: true), findsOneWidget);
      expect(find.text('新回答', findRichText: true), findsOneWidget);
    });

    testWidgets('流式中的增量并入同一回答区，光标只有一个', (tester) async {
      // 第二轮是因为第一轮调用了工具才出现的，分支照实建。
      final messages = visibleMessages(
        threadOf([
          user('u1', '看下文件'),
          message(
            id: 'm1',
            runId: 'run-1',
            text: '先读取文件',
            extra: toolCall('tool-1'),
          ),
          toolResult('t1', 'tool-1', '三行内容'),
          message(id: 'm2', runId: 'run-1'),
        ]),
        const ChatState(
          isGenerating: true,
          streamingParts: [TextPart(text: '正在总结')],
          streamingMessageId: 'm2',
        ),
      );
      await pumpTranscript(
        tester,
        messages,
        records: {'tool-1': record('tool-1')},
      );

      expect(find.byType(MessageBubble), findsNWidgets(2));
      final answer = tester
          .widgetList<MessageBubble>(find.byType(MessageBubble))
          .last
          .message;
      expect(answer.status, MessageStatus.streaming);
      expect(joinedText(answer), '先读取文件正在总结');
      // 卡片留在回答区里，光标跟在最后一段正文后面，整条回答只有一个。
      expect(find.byType(ToolCard), findsOneWidget);
      expect(
        tester.getRect(find.byType(ToolCard)).top,
        greaterThanOrEqualTo(
          tester.getRect(find.byType(GptMarkdown).first).bottom - 1,
        ),
      );
      expect(find.byKey(const ValueKey('generation-cursor')), findsOneWidget);
    });
  });

  group('真实工具循环', () {
    testWidgets('两轮工具循环在聊天页呈现为一个回答区，落库仍是一轮一条', (tester) async {
      tester.view.physicalSize = const Size(400, 860);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final harness = await ToolLoopHarness.create(
        registry: ToolRegistry([
          RecordingTool(name: 'echo', policy: ToolPolicy.allow),
        ]),
        models: const [
          ProfileModel(id: 'model-a', enabled: true, supportsTools: true),
        ],
      );
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (context, state) => const ChatPage()),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: harness.container,
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
          ),
        ),
      );
      await _settle(tester);

      harness.provider.turns.addAll([
        toolTurn(
          callId: 'call_1',
          toolName: 'echo',
          arguments: '{}',
          text: '先调用工具',
        ),
        textTurn('工具执行完了'),
      ]);
      await tester.enterText(
        find.byKey(const ValueKey('chat-message-input')),
        '跑一次工具',
      );
      await tester.pump();
      await tester.tap(find.byTooltip('发送'));
      await tester.pump();
      await _until(
        tester,
        () => !harness.state().isGenerating,
        reason: '运行未收口',
      );
      await _settle(tester);

      // 视图：用户输入 + 一个回答区，工具卡片在回答区里。
      final bubbles = tester
          .widgetList<MessageBubble>(find.byType(MessageBubble))
          .toList();
      expect(bubbles, hasLength(2));
      expect(find.byType(ToolCard), findsOneWidget);
      expect(find.byTooltip('消息操作'), findsOneWidget);
      final answer = bubbles.last.message;
      expect(joinedText(answer), '先调用工具工具执行完了');
      expect(answer.parts.whereType<ToolCallPart>(), hasLength(1));
      // 两轮正文各自是一段 Markdown，卡片夹在中间——不是全部堆在回答区末尾。
      final markdowns = tester
          .widgetList<GptMarkdown>(find.byType(GptMarkdown))
          .toList();
      expect(markdowns, hasLength(2));
      expect(markdowns.first.data, '先调用工具');
      expect(markdowns.last.data, '工具执行完了');
      final answerRect = tester.getRect(find.byType(MessageBubble).last);
      final card = tester.getRect(find.byType(ToolCard));
      expect(answerRect.contains(card.center), isTrue);
      final firstText = tester.getRect(find.byType(GptMarkdown).first);
      final lastText = tester.getRect(find.byType(GptMarkdown).last);
      expect(card.top, greaterThanOrEqualTo(firstText.bottom - 1));
      expect(card.bottom, lessThanOrEqualTo(lastText.top + 1));

      // 数据层不变：一次运行仍是一轮一条消息，工具结果消息留在分支里回填。
      final branch = await harness.branch();
      expect(branch.map((item) => item.role), [
        ChatRole.user,
        ChatRole.assistant,
        ChatRole.tool,
        ChatRole.assistant,
      ]);
      expect(branch.first.runId, isNull);
      expect(branch.skip(1).map((item) => item.runId).toSet(), hasLength(1));
      expect(tester.takeException(), isNull);
    });
  });
}

/// 卡片只通过仓储读记录：视图测试不建库。
class _FakeToolCalls implements ToolCallRepository {
  _FakeToolCalls(this.records);

  final Map<String, ToolCallRecord> records;

  @override
  Stream<ToolCallRecord> watchById(String id) {
    final record = records[id];
    return record == null
        ? const Stream<ToolCallRecord>.empty()
        : Stream<ToolCallRecord>.value(record);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('视图测试只用 watchById');
}

/// 有界推进 UI 与真实异步（库、文件、流）。
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 60));
  }
}

Future<void> _until(
  WidgetTester tester,
  FutureOr<bool> Function() condition, {
  required String reason,
}) async {
  for (var i = 0; i < 120; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 30));
    if (await tester.runAsync(() async => await condition()) ?? false) return;
  }
  fail('等待超时：$reason');
}
