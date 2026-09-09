import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/error/failure.dart';
import 'package:phase/data/datasources/local/app_database.dart';
import 'package:phase/data/datasources/local/secure_key_storage.dart';
import 'package:phase/data/datasources/local/settings_storage.dart';
import 'package:phase/data/models/ai_model.dart';
import 'package:phase/data/models/chat_chunk.dart';
import 'package:phase/data/models/chat_message.dart';
import 'package:phase/data/models/chat_request.dart';
import 'package:phase/features/chat/chat_controller.dart';
import 'package:phase/features/chat/model_selection.dart';
import 'package:phase/data/models/reasoning_effort.dart';
import 'package:phase/providers/ai_provider.dart';
import 'package:phase/providers/provider_factory.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAiProvider implements AiProvider {
  Stream<ChatChunk> Function()? streamFactory;
  ChatRequest? lastRequest;

  @override
  String get id => 'fake';

  @override
  ProviderCapabilities get capabilities => const ProviderCapabilities();

  @override
  Stream<ChatChunk> streamChat(ChatRequest request) {
    lastRequest = request;
    return streamFactory!();
  }

  @override
  Future<List<AiModel>> listModels() async => const [];

  @override
  Future<void> validateKey() async {}
}

/// 内存版密钥存储，避免在测试中触碰平台安全存储。
class _MemoryKeyStorage extends SecureKeyStorage {
  final Map<String, String> _keys = {};

  @override
  Future<String?> readApiKey(String providerProfileId) async =>
      _keys[providerProfileId];

  @override
  Future<void> writeApiKey(String providerProfileId, String apiKey) async {
    _keys[providerProfileId] = apiKey;
  }

  @override
  Future<void> deleteApiKey(String providerProfileId) async {
    _keys.remove(providerProfileId);
  }
}

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late _FakeAiProvider fakeProvider;

  Future<void> insertProfile({String id = 'p1'}) {
    return db.upsertProviderProfile(
      ProviderProfilesCompanion.insert(
        id: id,
        name: '测试服务商',
        baseUrl: 'https://example.com/v1',
        modelsJson: Value(jsonEncode(['model-a', 'model-b'])),
        defaultModel: const Value('model-a'),
        createdAt: DateTime.now(),
      ),
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    db = AppDatabase(NativeDatabase.memory());
    fakeProvider = _FakeAiProvider();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWith((ref) => preferences),
        appDatabaseProvider.overrideWith((ref) => db),
        secureKeyStorageProvider.overrideWith((ref) => _MemoryKeyStorage()),
        aiProviderFactoryProvider.overrideWith(
          (ref) => (profile, apiKey) => fakeProvider,
        ),
      ],
    );
    // chatController 是 autoDispose：测试中无 widget 监听，需持订阅防中途销毁。
    final subscription = container.listen(chatControllerProvider, (_, _) {});
    addTearDown(subscription.close);
    // 同理，send 经由 ref.read 拿模型选择，先把它激活并保持。
    final selectionSubscription = container.listen(
      modelSelectionProvider,
      (_, _) {},
    );
    addTearDown(selectionSubscription.close);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  ChatController controller() => container.read(chatControllerProvider.notifier);

  ChatState state() => container.read(chatControllerProvider);

  test('支持推理的模型把推理等级传入 ChatRequest，不支持则不传', () async {
    // 推理模型：默认 medium 档应随请求下发。
    await db.upsertProviderProfile(
      ProviderProfilesCompanion.insert(
        id: 'p-r',
        name: '推理服务商',
        baseUrl: 'https://example.com/v1',
        modelsJson: const Value(
          '[{"id":"model-r","supportsReasoning":true}]',
        ),
        defaultModel: const Value('model-r'),
        createdAt: DateTime.now(),
      ),
    );
    fakeProvider.streamFactory =
        () => Stream.fromIterable([const ChatChunk(delta: '好')]);
    await controller().send('你好');
    expect(
      fakeProvider.lastRequest!.reasoningEffort,
      ReasoningEffort.medium,
    );

    // 非推理模型（老格式字符串列表，启发式不命中）：不下发。
    await insertProfile(id: 'p-n');
    // 新插入的 profile 要成为「最近使用」才会被选中。
    final settings = container.read(settingsStorageProvider);
    await settings.writeLastModelSelection(
      profileId: 'p-n',
      model: 'model-a',
    );
    // refresh 立即重建并等待新值，避免读到失效前的旧选择。
    container.refresh(modelSelectionProvider);
    await container.read(modelSelectionProvider.future);

    await controller().send('再来');
    expect(fakeProvider.lastRequest!.reasoningEffort, isNull);
  });

  test('send 自动建会话、两条消息落库、AI 内容逐步累积并最终 done', () async {
    await insertProfile();
    final chunks = StreamController<ChatChunk>();
    fakeProvider.streamFactory = () => chunks.stream;

    const text = '你好，请介绍一下你自己，这句话超过二十个字了';
    final sendFuture = controller().send(text);
    await pumpEventQueue();

    expect(state().conversationId, isNotNull);
    expect(state().isGenerating, isTrue);
    final conversationId = state().conversationId!;

    // 会话标题取消息前 20 字。
    final conversations = await db.select(db.conversations).get();
    expect(conversations.single.title, '你好，请介绍一下你自己，这句话超过二十个…');

    chunks.add(const ChatChunk(delta: '你好'));
    await Future<void>.delayed(const Duration(milliseconds: 200));
    chunks.add(const ChatChunk(delta: '，我是'));
    await Future<void>.delayed(const Duration(milliseconds: 200));

    // 节流写库后能看到逐步累积的中间内容。
    var messages = await db.getMessageRows(conversationId);
    expect(messages, hasLength(2));
    expect(messages[0].role, ChatRole.user);
    expect(messages[0].status, ChatMessageStatus.done);
    expect(messages[1].role, ChatRole.assistant);
    expect(messages[1].status, ChatMessageStatus.streaming);
    expect(messages[1].content, '你好，我是');

    chunks.add(const ChatChunk(delta: '相月'));
    await chunks.close();
    await sendFuture;

    messages = await db.getMessageRows(conversationId);
    expect(messages[1].content, '你好，我是相月');
    expect(messages[1].status, ChatMessageStatus.done);
    expect(messages[1].modelName, 'model-a');
    expect(state().isGenerating, isFalse);

    // 请求上下文只含 done 消息（用户消息），不含 streaming 占位。
    final request = fakeProvider.lastRequest!;
    expect(request.model, 'model-a');
    expect(request.messages, hasLength(1));
    expect(request.messages.single.role, ChatRole.user);
    expect(request.messages.single.content, text);
  });

  test('reasoning 增量与正文一起累积落库', () async {
    await insertProfile();
    fakeProvider.streamFactory = () => Stream.fromIterable([
      const ChatChunk(delta: '', reasoningDelta: '先想'),
      const ChatChunk(delta: '', reasoningDelta: '一下'),
      const ChatChunk(delta: '答案'),
    ]);

    await controller().send('你好');
    final conversationId = state().conversationId!;

    final messages = await db.getMessageRows(conversationId);
    expect(messages[1].reasoning, '先想一下');
    expect(messages[1].content, '答案');
    expect(messages[1].status, ChatMessageStatus.done);
    expect(state().isGenerating, isFalse);
  });

  test('stop 取消流式生成，保留已生成内容并标记 done', () async {
    await insertProfile();
    final chunks = StreamController<ChatChunk>();
    fakeProvider.streamFactory = () => chunks.stream;

    final sendFuture = controller().send('你好');
    await pumpEventQueue();
    final conversationId = state().conversationId!;

    chunks.add(const ChatChunk(delta: '部分内容'));
    await Future<void>.delayed(const Duration(milliseconds: 200));

    controller().stop();
    await sendFuture;

    expect(state().isGenerating, isFalse);
    final messages = await db.getMessageRows(conversationId);
    expect(messages[1].content, '部分内容');
    expect(messages[1].status, ChatMessageStatus.done);

    await chunks.close();
  });

  test('流式 Failure 时 AI 消息标记 error 并展示用户文案', () async {
    await insertProfile();
    fakeProvider.streamFactory =
        () => Stream<ChatChunk>.error(const ServerFailure('boom'));

    await controller().send('你好');
    final conversationId = state().conversationId!;

    expect(state().isGenerating, isFalse);
    final messages = await db.getMessageRows(conversationId);
    expect(messages[1].status, ChatMessageStatus.error);
    expect(messages[1].content, const ServerFailure('boom').userMessage);
  });

  test('流空跑结束（无任何增量）时 AI 消息标记 error 而非空气泡', () async {
    await insertProfile();
    fakeProvider.streamFactory = () => const Stream<ChatChunk>.empty();

    await controller().send('你好');
    final conversationId = state().conversationId!;

    expect(state().isGenerating, isFalse);
    final messages = await db.getMessageRows(conversationId);
    expect(messages[1].status, ChatMessageStatus.error);
    expect(messages[1].content, contains('空响应'));
  });

  test('立即停止（无任何增量）不误判为 error', () async {
    await insertProfile();
    final chunks = StreamController<ChatChunk>();
    fakeProvider.streamFactory = () => chunks.stream;

    final sendFuture = controller().send('你好');
    await pumpEventQueue();
    final conversationId = state().conversationId!;

    controller().stop();
    await sendFuture;

    final messages = await db.getMessageRows(conversationId);
    expect(messages[1].status, ChatMessageStatus.done);
    expect(messages[1].content, isEmpty);

    await chunks.close();
  });

  test('未配置服务商时 send 抛 Failure，不创建会话与消息', () async {
    expect(
      () => controller().send('你好'),
      throwsA(isA<UnknownFailure>()),
    );
    await pumpEventQueue();

    expect(await db.select(db.conversations).get(), isEmpty);
    expect(await db.select(db.messages).get(), isEmpty);
    expect(state().conversationId, isNull);
    expect(state().isGenerating, isFalse);
  });
}
