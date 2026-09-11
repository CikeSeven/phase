import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:phase/app.dart';
import 'package:phase/data/datasources/local/app_database.dart';
import 'package:phase/data/datasources/local/secure_key_storage.dart';
import 'package:phase/data/datasources/local/settings_storage.dart';
import 'package:phase/data/models/ai_model.dart';
import 'package:phase/data/models/chat_chunk.dart';
import 'package:phase/data/models/chat_message.dart';
import 'package:phase/data/models/chat_request.dart';
import 'package:phase/data/models/profile_model.dart';
import 'package:phase/data/repositories/provider_profile_repository.dart';
import 'package:phase/features/chat/chat_controller.dart';
import 'package:phase/features/chat/model_selection.dart';
import 'package:phase/providers/ai_provider.dart';
import 'package:phase/providers/provider_factory.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FlowProvider implements AiProvider {
  StreamController<ChatChunk>? response;
  final requests = <ChatRequest>[];
  var cancellations = 0;

  @override
  String get id => 'ui-flow';

  @override
  ProviderCapabilities get capabilities => const ProviderCapabilities();

  @override
  Stream<ChatChunk> streamChat(ChatRequest request) {
    requests.add(request);
    response = StreamController<ChatChunk>(onCancel: () => cancellations++);
    return response!.stream;
  }

  @override
  Future<List<AiModel>> listModels() async => const [];

  @override
  Future<void> validateKey() async {}
}

class _FlowKeys extends SecureKeyStorage {
  @override
  Future<String?> readApiKey(String providerProfileId) async => 'test-only';
}

void main() {
  testWidgets('从界面输入到流式思考、正文落库，再停止下一条生成', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final db = AppDatabase(NativeDatabase.memory());
    final keys = _FlowKeys();
    final provider = _FlowProvider();
    await tester.runAsync(() async {
      await ProviderProfileRepository(db, keys).saveProfile(
        id: provider.id,
        name: '界面联调',
        baseUrl: 'https://example.invalid/v1',
        defaultModel: 'reasoning-test',
        models: const [
          ProfileModel(id: 'reasoning-test', supportsReasoning: true),
        ],
      );
    });
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWith((ref) => preferences),
        appDatabaseProvider.overrideWith((ref) => db),
        secureKeyStorageProvider.overrideWith((ref) => keys),
        aiProviderFactoryProvider.overrideWith(
          (ref) =>
              (_, _) => provider,
        ),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const PhaseApp()),
    );
    await _until(
      tester,
      () => container.read(modelSelectionProvider).value != null,
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '帮我安排今天的任务');
    await tester.pump();
    await tester.tap(find.byTooltip('发送'));
    await _until(tester, () => provider.requests.length == 1);
    expect(provider.requests.single.model, 'reasoning-test');
    expect(provider.requests.single.messages.last.content, '帮我安排今天的任务');
    expect(find.byTooltip('停止生成'), findsOneWidget);

    provider.response!.add(
      const ChatChunk(delta: '', reasoningDelta: '先区分重要事项与次要事项。'),
    );
    await _until(
      tester,
      () => find.textContaining('思考中…').evaluate().isNotEmpty,
    );
    expect(tester.takeException(), isNull);

    provider.response!.add(const ChatChunk(delta: '## 今日任务\n\n先完成最重要的一件事。'));
    await tester.pump(const Duration(milliseconds: 150));
    provider.response!.add(const ChatChunk(delta: '', done: true));
    unawaited(provider.response!.close());
    await _until(
      tester,
      () => !container.read(chatControllerProvider).isGenerating,
    );
    await tester.pumpAndSettle();
    expect(find.byType(GptMarkdown), findsWidgets);
    expect(find.textContaining('已思考'), findsOneWidget);
    expect(find.byTooltip('发送'), findsOneWidget);
    final conversationId = container
        .read(chatControllerProvider)
        .conversationId!;
    var messages = await tester.runAsync(
      () => db.getMessageRows(conversationId),
    );
    expect(messages, hasLength(2));
    expect(messages!.last.reasoning, '先区分重要事项与次要事项。');
    expect(messages.last.content, contains('今日任务'));
    expect(messages.last.status, ChatMessageStatus.done);

    await tester.enterText(find.byType(TextField).first, '再细化第一步');
    await tester.pump();
    await tester.tap(find.byTooltip('发送'));
    await _until(tester, () => provider.requests.length == 2);
    provider.response!.add(const ChatChunk(delta: '先整理材料，'));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.tap(find.byTooltip('停止生成'));
    await _until(
      tester,
      () => !container.read(chatControllerProvider).isGenerating,
    );
    await tester.pumpAndSettle();
    expect(provider.cancellations, greaterThanOrEqualTo(1));
    messages = await tester.runAsync(() => db.getMessageRows(conversationId));
    expect(messages, hasLength(4));
    expect(messages!.last.content, '先整理材料，');
    expect(messages.last.status, ChatMessageStatus.done);
    expect(tester.takeException(), isNull);

    unawaited(provider.response!.close());
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    var databaseClosed = false;
    unawaited(db.close().then((_) => databaseClosed = true));
    await _until(tester, () => databaseClosed);
  });
}

Future<void> _until(WidgetTester tester, bool Function() condition) async {
  for (var i = 0; i < 80; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 30));
    if (condition()) return;
  }
  fail('界面与流式状态未在预期时间内完成');
}
