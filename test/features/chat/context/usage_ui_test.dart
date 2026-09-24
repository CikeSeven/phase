import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/theme/app_theme.dart';
import 'package:phase/data/models/model_request_record.dart';
import 'package:phase/data/models/chat_message.dart';
import 'package:phase/data/models/message_part.dart';
import 'package:phase/features/chat/message_bubble.dart';
import 'package:phase/core/widgets/app_sheet.dart';
import 'package:phase/data/models/token_usage.dart';
import 'package:phase/data/repositories/model_request_repository.dart';
import 'package:phase/features/chat/usage/usage_panel.dart';

ModelRequestRecord record(
  String id, {
  TokenUsage? usage,
  bool inherited = false,
}) => ModelRequestRecord(
  id: id,
  conversationId: 'c',
  runId: inherited ? 'old-run' : 'run',
  profileId: 'p',
  protocol: 'openaiCompletions',
  requestedModelId: '原始模型标识-long-model-name',
  createdAt: DateTime(2026),
  startedAt: DateTime(2026),
  status: ModelRequestStatus.completed,
  usageComplete: true,
  usage: usage,
  isInherited: inherited,
);

void main() {
  test('缓存率不把未满命中四舍五入为 100%', () {
    expect(cacheRateLabel(.99999), '99.9%');
    expect(cacheRateLabel(1), '100.0%');
    expect(cacheRateLabel(null), '不适用');
  });

  testWidgets('消息用量直接打开底部面板，所属运行与返回保持有效', (tester) async {
    final container = ProviderContainer(
      overrides: [
        conversationRequestsProvider('c').overrideWith(
          (ref) => Stream.value([
            record(
              'one',
              usage: const TokenUsage(promptTokens: 100, cacheReadTokens: 80),
            ),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ListView(
              children: [
                MessageBubble(
                  message: ChatMessage(
                    id: 'reply',
                    conversationId: 'c',
                    runId: 'run',
                    role: ChatRole.assistant,
                    parts: const [TextPart(text: '回答正文')],
                    createdAt: DateTime(2026),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('消息操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('用量'));
    await tester.pumpAndSettle();
    expect(find.byType(AppSheet), findsOneWidget);
    expect(find.byType(UsagePanel), findsOneWidget);
    expect(tester.widget<UsagePanel>(find.byType(UsagePanel)).runId, 'run');
    expect(find.text('所属运行'), findsOneWidget);
    expect(find.textContaining('已报告用量 · 1 次实际请求'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(AppSheet), findsNothing);
    expect(find.text('回答正文', findRichText: true), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final size in [
    const Size(320, 640),
    const Size(360, 640),
    const Size(740, 360),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('用量 ${size.width}×${size.height} ${scale}x 可滚动、未知真实且无溢出', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.reset);
        final container = ProviderContainer(
          overrides: [
            conversationRequestsProvider('c').overrideWith(
              (ref) => Stream.value([
                record(
                  'one',
                  usage: const TokenUsage(
                    promptTokens: 100,
                    cacheReadTokens: 80,
                    outputTokens: 10,
                    totalTokens: 110,
                  ),
                ),
                record('two'),
                record(
                  'inherited',
                  usage: const TokenUsage(promptTokens: 9999),
                  inherited: true,
                ),
              ]),
            ),
          ],
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.light(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Scaffold(
                body: ListView(
                  children: const [UsagePanel(conversationId: 'c')],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('整个会话'),
          160,
          scrollable: find.byType(Scrollable).first,
        );
        await Scrollable.ensureVisible(
          tester.element(find.text('整个会话')),
          alignment: .4,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('整个会话').hitTestable());
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<ChoiceChip>(
                find.ancestor(
                  of: find.text('整个会话'),
                  matching: find.byType(ChoiceChip),
                ),
              )
              .selected,
          isTrue,
        );
        expect(find.textContaining('已报告用量 · 2 次实际请求'), findsOneWidget);
        expect(find.text('输入总量：100 · 1 次请求未提供'), findsOneWidget);
        expect(find.text('已报告请求命中率：80.0% · 覆盖 1/2 次'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.textContaining('不计本会话消耗'),
          180,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.textContaining('不计本会话消耗'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
