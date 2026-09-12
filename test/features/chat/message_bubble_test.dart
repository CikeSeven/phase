import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:phase/core/theme/app_theme.dart';
import 'package:phase/data/models/chat_message.dart';
import 'package:phase/data/models/message_part.dart';
import 'package:phase/features/chat/message_actions_sheet.dart';
import 'package:phase/features/chat/message_bubble.dart';
import 'package:phase/features/chat/thinking_panel.dart';

ChatMessage _aiMessage(String content, MessageStatus status) {
  return ChatMessage(
    id: 'm1',
    conversationId: 'c1',
    role: ChatRole.assistant,
    parts: [if (content.isNotEmpty) TextPart(text: content)],
    status: status,
    createdAt: DateTime(2026),
    modelLabel: 'test-model',
  );
}

/// Part 结构下的局部更新：正文替换/追加、思考设置或移除、状态切换。
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
}

void main() {
  Future<void> pumpBubble(WidgetTester tester, ChatMessage message) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(children: [MessageBubble(message: message)]),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('流式占位（空内容）不报错', (tester) async {
    await pumpBubble(tester, _aiMessage('', MessageStatus.streaming));
    expect(tester.takeException(), isNull);
  });

  testWidgets('流式半截 Markdown（未闭合代码块）不报错', (tester) async {
    await pumpBubble(
      tester,
      _aiMessage('好的，代码如下：\n```dart\nvoid main() {', MessageStatus.streaming),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('流式半截表格不报错', (tester) async {
    await pumpBubble(
      tester,
      _aiMessage('| 列A | 列B |\n| --- |', MessageStatus.streaming),
    );
    expect(tester.takeException(), isNull);
  });

  group('思考区块', () {
    ChatMessage reasoningMessage({
      String? reasoning = '推演过程',
      MessageStatus status = MessageStatus.completed,
    }) {
      return ChatMessage(
        id: 'm-reasoning',
        conversationId: 'c1',
        role: ChatRole.assistant,
        parts: [
          if (reasoning != null) ReasoningPart(publicText: reasoning),
          const TextPart(text: '答案'),
        ],
        status: status,
        modelLabel: 'model-a',
        createdAt: DateTime(2026),
      );
    }

    Widget buildBubble(ChatMessage message) {
      return MaterialApp(
        theme: AppTheme.light(),
        // 与 DESIGN 一致：降级模式下光标/计时静止，测试不悬挂周期计时器。
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Scaffold(body: MessageBubble(message: message)),
      );
    }

    testWidgets('完成的历史消息有 reasoning 时默认展示全文，可手动收起和展开', (tester) async {
      await tester.pumpWidget(buildBubble(reasoningMessage()));

      expect(find.byIcon(Symbols.psychology), findsOneWidget);
      expect(find.text('已思考'), findsOneWidget);
      expect(find.text('推演过程'), findsOneWidget);
      expect(find.text('答案', findRichText: true), findsOneWidget);

      await tester.tap(find.text('已思考'));
      await tester.pumpAndSettle();
      expect(find.text('推演过程'), findsNothing);
      expect(find.text('答案', findRichText: true), findsOneWidget);
      await tester.tap(find.text('已思考'));
      await tester.pumpAndSettle();
      expect(find.text('推演过程'), findsOneWidget);
    });

    testWidgets('reasoning 流式中显示「思考中…」且默认展开', (tester) async {
      await tester.pumpWidget(
        buildBubble(reasoningMessage(status: MessageStatus.streaming)),
      );
      // 有持续的光标动画，不能 pumpAndSettle。
      await tester.pump();

      expect(find.textContaining('思考中…'), findsOneWidget);
      expect(find.text('推演过程'), findsOneWidget);
    });

    testWidgets('无 reasoning 不因推理模型名或生成状态渲染思考区块', (tester) async {
      for (final status in MessageStatus.values) {
        await tester.pumpWidget(
          buildBubble(
            reasoningMessage(
              reasoning: null,
              status: status,
            ).copyWith(modelLabel: 'reasoning-thinking-model'),
          ),
        );
        expect(find.byIcon(Symbols.psychology), findsNothing);
        expect(find.byType(ThinkingPanel), findsNothing);
        expect(find.text('已思考'), findsNothing);
        expect(find.textContaining('思考中…'), findsNothing);
      }
    });

    testWidgets('空串 reasoning 在流式与完成时都不渲染思考区块', (tester) async {
      for (final status in MessageStatus.values) {
        await tester.pumpWidget(
          buildBubble(reasoningMessage(reasoning: '', status: status)),
        );
        expect(find.byIcon(Symbols.psychology), findsNothing);
        expect(find.byType(ThinkingPanel), findsNothing);
        expect(find.text('答案', findRichText: true), findsOneWidget);
      }
    });

    testWidgets('同一消息 streaming 到 done 保持父结构与思考全文', (tester) async {
      final streaming = reasoningMessage(status: MessageStatus.streaming);
      await tester.pumpWidget(buildBubble(streaming));
      final panelState = tester.state(find.byType(ThinkingPanel));
      expect(find.text('答案', findRichText: true), findsOneWidget);
      expect(find.textContaining('思考中…'), findsOneWidget);
      expect(find.byIcon(Symbols.psychology), findsOneWidget);
      expect(find.text('推演过程'), findsOneWidget);

      await tester.pumpWidget(
        buildBubble(streaming.copyWith(status: MessageStatus.completed)),
      );
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(ThinkingPanel)), same(panelState));
      // 思考结束自动收起，正文不受影响；手动展开恢复全文。
      expect(find.text('推演过程'), findsNothing);
      expect(find.text('已思考'), findsOneWidget);
      expect(find.text('答案', findRichText: true), findsOneWidget);
      await tester.tap(find.text('已思考'));
      await tester.pumpAndSettle();
      expect(find.text('推演过程'), findsOneWidget);
      final header = find.descendant(
        of: find.byType(ThinkingPanel),
        matching: find.byType(InkWell),
      );
      expect(tester.getSize(header).height, greaterThanOrEqualTo(48));
    });

    testWidgets('思考限高内容在流式期间跟随最新底部，上翻暂停、回底恢复', (tester) async {
      String lines(int from, int to) =>
          [for (var i = from; i < to; i++) '推演第 $i 行'].join('\n');
      final message = ValueNotifier(
        _aiMessage(
          '',
          MessageStatus.streaming,
        ).withParts(thinking: lines(0, 120)),
      );
      addTearDown(message.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: Scaffold(
            body: ValueListenableBuilder<ChatMessage>(
              valueListenable: message,
              builder: (context, value, child) => MessageBubble(message: value),
            ),
          ),
        ),
      );
      await tester.pump();
      final inner = find.descendant(
        of: find.byType(ThinkingPanel),
        matching: find.byType(SingleChildScrollView),
      );
      ScrollPosition position() =>
          tester.widget<SingleChildScrollView>(inner).controller!.position;

      // 初始定位在最新内容底部。
      await tester.pumpAndSettle();
      expect(position().pixels, position().maxScrollExtent);

      // 流式增量跟随到底部。
      message.value = message.value.withParts(thinking: lines(0, 220));
      await tester.pumpAndSettle();
      expect(position().pixels, position().maxScrollExtent);
      expect(position().maxScrollExtent, greaterThan(0));

      // 用户下拉回看旧内容（offset 减小）暂停跟随，增量不再抢滚动。
      await tester.drag(inner, const Offset(0, 120));
      await tester.pumpAndSettle();
      final readingOffset = position().pixels;
      message.value = message.value.withParts(thinking: lines(0, 300));
      await tester.pumpAndSettle();
      expect(position().pixels, closeTo(readingOffset, 1));

      // 手动上滑回到底部后恢复跟随。
      await tester.drag(inner, const Offset(0, -4000));
      await tester.pumpAndSettle();
      message.value = message.value.withParts(thinking: lines(0, 360));
      await tester.pumpAndSettle();
      expect(position().pixels, position().maxScrollExtent);
      expect(tester.takeException(), isNull);
    });

    testWidgets('100ms 内完成且首次带 reasoning 的 done 快照直接显示全文', (tester) async {
      final message = ValueNotifier(_aiMessage('', MessageStatus.streaming));
      addTearDown(message.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<ChatMessage>(
              valueListenable: message,
              builder: (context, value, child) => MessageBubble(message: value),
            ),
          ),
        ),
      );
      expect(find.byIcon(Symbols.psychology), findsNothing);
      await tester.pump(const Duration(milliseconds: 80));
      message.value = message.value.withParts(
        text: '快速回复正文',
        thinking: '完整推演第一行\n完整推演第二行',
        status: MessageStatus.completed,
      );
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.text('完整推演第一行\n完整推演第二行'), findsOneWidget);
      expect(find.text('快速回复正文', findRichText: true), findsOneWidget);
      expect(find.text('已思考'), findsOneWidget);
      expect(find.byIcon(Symbols.psychology), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('手动收起后正文和思考增量及状态切换都不覆盖偏好', (tester) async {
      final streaming = reasoningMessage(status: MessageStatus.streaming);
      await tester.pumpWidget(buildBubble(streaming));
      await tester.tap(find.textContaining('思考中…'));
      await tester.pump();
      expect(find.text('推演过程'), findsNothing);
      final updated = streaming.withParts(thinking: '完整思考：先分析，再校验。');
      await tester.pumpWidget(buildBubble(updated));
      expect(
        find.text(updated.parts.whereType<ReasoningPart>().single.publicText),
        findsNothing,
      );
      await tester.pumpWidget(
        buildBubble(updated.copyWith(status: MessageStatus.completed)),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(updated.parts.whereType<ReasoningPart>().single.publicText),
        findsNothing,
      );
      await tester.tap(find.text('已思考'));
      await tester.pumpAndSettle();
      expect(
        find.text(updated.parts.whereType<ReasoningPart>().single.publicText),
        findsOneWidget,
      );
    });

    testWidgets('手动重新展开后完成时不自动折叠，错误正文仍显示', (tester) async {
      final streaming = reasoningMessage(status: MessageStatus.streaming);
      await tester.pumpWidget(buildBubble(streaming));
      await tester.tap(find.textContaining('思考中…'));
      await tester.pump();
      await tester.tap(find.textContaining('思考中…'));
      await tester.pump();
      await tester.pumpWidget(
        buildBubble(streaming.copyWith(status: MessageStatus.completed)),
      );
      await tester.pumpAndSettle();
      expect(find.text('推演过程'), findsOneWidget);

      await tester.pumpWidget(
        buildBubble(
          streaming.withParts(
            status: MessageStatus.failed,
            text: '网络连接失败，请检查网络后重试',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('推演过程'), findsOneWidget);
      expect(find.text('回复未完成'), findsOneWidget);
      expect(find.text('网络连接失败，请检查网络后重试', findRichText: true), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('减少动态效果时生成光标可见且静止，依赖变化与销毁安全', (tester) async {
    Widget cursorApp({required bool reduced, required bool streaming}) {
      return MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
          child: child!,
        ),
        home: Scaffold(
          body: MessageBubble(
            message: _aiMessage(
              '答案',
              streaming ? MessageStatus.streaming : MessageStatus.completed,
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(cursorApp(reduced: true, streaming: true));
    await tester.pumpAndSettle();
    final cursorFade = find.descendant(
      of: find.byKey(const ValueKey('generation-cursor')),
      matching: find.byType(FadeTransition),
    );
    expect(tester.widget<FadeTransition>(cursorFade).opacity.value, 1);
    expect(tester.hasRunningAnimations, isFalse);
    expect(find.text('▍'), findsOneWidget);

    await tester.pumpWidget(cursorApp(reduced: false, streaming: true));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpWidget(cursorApp(reduced: true, streaming: true));
    await tester.pumpAndSettle();
    expect(tester.widget<FadeTransition>(cursorFade).opacity.value, 1);
    expect(tester.hasRunningAnimations, isFalse);
    await tester.pumpWidget(cursorApp(reduced: true, streaming: false));
    await tester.pumpAndSettle();
    expect(find.text('▍'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 360.0]) {
    for (final scale in [1.3, 2.0]) {
      testWidgets('长消息/模型名 $width dp ${scale}x 无溢出且正文不被压窄', (tester) async {
        tester.view.physicalSize = Size(width, 760);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const modelName = '非常长的服务商模型名称-deep-reasoning-model-2026-preview';
        const content =
            '# 阅读优先\n\n一段足够长的正文，应自然换行而不挤在思考旁边。\n\n'
            '- 第一项内容\n- 第二项内容\n\n'
            '[模型文档](https://example.com/models/a-very-long-model-name)\n\n'
            '```dart\nfinal text = "这是一个较长的代码示例";\n```';
        for (final theme in [AppTheme.light(), AppTheme.dark()]) {
          await tester.pumpWidget(
            MaterialApp(
              theme: theme,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scale),
                  disableAnimations: true,
                ),
                child: child!,
              ),
              home: Scaffold(
                body: ListView(
                  children: [
                    MessageBubble(
                      message: ChatMessage(
                        id: 'user',
                        conversationId: 'c1',
                        role: ChatRole.user,
                        parts: const [
                          TextPart(text: '用户的一段较长输入，也应有合理宽度并在右侧对齐。'),
                        ],
                        createdAt: DateTime(2026),
                      ),
                    ),
                    MessageBubble(
                      message: ChatMessage(
                        id: 'assistant',
                        conversationId: 'c1',
                        role: ChatRole.assistant,
                        parts: [
                          const ReasoningPart(publicText: '推演过程也会自然换行，不截掉原文。'),
                          TextPart(text: content),
                        ],
                        modelLabel: modelName,
                        status: MessageStatus.streaming,
                        createdAt: DateTime(2026),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(tester.getSize(find.byType(GptMarkdown)).width, width - 32);
          final label = tester.widget<Text>(find.text(modelName));
          expect(label.maxLines, 1);
          expect(label.overflow, TextOverflow.ellipsis);
          expect(find.byIcon(Symbols.psychology), findsOneWidget);
        }
      });
    }
  }

  testWidgets('长按消息从底部展开紧凑操作面板并复制正文', (tester) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await pumpBubble(tester, _aiMessage('需要复制的正文', MessageStatus.completed));

    await tester.longPress(find.text('需要复制的正文', findRichText: true));
    await tester.pumpAndSettle();
    expect(find.byType(MessageActionsSheet), findsOneWidget);
    expect(find.byType(MenuAnchor), findsNothing);
    expect(find.byType(MenuItemButton), findsNothing);
    final sheetRect = tester.getRect(find.byType(BottomSheet));
    expect(sheetRect.left, 0);
    expect(sheetRect.right, 800);
    expect(sheetRect.bottom, 600);
    expect(sheetRect.height, lessThan(240));
    expect(find.byIcon(Symbols.content_copy), findsOneWidget);
    expect(find.byIcon(Symbols.keep), findsNothing);
    expect(find.text('重新生成'), findsNothing);
    expect(find.text('删除'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('copy-message')));
    await tester.pumpAndSettle();
    expect(copied, ['需要复制的正文']);
    expect(find.text('已复制'), findsOneWidget);
    expect(find.byType(MessageActionsSheet), findsNothing);
  });

  testWidgets('AI 消息更多按钮也打开底部操作面板', (tester) async {
    await pumpBubble(tester, _aiMessage('需要复制的正文', MessageStatus.completed));
    await tester.tap(find.byTooltip('消息操作'));
    await tester.pumpAndSettle();
    expect(find.byType(MessageActionsSheet), findsOneWidget);
    expect(find.byType(MenuItemButton), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(MessageActionsSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('代码块复制仍调用剪贴板并保留原始代码', (tester) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await pumpBubble(
      tester,
      _aiMessage('```dart\nfinal answer = 42;\n```', MessageStatus.completed),
    );
    await tester.tap(find.byTooltip('复制代码'));
    await tester.pumpAndSettle();
    expect(copied.single.trim(), 'final answer = 42;');
    expect(tester.takeException(), isNull);
  });
}
