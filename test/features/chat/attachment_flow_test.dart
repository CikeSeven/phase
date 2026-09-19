import 'dart:async';
import 'dart:io';

import 'package:phase/data/repositories/workspace_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:phase/core/theme/app_theme.dart';
import 'package:phase/data/datasources/local/app_database.dart';
import 'package:phase/data/datasources/local/attachment_storage.dart';
import 'package:phase/data/datasources/local/secure_key_storage.dart';
import 'package:phase/data/datasources/local/settings_storage.dart';
import 'package:phase/data/models/api_protocol.dart';
import 'package:phase/data/models/attachment.dart';
import 'package:phase/data/models/chat_chunk.dart';
import 'package:phase/data/models/chat_request.dart';
import 'package:phase/data/models/profile_model.dart';
import 'package:phase/data/models/provider_profile.dart';
import 'package:phase/data/repositories/provider_profile_repository.dart';
import 'package:phase/features/chat/attachment_picker.dart';
import 'package:phase/features/chat/chat_page.dart';
import 'package:phase/providers/ai_provider.dart';
import 'package:phase/providers/provider_factory.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_secure_storage.dart';

/// 预制附件的选择器：返回测试临时目录里的文件，不触发平台选择器。
///
/// 附件落库、请求组装与消息引用由 chat_controller_test 与 attachment_test
/// 覆盖；这里只验证界面交互（入口、拦截、附件条）。
class _FakePicker implements AttachmentPicker {
  Attachment? next;
  int imageCalls = 0;
  int fileCalls = 0;

  @override
  Future<List<Attachment>> pickImages() async {
    imageCalls++;
    return [?next];
  }

  @override
  Future<Attachment?> pickCameraImage() async {
    imageCalls++;
    return next;
  }

  @override
  Future<List<Attachment>> pickFiles() async {
    fileCalls++;
    return [?next];
  }
}

class _IdleAi implements AiProvider {
  final requests = <ChatRequest>[];

  @override
  ApiProtocol get protocol => ApiProtocol.openaiCompletions;

  @override
  Future<List<ProfileModel>> listModels() async => const [];

  @override
  Stream<ChatChunk> streamChat(ChatRequest request) {
    requests.add(request);
    return const Stream<ChatChunk>.empty();
  }
}

void main() {
  late Directory temp;
  late AppDatabase db;
  late AttachmentStorage storage;
  late _FakePicker picker;
  late _IdleAi ai;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('phase_attach_flow');
    db = openAppDatabase(
      path: p.join(temp.path, 'phase.sqlite'),
      hexKey: '0123456789abcdef' * 4,
      background: false,
    );
    storage = AttachmentStorage(Directory(p.join(temp.path, 'files')));
    picker = _FakePicker();
    ai = _IdleAi();
    addTearDown(() async {
      await db.close();
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });
  });

  Future<Attachment> makeAttachment(AttachmentKind kind, String name) {
    return storage.save(
      name: name,
      mimeType: kind == AttachmentKind.image ? 'image/png' : 'text/plain',
      kind: kind,
      bytes: const [1, 2, 3, 4],
    );
  }

  /// 收尾：拆组件树 → 关容器（解除数据库流订阅）→ 关库。
  ///
  /// 顺序与 chat_flow_test 一致：drift 关闭查询流时会排零延时清理计时器，
  /// 先解除订阅再关库，测试结束前它们就能跑完。
  Future<void> closeChat(
    WidgetTester tester,
    ProviderContainer container,
  ) async {
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    var closed = false;
    unawaited(db.close().then((_) => closed = true));
    for (var i = 0; i < 40 && !closed; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(closed, isTrue, reason: '数据库未在预期时间内关闭');
  }

  Future<ProviderContainer> pumpChat(
    WidgetTester tester, {
    bool supportsImages = true,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const ChatPage()),
        GoRoute(
          path: '/settings/providers',
          builder: (_, _) => const Scaffold(body: Text('配置页')),
        ),
      ],
    );
    addTearDown(router.dispose);
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWith((ref) => preferences),
        appDatabaseProvider.overrideWith((ref) => db),
        secureKeyStorageProvider.overrideWith(
          (ref) => SecureKeyStorage(FakeSecureStorage()),
        ),
        workspaceRepositoryProvider.overrideWith(
          (ref) => WorkspaceRepository(db, storage.root),
        ),
        attachmentStorageProvider.overrideWith((ref) => storage),
        providerProfilesProvider.overrideWith(
          (ref) => Stream.value([
            ProviderProfile(
              id: 'p',
              name: '服务商',
              protocol: ApiProtocol.openaiCompletions,
              baseUrl: 'https://example.com/v1',
              defaultModel: 'model-x',
              models: [
                ProfileModel(id: 'model-x', supportsImages: supportsImages),
              ],
              createdAt: DateTime(2026),
            ),
          ]),
        ),
        aiProviderFactoryProvider.overrideWith(
          (ref) =>
              (_, _) => ai,
        ),
        attachmentPickerProvider.overrideWith((ref) async => picker),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
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
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('相册选图后出现附件条，可移除', (tester) async {
    await tester.runAsync(() async {
      picker.next = await makeAttachment(AttachmentKind.image, 'a.png');
    });
    final container = await pumpChat(tester);
    await tester.tap(find.byTooltip('附件'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('attach-gallery')));
    await tester.pumpAndSettle();

    expect(picker.imageCalls, 1);
    expect(find.byKey(const ValueKey('attachment-chips')), findsOneWidget);
    expect(
      find.byKey(ValueKey('attachment-${picker.next!.id}')),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('移除附件'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('attachment-chips')), findsNothing);

    await closeChat(tester, container);
  });

  testWidgets('选择文件后只出现附件条，不进入文本输入框', (tester) async {
    await tester.runAsync(() async {
      picker.next = await makeAttachment(AttachmentKind.text, 'note.txt');
    });
    final container = await pumpChat(tester);
    await tester.tap(find.byTooltip('附件'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('attach-file')));
    await tester.pumpAndSettle();

    expect(picker.fileCalls, 1);
    expect(find.byKey(const ValueKey('attachment-chips')), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('chat-message-input')))
          .controller!
          .text,
      isEmpty,
    );

    await closeChat(tester, container);
  });

  testWidgets('模型未标记支持图片时拦截图片入口，文件入口不受影响', (tester) async {
    await tester.runAsync(() async {
      picker.next = await makeAttachment(AttachmentKind.text, 'note.txt');
    });
    final container = await pumpChat(tester, supportsImages: false);
    await tester.tap(find.byTooltip('附件'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('attach-gallery')));
    await tester.pumpAndSettle();
    expect(picker.imageCalls, 0);
    expect(find.text('当前模型未标记支持图片输入'), findsOneWidget);

    // SnackBar 会短暂遮住底部输入栏，等它消失后再打开面板。
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('附件'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('attach-file')));
    await tester.pumpAndSettle();
    expect(picker.fileCalls, 1);
    expect(find.byKey(const ValueKey('attachment-chips')), findsOneWidget);

    await closeChat(tester, container);
  });
}
