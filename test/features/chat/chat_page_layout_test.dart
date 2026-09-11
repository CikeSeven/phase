import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:phase/core/error/failure.dart';
import 'package:phase/core/theme/app_spacing.dart';
import 'package:phase/core/theme/app_theme.dart';
import 'package:phase/core/theme/frosted_surface.dart';
import 'package:phase/core/widgets/app_background.dart';
import 'package:phase/core/widgets/app_dialog.dart';
import 'package:phase/data/datasources/local/attachment_storage.dart';
import 'package:phase/data/datasources/local/secure_key_storage.dart';
import 'package:phase/data/datasources/local/settings_storage.dart';
import 'package:phase/data/models/ai_model.dart';
import 'package:phase/data/models/chat_chunk.dart';
import 'package:phase/data/models/chat_attachment.dart';
import 'package:phase/data/models/chat_message.dart';
import 'package:phase/data/models/chat_request.dart';
import 'package:phase/data/models/conversation.dart';
import 'package:phase/data/models/profile_model.dart';
import 'package:phase/data/models/provider_profile.dart';
import 'package:phase/data/repositories/conversation_repository.dart';
import 'package:phase/data/repositories/provider_profile_repository.dart';
import 'package:phase/features/chat/chat_controller.dart';
import 'package:phase/features/chat/chat_page.dart';
import 'package:phase/features/chat/chat_transcript.dart';
import 'package:phase/features/chat/model_picker_sheet.dart';
import 'package:phase/providers/ai_provider.dart';
import 'package:phase/providers/provider_factory.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _profile = ProviderProfile(
  id: 'profile',
  name: '长名称服务商配置用于验证模型入口不会挤压按钮',
  baseUrl: 'https://example.com/v1',
  defaultModel:
      'very-long-reasoning-model-name-2026-preview-with-extra-context',
);

class _MemoryConversations implements ConversationRepository {
  final items = <Conversation>[];
  final messages = <String, List<ChatMessage>>{};
  final _changes = StreamController<void>.broadcast(sync: true);
  Completer<void>? createGate;
  Failure? createFailure;
  Failure? deleteFailure;
  int createCalls = 0;
  int renameCalls = 0;
  int pinCalls = 0;
  int deleteCalls = 0;
  int _messageSequence = 0;

  @override
  AttachmentStorage? get attachments => null;

  void seed(int count) {
    for (var index = 0; index < count; index++) {
      items.add(
        Conversation(
          id: 'seed-$index',
          title: index == 0 ? '旅行灵感' : '历史会话 $index',
          pinned: false,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026, 9, 9).subtract(Duration(minutes: index)),
        ),
      );
    }
  }

  List<Conversation> _snapshot() => [...items]
    ..sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });

  void _notify() {
    if (!_changes.isClosed) _changes.add(null);
  }

  @override
  Stream<List<Conversation>> watchConversations() async* {
    yield _snapshot();
    await for (final _ in _changes.stream) {
      yield _snapshot();
    }
  }

  @override
  Stream<List<ChatMessage>> watchMessages(String conversationId) async* {
    yield [...?messages[conversationId]];
    await for (final _ in _changes.stream) {
      yield [...?messages[conversationId]];
    }
  }

  @override
  Future<List<ChatMessage>> getMessages(String conversationId) async => [
    ...?messages[conversationId],
  ];

  @override
  Future<Conversation> createConversation({String title = '新会话'}) async {
    createCalls++;
    await createGate?.future;
    if (createFailure case final failure?) throw failure;
    final conversation = Conversation(
      id: 'created-$createCalls',
      title: title,
      pinned: false,
      createdAt: DateTime(2026, 9, 9),
      updatedAt: DateTime(2026, 9, 9),
    );
    items.add(conversation);
    _notify();
    return conversation;
  }

  @override
  Future<ChatMessage> appendMessage({
    required String conversationId,
    required ChatRole role,
    required String content,
    ChatMessageStatus status = ChatMessageStatus.done,
    String? modelName,
    List<ChatAttachment> attachments = const [],
  }) async {
    final message = ChatMessage(
      id: 'message-${_messageSequence++}',
      role: role,
      content: content,
      status: status,
      modelName: modelName,
      attachments: attachments,
    );
    messages.putIfAbsent(conversationId, () => []).add(message);
    _notify();
    return message;
  }

  @override
  Future<void> updateMessageContent(
    String id, {
    required String content,
    required String? reasoning,
    required ChatMessageStatus status,
  }) async {
    for (final entries in messages.values) {
      final index = entries.indexWhere((message) => message.id == id);
      if (index < 0) continue;
      final old = entries[index];
      entries[index] = ChatMessage(
        id: id,
        role: old.role,
        content: content,
        reasoning: reasoning,
        modelName: old.modelName,
        status: status,
      );
    }
    _notify();
  }

  @override
  Future<void> renameConversation(String id, String title) async {
    renameCalls++;
    final index = items.indexWhere((item) => item.id == id);
    items[index] = items[index].copyWith(title: title);
    _notify();
  }

  @override
  Future<void> setPinned(String id, {required bool pinned}) async {
    pinCalls++;
    final index = items.indexWhere((item) => item.id == id);
    items[index] = items[index].copyWith(pinned: pinned);
    _notify();
  }

  @override
  Future<void> deleteConversation(String id) async {
    deleteCalls++;
    if (deleteFailure case final failure?) throw failure;
    items.removeWhere((item) => item.id == id);
    messages.remove(id);
    _notify();
  }

  Future<void> close() => _changes.close();
}

class _MemoryKeys extends SecureKeyStorage {
  @override
  Future<String?> readApiKey(String providerProfileId) async => null;
}

class _StreamingAi implements AiProvider {
  final chunks = StreamController<ChatChunk>.broadcast();
  final requests = <ChatRequest>[];

  @override
  String get id => 'widget-test';

  @override
  ProviderCapabilities get capabilities => const ProviderCapabilities();

  @override
  Stream<ChatChunk> streamChat(ChatRequest request) {
    requests.add(request);
    return chunks.stream;
  }

  @override
  Future<List<AiModel>> listModels() async => [];

  @override
  Future<void> validateKey() async {}
}

class _Harness {
  const _Harness(this.repository, this.ai, this.container, this.router);

  final _MemoryConversations repository;
  final _StreamingAi ai;
  final ProviderContainer container;
  final GoRouter router;
}

void main() {
  Future<_Harness> pumpChat(
    WidgetTester tester, {
    Size size = const Size(360, 780),
    double scale = 1,
    bool dark = false,
    bool configured = true,
    _MemoryConversations? repository,
    Stream<List<ProviderProfile>>? profiles,
    Map<String, Object> values = const {},
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    SharedPreferences.setMockInitialValues(values);
    final preferences = await SharedPreferences.getInstance();
    final conversations = repository ?? _MemoryConversations();
    final ai = _StreamingAi();
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (context, state) => const ChatPage()),
        GoRoute(
          path: '/assistants',
          builder: (context, state) => const Scaffold(body: Text('助手入口')),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const Scaffold(body: Text('设置入口')),
        ),
        GoRoute(
          path: '/settings/providers',
          builder: (context, state) => const Scaffold(body: Text('服务商配置入口')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        retry: (retryCount, error) => null,
        overrides: [
          sharedPreferencesProvider.overrideWith((ref) => preferences),
          conversationRepositoryProvider.overrideWith((ref) => conversations),
          providerProfilesProvider.overrideWith(
            (ref) => profiles ?? Stream.value(configured ? [_profile] : []),
          ),
          secureKeyStorageProvider.overrideWith((ref) => _MemoryKeys()),
          aiProviderFactoryProvider.overrideWith(
            (ref) =>
                (profile, apiKey) => ai,
          ),
        ],
        child: MaterialApp.router(
          theme: dark ? AppTheme.dark() : AppTheme.light(),
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              disableAnimations: true,
            ),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ChatPage)),
    );
    addTearDown(() async {
      await ai.chunks.close();
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
      await conversations.close();
    });
    return _Harness(conversations, ai, container, router);
  }

  Future<void> openDrawer(WidgetTester tester) async {
    await tester.tap(find.byTooltip('打开会话列表'));
    await tester.pumpAndSettle();
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byTooltip('会话菜单').first);
    await tester.pumpAndSettle();
  }

  Future<void> enterDraft(WidgetTester tester, String text) async {
    await tester.enterText(
      find.byKey(const ValueKey('chat-message-input')),
      text,
    );
    await tester.pump();
  }

  testWidgets('侧栏在手指松开前连续跟随位移，反向拖动与取消均可回到关闭状态', (tester) async {
    await pumpChat(tester, repository: _MemoryConversations()..seed(12));
    final scaffold = tester.state<ScaffoldState>(find.byType(Scaffold).first);
    final drag = await tester.startGesture(const Offset(100, 300));
    await drag.moveBy(const Offset(24, 0));
    await tester.pump();
    await drag.moveBy(const Offset(64, 0));
    await tester.pump();
    final drawer = find.byType(Drawer);
    final firstRight = tester.getRect(drawer).right;
    expect(firstRight, greaterThan(20));
    expect(firstRight, lessThan(tester.getSize(drawer).width));
    await drag.moveBy(const Offset(55, 0));
    await tester.pump();
    expect(tester.getRect(drawer).right - firstRight, closeTo(55, 2));
    await drag.moveBy(const Offset(-90, 0));
    await tester.pump();
    expect(tester.getRect(drawer).right, lessThan(firstRight));
    await tester.pump(const Duration(milliseconds: 300));
    await drag.up();
    await tester.pumpAndSettle();
    expect(scaffold.isDrawerOpen, isFalse);

    final cancelled = await tester.startGesture(const Offset(100, 300));
    await cancelled.moveBy(const Offset(24, 0));
    await tester.pump();
    await cancelled.moveBy(const Offset(45, 0));
    await tester.pump();
    expect(tester.getRect(drawer).right, greaterThan(0));
    await cancelled.cancel();
    await tester.pumpAndSettle();
    expect(scaffold.isDrawerOpen, isFalse);

    await openDrawer(tester);
    final closing = await tester.startGesture(const Offset(240, 650));
    await closing.moveBy(const Offset(-25, 0));
    await tester.pump();
    await closing.moveBy(const Offset(-200, 0));
    await tester.pump();
    expect(tester.getRect(drawer).right, lessThan(250));
    await closing.up();
    await tester.pumpAndSettle();
    expect(scaffold.isDrawerOpen, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('侧栏开关不再把焦点恢复到输入框，键盘保持收起', (tester) async {
    await pumpChat(tester, repository: _MemoryConversations()..seed(3));

    bool inputHasPrimaryFocus() {
      final editable = tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(const ValueKey('chat-message-input')),
          matching: find.byType(EditableText),
        ),
      );
      return editable.focusNode.hasPrimaryFocus;
    }

    // 按钮打开 + 关闭按钮关闭
    await tester.tap(find.byKey(const ValueKey('chat-message-input')));
    await tester.pumpAndSettle();
    expect(inputHasPrimaryFocus(), isTrue);
    await openDrawer(tester);
    expect(inputHasPrimaryFocus(), isFalse);
    await tester.tap(find.byTooltip('关闭侧栏'));
    await tester.pumpAndSettle();
    expect(inputHasPrimaryFocus(), isFalse);
    expect(find.byType(Drawer), findsNothing);

    // 聚焦输入框后拖拽打开 + 点遮罩关闭
    await tester.tap(find.byKey(const ValueKey('chat-message-input')));
    await tester.pumpAndSettle();
    final drag = await tester.startGesture(const Offset(100, 300));
    await drag.moveBy(const Offset(260, 0));
    await drag.up();
    await tester.pumpAndSettle();
    expect(find.byType(Drawer), findsOneWidget);
    expect(inputHasPrimaryFocus(), isFalse);
    await tester.tapAt(const Offset(350, 300));
    await tester.pumpAndSettle();
    expect(find.byType(Drawer), findsNothing);
    expect(inputHasPrimaryFocus(), isFalse);

    // 搜索框聚焦后关闭再打开，输入框与搜索框都不抢焦点
    await openDrawer(tester);
    await tester.tap(find.byKey(const ValueKey('conversation-search')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('关闭侧栏'));
    await tester.pumpAndSettle();
    expect(inputHasPrimaryFocus(), isFalse);
    await openDrawer(tester);
    expect(inputHasPrimaryFocus(), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('侧栏打开时系统返回只关闭侧栏，不退出根页面', (tester) async {
    final harness = await pumpChat(
      tester,
      repository: _MemoryConversations()..seed(3),
    );
    await openDrawer(tester);
    expect(find.byType(Drawer), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(Drawer), findsNothing);
    expect(find.byType(ChatPage), findsOneWidget);
    expect(
      harness.router.routerDelegate.currentConfiguration.uri.toString(),
      '/',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('侧栏进入设置后返回，侧栏保持打开且不抢焦点', (tester) async {
    await pumpChat(tester, repository: _MemoryConversations()..seed(3));
    await openDrawer(tester);
    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    expect(find.text('设置入口'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('设置入口'), findsNothing);
    expect(find.byType(Drawer), findsOneWidget);
    expect(tester.takeException(), isNull);

    // 侧栏仍处于打开状态，系统返回依然可以关闭它。
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(Drawer), findsNothing);
    expect(find.byType(ChatPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('紧凑会话行保留48触区，更多菜单对齐按钮而非会话左边', (tester) async {
    await pumpChat(tester, repository: _MemoryConversations()..seed(20));
    await openDrawer(tester);
    final row = find.byKey(const ValueKey('conversation-row-seed-0'));
    final button = find.byKey(const ValueKey('conversation-menu-seed-0'));
    expect(tester.getSize(row).height, inInclusiveRange(48, 60));
    expect(tester.getSize(button).shortestSide, greaterThanOrEqualTo(48));
    final buttonRect = tester.getRect(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    final item = find.widgetWithText(MenuItemButton, '重命名');
    final menuItemRect = tester.getRect(item);
    expect(menuItemRect.left, greaterThan(tester.getRect(row).left + 80));
    expect(menuItemRect.right, lessThanOrEqualTo(buttonRect.right + 8));
    expect(menuItemRect.top, greaterThanOrEqualTo(buttonRect.bottom - 1));
    await tester.tapAt(const Offset(355, 680));
    await tester.pumpAndSettle();
    await tester.longPress(find.text('旅行灵感'));
    await tester.pumpAndSettle();
    expect(tester.getRect(item).left, closeTo(menuItemRect.left, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('靠近侧栏底部的菜单向上避让，不偏到左侧或超出屏幕', (tester) async {
    await pumpChat(tester, repository: _MemoryConversations()..seed(30));
    await openDrawer(tester);
    final button = find.byKey(const ValueKey('conversation-menu-seed-6'));
    await Scrollable.ensureVisible(tester.element(button), alignment: 1);
    await tester.pumpAndSettle();
    final buttonRect = tester.getRect(button);
    expect(buttonRect.top, greaterThan(580));
    await tester.tap(button);
    await tester.pumpAndSettle();
    final first = tester.getRect(find.widgetWithText(MenuItemButton, '重命名'));
    final last = tester.getRect(find.widgetWithText(MenuItemButton, '删除'));
    expect(first.left, greaterThan(80));
    expect(first.right, lessThanOrEqualTo(buttonRect.right + 8));
    expect(first.top, greaterThanOrEqualTo(0));
    expect(last.bottom, lessThanOrEqualTo(780));
    expect(first.top, lessThan(buttonRect.top));
    expect(tester.takeException(), isNull);
  });

  testWidgets('输入栏和侧栏不再展示重复教程或标语', (tester) async {
    await pumpChat(tester);
    expect(find.text('支持多行输入'), findsNothing);
    expect(find.text('正在生成回复'), findsNothing);
    await openDrawer(tester);
    expect(find.text('留住灵感，继续每一次对话'), findsNothing);
    expect(find.text('暂无会话'), findsOneWidget);
  });

  for (final size in [const Size(320, 720), const Size(360, 780)]) {
    for (final scale in [1.3, 2.0]) {
      testWidgets('空态/长模型名 ${size.width}dp ${scale}x 与键盘布局', (tester) async {
        await pumpChat(tester, size: size, scale: scale, dark: scale == 2);
        expect(find.byType(AppBackground), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);
        expect(find.text('向相月提问，或选择一个助手'), findsOneWidget);
        expect(find.text('选择助手'), findsOneWidget);
        final attach = find.byTooltip('附件');
        expect(attach, findsOneWidget);
        // 附件按钮在输入栏内，不挤压发送触区。
        expect(
          tester.getRect(attach).right,
          lessThanOrEqualTo(tester.getRect(find.byTooltip('发送')).left),
        );
        expect(find.byIcon(Symbols.expand_more), findsOneWidget);
        final modelText = tester.widget<Text>(
          find.text(_profile.defaultModel!),
        );
        expect(modelText.overflow, TextOverflow.ellipsis);
        expect(modelText.maxLines, 1);
        final modelParagraph = tester.renderObject<RenderParagraph>(
          find.text(_profile.defaultModel!),
        );
        expect(modelParagraph.didExceedMaxLines, isTrue);
        final iconRect = tester.getRect(find.byIcon(Symbols.expand_more));
        expect(
          iconRect.left -
              tester.getRect(find.text(_profile.defaultModel!)).right,
          closeTo(4, 0.5),
        );
        expect(
          iconRect.right,
          lessThanOrEqualTo(tester.getRect(find.byTooltip('新会话')).left),
        );
        expect(
          tester.getSize(find.byTooltip('打开会话列表')).shortestSide,
          greaterThanOrEqualTo(48),
        );
        expect(tester.takeException(), isNull);

        await tester.enterText(
          find.byKey(const ValueKey('chat-message-input')),
          '第一行内容\n第二行内容\n第三行内容\n第四行内容\n第五行内容\n第六行内容',
        );
        tester.view.viewInsets = const FakeViewPadding(bottom: 260);
        await tester.pumpAndSettle();
        final field = tester.widget<TextField>(
          find.byKey(const ValueKey('chat-message-input')),
        );
        expect(field.maxLines, 5);
        expect(
          tester.getSize(find.byType(TextField)).width,
          greaterThan(size.width - 80),
        );
        expect(
          tester.getBottomRight(find.byTooltip('发送')).dy,
          lessThanOrEqualTo(size.height - 260),
        );
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('横屏与键盘下空态可滚动，选择助手是真实入口', (tester) async {
    await pumpChat(tester, size: const Size(680, 360), scale: 2);
    tester.view.viewInsets = const FakeViewPadding(bottom: 100);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('选择助手'));
    await tester.tap(find.text('选择助手'));
    await tester.pumpAndSettle();
    expect(find.text('助手入口'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 680.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('短模型名下拉图标紧邻文字 ${width}dp ${scale}x', (tester) async {
        const model = 'gpt-5';
        await pumpChat(
          tester,
          size: Size(width, 780),
          scale: scale,
          profiles: Stream.value([_profile.copyWith(defaultModel: model)]),
        );
        final paragraph = tester.renderObject<RenderParagraph>(
          find.text(model),
        );
        final textBox = paragraph
            .getBoxesForSelection(
              const TextSelection(baseOffset: 0, extentOffset: model.length),
            )
            .single;
        final textRight = paragraph.localToGlobal(Offset(textBox.right, 0)).dx;
        final icon = find.byIcon(Symbols.expand_more);
        final iconRect = tester.getRect(icon);
        expect(iconRect.left - textRight, closeTo(4, 0.5));
        expect(
          iconRect.right,
          lessThanOrEqualTo(tester.getRect(find.byTooltip('新会话')).left),
        );
        expect(
          tester
              .getSize(find.byKey(const ValueKey('chat-model-picker')))
              .height,
          greaterThanOrEqualTo(48),
        );
        await tester.tap(icon);
        await tester.pumpAndSettle();
        expect(find.byType(ModelPickerSheet), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('顶栏在模型名右侧用不同颜色显示当前推理等级', (tester) async {
    const profile = ProviderProfile(
      id: 'profile',
      name: '服务商',
      baseUrl: 'https://example.com/v1',
      defaultModel: 'think-model',
      models: [ProfileModel(id: 'think-model', supportsReasoning: true)],
    );
    await pumpChat(
      tester,
      values: const {'last_reasoning_effort': 'high'},
      profiles: Stream.value([profile]),
    );
    final effort = find.byKey(const ValueKey('chat-reasoning-effort'));
    expect(effort, findsOneWidget);
    expect(tester.widget<Text>(effort).data, '高');
    // 跟在模型名右侧，颜色与模型名不同。
    final modelRect = tester.getRect(find.text('think-model'));
    expect(tester.getRect(effort).left, greaterThan(modelRect.right));
    final colors = Theme.of(tester.element(effort)).colorScheme;
    expect(tester.widget<Text>(effort).style?.color, isNot(colors.primary));
    expect(
      tester.widget<Text>(find.text('think-model')).style?.color,
      colors.primary,
    );
  });

  testWidgets('顶栏对关闭或不支持推理的模型不显示推理等级', (tester) async {
    // 支持推理但等级为关。
    await pumpChat(
      tester,
      profiles: Stream.value([
        const ProviderProfile(
          id: 'profile',
          name: '服务商',
          baseUrl: 'https://example.com/v1',
          defaultModel: 'think-model',
          models: [ProfileModel(id: 'think-model', supportsReasoning: true)],
        ),
      ]),
    );
    expect(find.text('think-model'), findsOneWidget);
    expect(find.byKey(const ValueKey('chat-reasoning-effort')), findsNothing);
  });

  testWidgets('输入栏悬浮于消息区之上，列表按其实测高度留白', (tester) async {
    final repository = _MemoryConversations()..seed(1);
    repository.messages['seed-0'] = [
      const ChatMessage(
        id: 'saved',
        role: ChatRole.assistant,
        content: '已有的回复',
      ),
    ];
    await pumpChat(tester, repository: repository);
    await openDrawer(tester);
    await tester.tap(find.text('旅行灵感'));
    await tester.pumpAndSettle();

    // 消息区延伸到屏幕底部，发送按钮悬浮在消息区之上（而不是把消息区顶上去）。
    final transcriptRect = tester.getRect(find.byType(ChatTranscript));
    final sendCenter = tester.getCenter(find.byTooltip('发送'));
    expect(transcriptRect.contains(sendCenter), isTrue);

    // 列表底部留白 ≥ 输入栏高度，末条消息可以滚出遮挡区。
    final listView = tester.widget<ListView>(
      find.descendant(
        of: find.byType(ChatTranscript),
        matching: find.byType(ListView),
      ),
    );
    final composerHeight = tester
        .getRect(find.byKey(const ValueKey('chat-message-input')))
        .height;
    expect(
      listView.padding!.resolve(TextDirection.ltr).bottom,
      greaterThan(composerHeight + AppSpacing.m),
    );
  });

  testWidgets('模型下拉入口保留 showModelPickerSheet 接口', (tester) async {
    await pumpChat(tester);
    await tester.tap(find.byKey(const ValueKey('chat-model-picker')));
    await tester.pumpAndSettle();
    expect(find.byType(ModelPickerSheet), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
  });

  for (final dark in [false, true]) {
    testWidgets('输入框聚焦时外边框变为主色，失焦后恢复 ${dark ? '深色' : '浅色'}', (tester) async {
      await pumpChat(tester, dark: dark);
      final input = find.byKey(const ValueKey('chat-message-input'));
      final surface = find.ancestor(
        of: input,
        matching: find.byType(FrostedSurface),
      );
      final colors = Theme.of(tester.element(input)).colorScheme;
      final size = tester.getSize(surface);
      Color borderColor() {
        final material = tester.widget<Material>(
          find.descendant(of: surface, matching: find.byType(Material)).first,
        );
        return (material.shape! as RoundedRectangleBorder).side.color;
      }

      final idleColor = borderColor();
      expect(idleColor, isNot(colors.primary));
      await tester.tap(input);
      await tester.pumpAndSettle();
      expect(borderColor(), colors.primary);
      expect(tester.getSize(surface), size);
      await tester.enterText(input, '保留草稿');
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      expect(borderColor(), colors.primary);

      await openDrawer(tester);
      expect(borderColor(), idleColor);
      await tester.tap(find.byTooltip('关闭侧栏'));
      await tester.pumpAndSettle();
      expect(borderColor(), idleColor);
      expect(tester.widget<TextField>(input).controller!.text, '保留草稿');
      expect(tester.testTextInput.isVisible, isFalse);
      await tester.tap(input);
      await tester.pumpAndSettle();
      expect(borderColor(), colors.primary);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('输入栏在短视口与键盘切换时保留编辑状态和焦点', (tester) async {
    await pumpChat(tester, scale: 2);
    await enterDraft(tester, '第一行\n第二行\n第三行');
    final editor = find.descendant(
      of: find.byKey(const ValueKey('chat-message-input')),
      matching: find.byType(EditableText),
    );
    final editorState = tester.state(editor);
    final focus = tester.widget<EditableText>(editor).focusNode;
    expect(focus.hasFocus, isTrue);

    tester.view.viewInsets = const FakeViewPadding(bottom: 580);
    await tester.pumpAndSettle();
    expect(tester.state(editor), same(editorState));
    expect(focus.hasFocus, isTrue);
    expect(tester.takeException(), isNull);

    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    await tester.pumpAndSettle();
    expect(tester.state(editor), same(editorState));
    expect(focus.hasFocus, isTrue);
    tester.testTextInput.enterText('保留焦点后继续输入');
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '保留焦点后继续输入',
    );
  });

  testWidgets('未配置发送保留草稿并提供去配置导航', (tester) async {
    final harness = await pumpChat(tester, configured: false);
    await enterDraft(tester, '尚未发送的草稿');
    await tester.tap(find.byTooltip('发送'));
    await tester.pumpAndSettle();
    expect(find.text('请先在设置中配置服务商与模型'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '尚未发送的草稿',
    );
    expect(harness.repository.createCalls, 0);
    await tester.tap(find.text('去配置'));
    await tester.pumpAndSettle();
    expect(find.text('服务商配置入口'), findsOneWidget);
  });

  testWidgets('模型读取错误显示失败而非无配置，发送不清草稿', (tester) async {
    final harness = await pumpChat(
      tester,
      profiles: Stream.error(const NetworkFailure('profile stream')),
    );
    expect(find.text('模型加载失败'), findsOneWidget);
    expect(find.text('检查配置'), findsOneWidget);
    await enterDraft(tester, '保留内容');
    await tester.tap(find.byTooltip('发送'));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '保留内容',
    );
    expect(harness.repository.createCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('快速连点本地防重，接收后才清草稿，停止保留双通道和下一条草稿', (tester) async {
    final repository = _MemoryConversations()..createGate = Completer<void>();
    final harness = await pumpChat(tester, repository: repository);
    await enterDraft(tester, '第一条问题');
    await tester.tap(find.byTooltip('发送'));
    await tester.tap(find.byTooltip('发送'));
    await tester.pumpAndSettle();
    expect(repository.createCalls, 1);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '第一条问题',
    );
    expect(harness.ai.requests, isEmpty);

    repository.createGate!.complete();
    await tester.pumpAndSettle();
    expect(harness.ai.requests, hasLength(1));
    expect(repository.messages.values.single, hasLength(2));
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    expect(find.byTooltip('停止生成'), findsOneWidget);
    expect(harness.container.read(chatControllerProvider).messages, isEmpty);
    await enterDraft(tester, '下一条草稿');
    harness.ai.chunks.add(const ChatChunk(delta: '答案', reasoningDelta: '推演过程'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pumpAndSettle();
    expect(find.text('答案', findRichText: true), findsOneWidget);
    expect(find.text('思考中…'), findsOneWidget);
    expect(find.text('推演过程'), findsOneWidget);

    await tester.tap(find.byTooltip('停止生成'));
    await tester.pumpAndSettle();
    final reply = repository.messages.values.single.last;
    expect(reply.status, ChatMessageStatus.done);
    expect(reply.content, '答案');
    expect(reply.reasoning, '推演过程');
    expect(find.text('已思考'), findsOneWidget);
    expect(find.text('推演过程'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '下一条草稿',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('发送前落库失败显示 Failure 且保留草稿和重试能力', (tester) async {
    final repository = _MemoryConversations()
      ..createFailure = const NetworkFailure('create');
    await pumpChat(tester, repository: repository);
    await enterDraft(tester, '不能丢的草稿');
    await tester.tap(find.byTooltip('发送'));
    await tester.pumpAndSettle();
    expect(find.text('网络连接失败，请检查网络后重试'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '不能丢的草稿',
    );
    expect(repository.items, isEmpty);
    await tester.drag(find.byType(SnackBar), const Offset(0, 100));
    await tester.pumpAndSettle();
    repository.createFailure = null;
    await tester.tap(find.byTooltip('发送'));
    await tester.pumpAndSettle();
    expect(repository.createCalls, 2);
    expect(find.byTooltip('停止生成'), findsOneWidget);
    await tester.tap(find.byTooltip('停止生成'));
    await tester.pumpAndSettle();
  });

  testWidgets('侧栏搜索惰性列表，重命名取消/保存/置顶/删除都调用真实动作', (tester) async {
    final repository = _MemoryConversations()..seed(80);
    repository.messages['seed-0'] = [
      const ChatMessage(
        id: 'saved',
        role: ChatRole.assistant,
        content: '已有的旅行建议',
      ),
    ];
    final harness = await pumpChat(tester, repository: repository);
    await openDrawer(tester);
    expect(find.byKey(const ValueKey('seed-79')), findsNothing);
    expect(find.text('设置'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('conversation-search')),
      '旅行',
    );
    await tester.pumpAndSettle();
    expect(find.text('旅行灵感'), findsOneWidget);
    expect(find.text('历史会话 1'), findsNothing);

    await openMenu(tester);
    await tester.tap(find.text('重命名'));
    await tester.pumpAndSettle();
    expect(find.byType(AppDialog), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('conversation-name-input')),
      '不应保存',
    );
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(repository.renameCalls, 0);
    expect(repository.items.first.title, '旅行灵感');
    expect(tester.takeException(), isNull);

    await openMenu(tester);
    await tester.tap(find.text('重命名'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('conversation-name-input')),
      '新的旅行计划',
    );
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(repository.renameCalls, 1);
    expect(find.text('新的旅行计划'), findsOneWidget);
    await openMenu(tester);
    await tester.tap(find.text('置顶'));
    await tester.pumpAndSettle();
    expect(repository.pinCalls, 1);
    expect(repository.items.first.pinned, isTrue);

    await tester.tap(find.text('新的旅行计划'));
    await tester.pumpAndSettle();
    expect(
      harness.container.read(chatControllerProvider).conversationId,
      'seed-0',
    );
    expect(find.text('已有的旅行建议', findRichText: true), findsOneWidget);
    await openDrawer(tester);
    await openMenu(tester);
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    final deleteButton = find.widgetWithText(FilledButton, '删除');
    final colors = Theme.of(tester.element(deleteButton)).colorScheme;
    expect(
      tester
          .widget<FilledButton>(deleteButton)
          .style!
          .backgroundColor!
          .resolve({}),
      colors.error,
    );
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();
    expect(repository.deleteCalls, 1);
    expect(repository.items.any((item) => item.id == 'seed-0'), isFalse);
    expect(repository.messages.containsKey('seed-0'), isFalse);
    expect(
      harness.container.read(chatControllerProvider).conversationId,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('320dp 2x 键盘下重命名取消不提前销毁编辑 controller', (tester) async {
    final repository = _MemoryConversations()..seed(1);
    await pumpChat(
      tester,
      repository: repository,
      size: const Size(320, 720),
      scale: 2,
    );
    await openDrawer(tester);
    await tester.ensureVisible(find.byTooltip('会话菜单'));
    await openMenu(tester);
    await tester.tap(find.text('重命名'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('conversation-name-input')),
      '临时修改',
    );
    await tester.ensureVisible(find.text('取消'));
    await tester.tap(find.text('取消'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(repository.renameCalls, 0);
    expect(find.byType(AppDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('删除失败保留当前会话并显示错误，设置往返保留侧栏', (tester) async {
    final repository = _MemoryConversations()..seed(1);
    final harness = await pumpChat(tester, repository: repository);
    await openDrawer(tester);
    await tester.tap(find.text('旅行灵感'));
    await tester.pumpAndSettle();
    await openDrawer(tester);
    repository.deleteFailure = const NetworkFailure('delete');
    await openMenu(tester);
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();
    expect(
      harness.container.read(chatControllerProvider).conversationId,
      'seed-0',
    );
    expect(repository.items, hasLength(1));
    expect(find.text('网络连接失败，请检查网络后重试'), findsOneWidget);

    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    expect(find.text('设置入口'), findsOneWidget);
    harness.router.pop();
    await tester.pumpAndSettle();
    final scaffold = tester.state<ScaffoldState>(find.byType(Scaffold).first);
    expect(scaffold.isDrawerOpen, isTrue);
    expect(find.byType(TextField), findsNWidgets(2));
  });
}
