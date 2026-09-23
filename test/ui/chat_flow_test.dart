import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:phase/data/repositories/workspace_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:material_loading_indicator/loading_indicator.dart';
import 'package:path/path.dart' as p;
import 'package:phase/app.dart';
import 'package:phase/data/datasources/local/app_database.dart';
import 'package:phase/data/datasources/local/model_catalog_cache.dart';
import 'package:phase/data/models/model_catalog.dart';
import 'package:phase/data/datasources/local/attachment_storage.dart';
import 'package:phase/data/datasources/local/secure_key_storage.dart';
import 'package:phase/data/datasources/local/settings_storage.dart';
import 'package:phase/data/models/api_protocol.dart';
import 'package:phase/data/models/chat_chunk.dart';
import 'package:phase/data/models/chat_message.dart';
import 'package:phase/data/models/chat_request.dart';
import 'package:phase/data/models/message_part.dart';
import 'package:phase/data/models/profile_model.dart';
import 'package:phase/data/repositories/provider_profile_repository.dart';
import 'package:phase/features/chat/chat_controller.dart';
import 'package:phase/features/chat/chat_send_button.dart';
import 'package:phase/features/chat/message_bubble.dart';
import 'package:phase/features/chat/model_selection.dart';
import 'package:phase/providers/ai_provider.dart';
import 'package:phase/providers/provider_factory.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_secure_storage.dart';

/// 界面联调用的可控协议实现：事件由测试逐条推送。
class _FlowProvider implements AiProvider {
  StreamController<ChatChunk>? response;
  final requests = <ChatRequest>[];
  var cancellations = 0;

  @override
  ApiProtocol get protocol => ApiProtocol.openaiCompletions;

  @override
  Future<List<ProfileModel>> listModels() async => const [];

  @override
  Stream<ChatChunk> streamChat(ChatRequest request) {
    requests.add(request);
    response = StreamController<ChatChunk>(onCancel: () => cancellations++);
    return response!.stream;
  }
}

void main() {
  testWidgets('从界面输入到流式思考、正文落库，再停止下一条生成', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final tempDir = Directory.systemTemp.createTempSync('phase_chat_flow');
    addTearDown(() => tempDir.deleteSync(recursive: true));
    // widget 测试的 fake-async 无法驱动后台 isolate：同 isolate 打开。
    final db = openAppDatabase(
      path: p.join(tempDir.path, 'phase.sqlite'),
      hexKey: '0123456789abcdef' * 4,
      background: false,
    );
    final keys = SecureKeyStorage(
      FakeSecureStorage({'api_key_p1': 'test-only'}),
    );
    final provider = _FlowProvider();
    await tester.runAsync(() async {
      await ProviderProfileRepository(db, keys).createProfile(
        name: '界面联调',
        baseUrl: 'https://example.invalid/v1',
        protocol: ApiProtocol.openaiCompletions,
        defaultModel: 'reasoning-test',
        models: const [
          ProfileModel(
            id: 'reasoning-test',
            enabled: true,
            supportsReasoning: true,
          ),
        ],
      );
    });
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        modelCatalogProvider.overrideWith((ref) async => ModelCatalog.empty),
        sharedPreferencesProvider.overrideWith((ref) => preferences),
        appDatabaseProvider.overrideWith((ref) => db),
        secureKeyStorageProvider.overrideWith((ref) => keys),
        workspaceRepositoryProvider.overrideWith(
          (ref) => WorkspaceRepository(db, tempDir),
        ),
        attachmentStorageProvider.overrideWith(
          (ref) =>
              AttachmentStorage(Directory(p.join(tempDir.path, 'attachments'))),
        ),
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
    await _settleUi(tester);

    expect(container.read(activeConversationProvider).conversationId, isNull);
    expect(find.byTooltip('会话工作区'), findsNothing);
    await tester.runAsync(() async {
      expect(
        await (await container.read(workspaceRepositoryProvider.future)).list(),
        isEmpty,
      );
    });
    await tester.enterText(find.byType(TextField).first, '帮我安排今天的任务');
    await tester.pump();
    final sendRect = tester.getRect(find.byType(ChatSendButton));
    expect(sendRect.size, const Size.square(56));
    await tester.tap(find.byTooltip('发送'));
    await _until(tester, () => provider.requests.length == 1);
    expect(provider.requests.single.modelId, 'reasoning-test');
    expect(find.byTooltip('会话工作区'), findsOneWidget);
    expect(
      provider.requests.single.messages.last.parts
          .whereType<ResolvedText>()
          .single
          .text,
      '帮我安排今天的任务',
    );
    expect(find.byTooltip('停止生成'), findsOneWidget);
    expect(tester.getRect(find.byType(ChatSendButton)), sendRect);
    expect(find.byType(LoadingIndicator), findsOneWidget);
    final stopButton = tester.widget<IconButton>(
      find.descendant(
        of: find.byType(ChatSendButton),
        matching: find.byType(IconButton),
      ),
    );
    expect(stopButton.isSelected, isNull);
    expect(stopButton.style!.shape!.resolve({}), isA<StadiumBorder>());

    provider.response!.add(
      const PartStart(partId: 'reasoning_0', kind: PartKind.reasoning),
    );
    provider.response!.add(
      const ReasoningDelta(partId: 'reasoning_0', text: '先区分重要事项与次要事项。'),
    );
    await _until(
      tester,
      () => find.textContaining('思考中…').evaluate().isNotEmpty,
    );
    expect(tester.takeException(), isNull);

    provider.response!.add(
      const PartStart(partId: 'text_0', kind: PartKind.text),
    );
    provider.response!.add(
      const TextDelta(partId: 'text_0', text: '## 今日任务\n\n先完成最重要的一件事。'),
    );
    await tester.pump(const Duration(milliseconds: 150));
    provider.response!.add(
      const PartEnd(
        partId: 'text_0',
        part: TextPart(text: '## 今日任务\n\n先完成最重要的一件事。'),
      ),
    );
    provider.response!.add(const ResponseEnd());
    unawaited(provider.response!.close());
    await _until(
      tester,
      () => !container.read(chatControllerProvider).isGenerating,
    );
    await _settleUi(tester);
    // 流式覆盖层清空后，当前页面仍展示已落库的完整正文和终态。
    final firstAnswer = tester
        .widgetList<MessageBubble>(find.byType(MessageBubble))
        .singleWhere((bubble) => bubble.message.role == ChatRole.assistant)
        .message;
    expect(firstAnswer.text, '## 今日任务\n\n先完成最重要的一件事。');
    expect(firstAnswer.status, MessageStatus.completed);
    expect(
      tester
          .widgetList<GptMarkdown>(find.byType(GptMarkdown))
          .map((w) => w.data),
      contains('## 今日任务\n\n先完成最重要的一件事。'),
    );
    expect(find.byTooltip('发送'), findsOneWidget);
    final conversationId = container
        .read(activeConversationProvider)
        .conversationId!;

    await tester.enterText(find.byType(TextField).first, '再细化第一步');
    await tester.pump();
    await tester.tap(find.byTooltip('发送'));
    await _until(tester, () => provider.requests.length == 2);
    expect(provider.requests.last.messages.map((message) => message.role), [
      ChatRole.user,
      ChatRole.assistant,
      ChatRole.user,
    ]);
    expect(
      provider.requests.last.messages[1].parts
          .whereType<ResolvedText>()
          .single
          .text,
      firstAnswer.text,
    );
    provider.response!.add(
      const PartStart(partId: 'text_0', kind: PartKind.text),
    );
    provider.response!.add(const TextDelta(partId: 'text_0', text: '先整理材料，'));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.tap(find.byTooltip('停止生成'));
    await _until(
      tester,
      () => !container.read(chatControllerProvider).isGenerating,
    );
    await _settleUi(tester);
    expect(provider.cancellations, greaterThanOrEqualTo(1));
    final stoppedAnswer = tester
        .widgetList<MessageBubble>(find.byType(MessageBubble))
        .where((bubble) => bubble.message.role == ChatRole.assistant)
        .last
        .message;
    expect(stoppedAnswer.text, '先整理材料，');
    expect(stoppedAnswer.status, MessageStatus.cancelled);
    // 停止时保留已收内容，标记为已取消。
    final stopped = await tester.runAsync(
      () => (db.select(
        db.messages,
      )..where((t) => t.conversationId.equals(conversationId))).get(),
    );
    expect(stopped, hasLength(4));
    expect(stopped!.last.status, MessageStatus.cancelled);
    expect(
      decodeMessageParts(jsonDecode(stopped.last.partsJson))
          .whereType<TextPart>()
          .single
          .text,
      '先整理材料，',
    );
    expect(tester.takeException(), isNull);

    unawaited(provider.response!.close());
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    var databaseClosed = false;
    unawaited(db.close().then((_) => databaseClosed = true));
    await _until(tester, () => databaseClosed);
  });
}

/// 有界推进 UI：动画链（思考面板收起等）不保证收敛，不用 pumpAndSettle。
Future<void> _settleUi(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 60));
  }
}

Future<void> _until(
  WidgetTester tester,
  bool Function() condition, {
  bool failOnTimeout = true,
}) async {
  for (var i = 0; i < 80; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 30));
    if (condition()) return;
  }
  if (failOnTimeout) fail('界面与流式状态未在预期时间内完成');
}
