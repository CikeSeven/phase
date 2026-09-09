import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase/app.dart';
import 'package:phase/core/router/app_router.dart';
import 'package:phase/core/widgets/app_dialog.dart';
import 'package:phase/data/datasources/local/app_database.dart';
import 'package:phase/data/datasources/local/secure_key_storage.dart';
import 'package:phase/data/datasources/local/settings_storage.dart';
import 'package:phase/data/models/api_protocol.dart';
import 'package:phase/data/models/chat_message.dart';
import 'package:phase/data/models/profile_model.dart';
import 'package:phase/data/repositories/conversation_repository.dart';
import 'package:phase/data/repositories/provider_profile_repository.dart';
import 'package:phase/features/chat/model_picker_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _capture = bool.fromEnvironment('CAPTURE_UI');
const _captureKey = ValueKey('ui-preview-capture');

class _PreviewKeyStorage extends SecureKeyStorage {
  @override
  Future<String?> readApiKey(String providerProfileId) async => null;
}

void main() {
  setUpAll(() async {
    if (!_capture) return;
    final bytes = await File('build/ui-preview/NotoSansCJKsc-Regular.otf')
        .readAsBytes();
    for (final family in ['Roboto', 'Ahem', 'sans-serif']) {
      final loader = FontLoader(family)
        ..addFont(Future.value(ByteData.sublistView(bytes)));
      await loader.load();
    }
    final manifest = jsonDecode(
      await rootBundle.loadString('FontManifest.json'),
    ) as List<dynamic>;
    for (final entry in manifest.cast<Map<String, dynamic>>()) {
      final family = entry['family'] as String;
      if (!family.toLowerCase().contains('material')) continue;
      final loader = FontLoader(family);
      for (final font
          in (entry['fonts'] as List<dynamic>).cast<Map<String, dynamic>>()) {
        loader.addFont(rootBundle.load(font['asset'] as String));
      }
      await loader.load();
    }
  });

  for (final mode in ['light', 'dark']) {
    testWidgets('$mode 关键页面真实渲染预览', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.padding = const FakeViewPadding(top: 28, bottom: 20);
      tester.view.viewPadding = const FakeViewPadding(top: 28, bottom: 20);
      addTearDown(tester.view.reset);

      final db = AppDatabase(NativeDatabase.memory());
      final keys = _PreviewKeyStorage();
      final profiles = ProviderProfileRepository(db, keys);
      final conversations = ConversationRepository(db);
      await tester.runAsync(() async {
        await profiles.saveProfile(
          id: 'preview-gateway',
          name: '开发网关',
          baseUrl: 'https://preview.invalid/v1',
          protocol: ApiProtocol.openaiResponses,
          defaultModel: 'gpt-5.6-sol',
          models: const [
            ProfileModel(id: 'gpt-5.6-sol', supportsReasoning: true),
            ProfileModel(id: 'fast-chat'),
            ProfileModel(id: 'long-context-reasoning', supportsReasoning: true),
          ],
        );
        await profiles.saveProfile(
          id: 'preview-local',
          name: '本地模型',
          baseUrl: 'http://localhost:11434/v1',
          presetId: 'ollama',
          defaultModel: 'local-chat',
          models: const [ProfileModel(id: 'local-chat')],
        );
        final conversation = await conversations.createConversation(
          title: '把今天的想法整理成计划',
        );
        await conversations.setPinned(conversation.id, pinned: true);
        await conversations.appendMessage(
          conversationId: conversation.id,
          role: ChatRole.user,
          content: '我有一些零散的想法，帮我整理成今天的行动计划。',
        );
        final reply = await conversations.appendMessage(
          conversationId: conversation.id,
          role: ChatRole.assistant,
          content: '',
          modelName: 'gpt-5.6-sol',
        );
        await conversations.updateMessageContent(
          reply.id!,
          content:
              '## 先做最重要的一件事\n\n'
              '把想法变成行动，可以分成三个小步骤：\n\n'
              '1. **明确目标**：写下今天最想完成的结果。\n'
              '2. **缩小任务**：拆成半小时就能推进的一步。\n'
              '3. **留出余量**：给休息和新的想法留一点空间。\n\n'
              '> 不必一次做完所有事，先让第一步发生。',
          reasoning:
              '先区分目标与任务，再按优先级安排。'
              '用户希望计划容易执行，因此应保留弹性，避免安排过满。',
          status: ChatMessageStatus.done,
        );
        await conversations.createConversation(title: '读一本书的笔记');
        await conversations.createConversation(title: '一个小工具的设计草稿');
      });

      SharedPreferences.setMockInitialValues({
        'theme_mode': mode,
        'last_profile_id': 'preview-gateway',
        'last_model': 'gpt-5.6-sol',
        'last_reasoning_effort': 'medium',
      });
      final preferences = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWith((ref) => preferences),
          appDatabaseProvider.overrideWith((ref) => db),
          secureKeyStorageProvider.overrideWith((ref) => keys),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const RepaintBoundary(key: _captureKey, child: PhaseApp()),
        ),
      );
      await _settleDatabase(tester);
      await _save(tester, '$mode-chat-empty');

      final scaffold = tester.state<ScaffoldState>(find.byType(Scaffold).first);
      scaffold.openDrawer();
      await tester.pumpAndSettle();
      await _save(tester, '$mode-drawer');
      await tester.tap(find.text('把今天的想法整理成计划'));
      await _settleDatabase(tester);
      await _save(tester, '$mode-chat-message');
      await tester.ensureVisible(find.text('已思考'));
      await tester.pumpAndSettle();
      await _save(tester, '$mode-reasoning');
      await tester.tap(find.text('已思考'));
      await tester.pumpAndSettle();
      await _save(tester, '$mode-reasoning-collapsed');

      final context = tester.element(find.byType(Scaffold).first);
      final sheetFuture = showModelPickerSheet(context);
      await tester.pumpAndSettle();
      await _save(tester, '$mode-model-picker');
      await tester.tap(find.byTooltip('关闭'));
      await tester.pumpAndSettle();
      await sheetFuture;

      final router = container.read(appRouterProvider);
      router.push('/settings');
      await tester.pumpAndSettle();
      await _save(tester, '$mode-settings');
      await tester.tap(find.text('主题模式'));
      await tester.pumpAndSettle();
      await _save(tester, '$mode-theme-dialog');
      final dialogContext = tester.element(find.byType(AppDialog));
      Navigator.of(dialogContext).pop();
      await tester.pumpAndSettle();

      router.push('/settings/providers');
      await _settleDatabase(tester);
      await _save(tester, '$mode-providers');
      router.push('/settings/providers/preview-gateway');
      await _settleDatabase(tester);
      await _save(tester, '$mode-provider-edit');

      router.go('/assistants');
      await tester.pumpAndSettle();
      await _save(tester, '$mode-assistants');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      var databaseClosed = false;
      final closing = db.close().then((_) => databaseClosed = true);
      for (var i = 0; !databaseClosed && i < 80; i++) {
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pump(const Duration(milliseconds: 30));
      }
      expect(databaseClosed, isTrue);
      await closing;
    }, skip: !_capture);
  }
}

Future<void> _settleDatabase(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 30));
  }
  await tester.pumpAndSettle();
}

Future<void> _save(WidgetTester tester, String name) async {
  expect(tester.takeException(), isNull, reason: name);
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_captureKey),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('build/ui-preview/$name.png').writeAsBytes(
      data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
    image.dispose();
  });
}
