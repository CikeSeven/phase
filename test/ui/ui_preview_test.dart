import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:phase/app.dart';
import 'package:phase/core/router/app_router.dart';
import 'package:phase/core/widgets/app_dialog.dart';
import 'package:phase/data/datasources/local/app_database.dart';
import 'package:phase/data/datasources/local/secure_key_storage.dart';
import 'package:phase/data/datasources/local/settings_storage.dart';
import 'package:phase/data/models/api_protocol.dart';
import 'package:phase/data/models/chat_message.dart';
import 'package:phase/data/models/message_part.dart';
import 'package:phase/data/models/profile_model.dart';
import 'package:phase/data/repositories/conversation_repository.dart';
import 'package:phase/data/repositories/provider_profile_repository.dart';
import 'package:phase/features/chat/chat_transcript.dart';
import 'package:phase/features/chat/model_picker_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_secure_storage.dart';

const _capture = bool.fromEnvironment('CAPTURE_UI');
const _captureKey = ValueKey('ui-preview-capture');

class _PreviewKeyStorage extends SecureKeyStorage {
  _PreviewKeyStorage() : super(FakeSecureStorage());
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

  for (final mode in ['light', 'dark', 'light-compact', 'dark-compact']) {
    testWidgets('$mode 关键页面真实渲染预览', (tester) async {
      final compact = mode.endsWith('compact');
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = compact
          ? const Size(320, 760)
          : const Size(390, 844);
      tester.platformDispatcher.textScaleFactorTestValue = compact ? 2 : 1;
      tester.view.padding = const FakeViewPadding(top: 28, bottom: 20);
      tester.view.viewPadding = const FakeViewPadding(top: 28, bottom: 20);
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      final tempDir = Directory.systemTemp.createTempSync('phase_ui_preview');
      addTearDown(() {
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      });
      final db = openAppDatabase(
        path: p.join(tempDir.path, 'phase.sqlite'),
        hexKey: '0123456789abcdef' * 4,
        background: false,
      );
      final keys = _PreviewKeyStorage();
      final profiles = ProviderProfileRepository(db, keys);
      final conversations = ConversationRepository(db);
      await tester.runAsync(() async {
        await profiles.createProfile(
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
        await profiles.createProfile(
          name: '本地模型',
          baseUrl: 'http://localhost:11434/v1',
          presetId: 'ollama',
          requiresKey: false,
          defaultModel: 'local-chat',
          models: const [ProfileModel(id: 'local-chat')],
        );
        final conversation = await conversations.createConversation(
          title: '把今天的想法整理成计划',
        );
        await conversations.setPinned(conversation.id, pinned: true);
        await conversations.appendMessage(
          ChatMessage(
            id: 'preview-m1',
            conversationId: conversation.id,
            role: ChatRole.user,
            parts: const [TextPart(text: '今天想完成三件事：整理读书笔记、推进小工具原型、写一份周末出行计划。')],
            createdAt: DateTime.now(),
          ),
        );
        await conversations.appendMessage(
          ChatMessage(
            id: 'preview-m2',
            conversationId: conversation.id,
            role: ChatRole.assistant,
            parts: const [
              TextPart(text: '可以先确定优先顺序，再为每件事留一个明确的时间段。先从最需要专注的小工具原型开始。'),
            ],
            modelLabel: 'gpt-5.6-sol',
            createdAt: DateTime.now(),
          ),
        );
        await conversations.appendMessage(
          ChatMessage(
            id: 'preview-m3',
            conversationId: conversation.id,
            parentId: 'preview-m2',
            role: ChatRole.user,
            parts: const [TextPart(text: '我有一些零散的想法，帮我整理成今天的行动计划。')],
            createdAt: DateTime.now(),
          ),
        );
        final reply = await conversations.appendMessage(
          ChatMessage(
            id: 'preview-m4',
            conversationId: conversation.id,
            parentId: 'preview-m3',
            role: ChatRole.assistant,
            parts: const [],
            modelLabel: 'gpt-5.6-sol',
            createdAt: DateTime.now(),
          ),
        );
        await conversations.updateMessage(
          messageId: reply.id,
          parts: const [
            ReasoningPart(
              publicText:
                  '先区分目标与任务，再按优先级安排。'
                  '用户希望计划容易执行，因此应保留弹性，避免安排过满。',
            ),
            TextPart(
              text:
                  '## 先做最重要的一件事\n\n'
                  '把想法变成行动，可以分成三个小步骤：\n\n'
                  '1. **明确目标**：写下今天最想完成的结果。\n'
                  '2. **缩小任务**：拆成半小时就能推进的一步。\n'
                  '3. **留出余量**：给休息和新的想法留一点空间。\n\n'
                  '> 不必一次做完所有事，先让第一步发生。',
            ),
          ],
          status: MessageStatus.completed,
          thinkingDurationMs: 2400,
        );
        await conversations.createConversation(title: '读一本书的笔记');
        await conversations.createConversation(title: '一个小工具的设计草稿');
      });

      SharedPreferences.setMockInitialValues({
        'theme_mode': mode.startsWith('dark') ? 'dark' : 'light',
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
      await tester.drag(find.byType(ChatTranscript), const Offset(0, 400));
      await tester.pumpAndSettle();
      expect(find.byTooltip('回到底部'), findsOneWidget);
      await _save(tester, '$mode-chat-history');
      await tester.tap(find.byTooltip('回到底部'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('回到底部'), findsNothing);
      await tester.drag(find.byType(ChatTranscript), const Offset(0, 400));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('已思考'));
      await tester.pumpAndSettle();
      await _save(tester, '$mode-reasoning');
      expect(find.text('已思考').hitTestable(), findsOneWidget);
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
