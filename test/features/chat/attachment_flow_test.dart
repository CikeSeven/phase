import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:phase/core/theme/app_theme.dart';
import 'package:phase/data/datasources/local/attachment_storage.dart';
import 'package:phase/data/datasources/local/secure_key_storage.dart';
import 'package:phase/data/datasources/local/settings_storage.dart';
import 'package:phase/data/models/ai_model.dart';
import 'package:phase/data/models/chat_attachment.dart';
import 'package:phase/data/models/chat_chunk.dart';
import 'package:phase/data/models/chat_message.dart';
import 'package:phase/data/models/chat_request.dart';
import 'package:phase/data/models/conversation.dart';
import 'package:phase/data/models/profile_model.dart';
import 'package:phase/data/models/provider_profile.dart';
import 'package:phase/data/repositories/conversation_repository.dart';
import 'package:phase/data/repositories/provider_profile_repository.dart';
import 'package:phase/features/chat/attachment_chips.dart';
import 'package:phase/features/chat/attachment_picker.dart';
import 'package:phase/features/chat/chat_page.dart';
import 'package:phase/providers/ai_provider.dart';
import 'package:phase/providers/provider_factory.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakePicker implements AttachmentPicker {
  ChatAttachment? next;
  int imageCalls = 0;
  int fileCalls = 0;

  @override
  Future<List<ChatAttachment>> pickImages() async {
    imageCalls++;
    return [if (next case final attachment?) attachment];
  }

  @override
  Future<ChatAttachment?> pickCameraImage() async {
    imageCalls++;
    return next;
  }

  @override
  Future<List<ChatAttachment>> pickFiles() async {
    fileCalls++;
    return [if (next case final attachment?) attachment];
  }
}

class _MemoryConversations implements ConversationRepository {
  final conversations = <Conversation>[];
  final messages = <String, List<ChatMessage>>{};
  final _changes = StreamController<void>.broadcast(sync: true);
  int _messageSequence = 0;

  @override
  AttachmentStorage? get attachments => null;

  void _notify() => _changes.add(null);

  @override
  Stream<List<Conversation>> watchConversations() async* {
    yield [...conversations];
    await for (final _ in _changes.stream) {
      yield [...conversations];
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
    final conversation = Conversation(
      id: 'c-${conversations.length}',
      title: title,
      pinned: false,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    conversations.add(conversation);
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
      id: 'm-${_messageSequence++}',
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
        attachments: old.attachments,
        status: status,
      );
    }
    _notify();
  }

  @override
  Future<void> renameConversation(String id, String title) async {}

  @override
  Future<void> setPinned(String id, {required bool pinned}) async {}

  @override
  Future<void> deleteConversation(String id) async {}

  Future<void> close() => _changes.close();
}

class _StreamingAi implements AiProvider {
  final chunks = StreamController<ChatChunk>.broadcast();
  final requests = <ChatRequest>[];

  @override
  String get id => 'fake';

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

class _MemoryKeys extends SecureKeyStorage {
  @override
  Future<String?> readApiKey(String providerProfileId) async => null;
}

void main() {
  late Directory temp;
  late ChatAttachment image;
  late _FakePicker picker;
  late _MemoryConversations repository;
  late _StreamingAi ai;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('phase-attach-flow');
    File('${temp.path}/a.png').writeAsBytesSync([137, 80, 78, 71]);
    image = ChatAttachment(
      id: 'att-1',
      type: ChatAttachmentType.image,
      name: 'a.png',
      mimeType: 'image/png',
      path: '${temp.path}/a.png',
      size: 4,
    );
    picker = _FakePicker()..next = image;
    repository = _MemoryConversations();
    ai = _StreamingAi();
    addTearDown(() async {
      await repository.close();
      await ai.chunks.close();
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });
  });

  Future<void> pumpChat(
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
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWith((ref) => preferences),
          conversationRepositoryProvider.overrideWith((ref) => repository),
          providerProfilesProvider.overrideWith(
            (ref) => Stream.value([
              ProviderProfile(
                id: 'p',
                name: '服务商',
                baseUrl: 'https://example.com/v1',
                defaultModel: 'model-x',
                models: [
                  ProfileModel(id: 'model-x', supportsImages: supportsImages),
                ],
              ),
            ]),
          ),
          secureKeyStorageProvider.overrideWith((ref) => _MemoryKeys()),
          aiProviderFactoryProvider.overrideWith(
            (ref) =>
                (_, _) => ai,
          ),
          attachmentPickerProvider.overrideWith((ref) async => picker),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
          // 流式光标动画默认静止，否则 pumpAndSettle 永不稳定。
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('相册选图 → 附件条 → 发送后附件随消息入请求并展示在气泡', (tester) async {
    await pumpChat(tester);
    await tester.tap(find.byTooltip('附件'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('attach-gallery')));
    await tester.pumpAndSettle();
    expect(picker.imageCalls, 1);
    expect(find.byKey(const ValueKey('attachment-chips')), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('chat-message-input')),
      '这是什么',
    );
    await tester.tap(find.byTooltip('发送'));
    await tester.pumpAndSettle();

    final sent = ai.requests.single.messages.firstWhere(
      (message) => message.role == ChatRole.user,
    );
    expect(sent.content, '这是什么');
    expect(sent.attachments.single.id, 'att-1');
    // 发送成功后附件条清空。
    expect(find.byKey(const ValueKey('attachment-chips')), findsNothing);
    // 气泡展示附件（图片缩略图）。
    expect(find.byType(MessageAttachments), findsOneWidget);
  });

  testWidgets('仅附件无文本也可发送，会话标题取附件名', (tester) async {
    await pumpChat(tester);
    await tester.tap(find.byTooltip('附件'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('attach-gallery')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('发送'));
    await tester.pumpAndSettle();
    expect(ai.requests.single.messages.last.role, ChatRole.user);
    expect(ai.requests.single.messages.last.attachments, isNotEmpty);
    expect(repository.conversations.single.title, '附件：a.png');
  });

  testWidgets('模型未标记支持图片时拦截图片入口，文件入口不受影响', (tester) async {
    await pumpChat(tester, supportsImages: false);
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
  });
}
