import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/theme/app_theme.dart';
import 'package:phase/data/models/api_protocol.dart';
import 'package:phase/data/models/chat_message.dart';
import 'package:phase/data/models/chat_request.dart';
import 'package:phase/data/models/model_request_record.dart';
import 'package:phase/data/models/provider_profile.dart';
import 'package:phase/data/models/token_usage.dart';
import 'package:phase/data/repositories/model_request_repository.dart';
import 'package:phase/data/repositories/plan_repository.dart';
import 'package:phase/features/chat/chat_controller.dart';
import 'package:phase/features/chat/context/context_builder.dart';
import 'package:phase/features/chat/context/context_meter.dart';
import 'package:phase/features/chat/context/context_preview.dart';
import 'package:phase/features/chat/context/conversation_context_page.dart';
import 'package:phase/features/chat/usage/usage_panel.dart';
import 'package:phase/providers/request_plan.dart';

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

  for (final size in [
    const Size(320, 640),
    const Size(360, 640),
    const Size(740, 360),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        '上下文/用量 ${size.width}×${size.height} ${scale}x 可滚动、未知真实且无溢出',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = size;
          addTearDown(tester.view.reset);
          final plan = await planRequest(
            ProviderProfile(
              id: 'p',
              name: 'fixture',
              protocol: ApiProtocol.openaiCompletions,
              baseUrl: 'https://fixture.test',
              createdAt: DateTime(2026),
            ),
            const ChatRequest(
              modelId: 'm',
              messages: [
                ResolvedMessage(
                  role: ChatRole.user,
                  sourceMessageId: 'u',
                  parts: [ResolvedText('当前任务')],
                ),
              ],
            ),
          );
          final measurement = await const ContextMeter().measure(
            conversationId: 'c',
            plan: plan,
            generation: 'original',
            requests: [],
          );
          final container = ProviderContainer(
            overrides: [
              contextPreviewProvider('c').overrideWith(
                (ref) async => ContextBuild(
                  plan.request.messages,
                  measurement.estimatedInputTokens,
                  const ContextBudget(),
                  measurement: measurement,
                ),
              ),
              contextSummariesProvider('c')
                  .overrideWith((ref) => Stream.value([])),
              conversationPlansProvider('c')
                  .overrideWith((ref) => Stream.value([])),
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
          container.read(activeConversationProvider.notifier).open('c');
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
                home: const ConversationContextPage(conversationId: 'c'),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.textContaining('下一请求预计输入 ≈'), findsOneWidget);
          expect(find.textContaining('本地默认窗口'), findsOneWidget);
          await tester.scrollUntilVisible(
            find.textContaining('不含未发送草稿'),
            160,
            scrollable: find.byType(Scrollable).first,
          );
          expect(find.textContaining('不含未发送草稿'), findsOneWidget);
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
        },
      );
    }
  }
}
