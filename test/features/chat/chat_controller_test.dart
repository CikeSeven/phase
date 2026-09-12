import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:phase/core/error/failure.dart';
import 'package:phase/core/error/provider_error.dart';
import 'package:phase/data/datasources/local/app_database.dart';
import 'package:phase/data/datasources/local/attachment_storage.dart';
import 'package:phase/data/datasources/local/secure_key_storage.dart';
import 'package:phase/data/datasources/local/settings_storage.dart';
import 'package:phase/data/models/api_protocol.dart';
import 'package:phase/data/models/chat_chunk.dart';
import 'package:phase/data/models/chat_message.dart';
import 'package:phase/data/models/chat_request.dart';
import 'package:phase/data/models/message_part.dart';
import 'package:phase/data/models/profile_model.dart';
import 'package:phase/data/models/provider_profile.dart';
import 'package:phase/data/models/reasoning_effort.dart';
import 'package:phase/data/repositories/conversation_repository.dart';
import 'package:phase/data/repositories/provider_profile_repository.dart';
import 'package:phase/features/chat/chat_controller.dart';
import 'package:phase/features/chat/model_selection.dart';
import 'package:phase/providers/ai_provider.dart';
import 'package:phase/providers/openai_completions/openai_completions_provider.dart';
import 'package:phase/providers/provider_factory.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_secure_storage.dart';

/// 可控的协议实现：按需产出类型化事件流。
class _FakeAiProvider implements AiProvider {
  _FakeAiProvider(this.protocol);

  @override
  final ApiProtocol protocol;

  Stream<ChatChunk> Function()? streamFactory;
  ChatRequest? lastRequest;

  @override
  Future<List<ProfileModel>> listModels() async => const [];

  @override
  Stream<ChatChunk> streamChat(ChatRequest request) {
    lastRequest = request;
    return streamFactory!();
  }
}

/// 文本应答的常规事件序列（开始块 → 增量 → 收口 → 结束）。
List<ChatChunk> textResponse(String text, {String partId = 'text_0'}) => [
  PartStart(partId: partId, kind: PartKind.text),
  TextDelta(partId: partId, text: text),
  PartEnd(
    partId: partId,
    part: TextPart(text: text, partId: partId),
  ),
  const ResponseEnd(),
];

void main() {
  late Directory tempDir;
  late AppDatabase db;
  late ProviderContainer container;
  late _FakeAiProvider fakeProvider;
  late ProviderProfile profile;

  const dbKey =
      'a1b2c3d4e5f60718293a4b5c6d7e8f90'
      'a1b2c3d4e5f60718293a4b5c6d7e8f90';

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    tempDir = Directory.systemTemp.createTempSync('phase_controller');
    db = openAppDatabase(
      path: p.join(tempDir.path, 'phase.sqlite'),
      hexKey: dbKey,
    );
    final keys = FakeSecureStorage({'api_key_p1': 'sk-test'});
    fakeProvider = _FakeAiProvider(ApiProtocol.openaiCompletions);
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWith((ref) => preferences),
        appDatabaseProvider.overrideWith((ref) => db),
        secureKeyStorageProvider.overrideWith((ref) => SecureKeyStorage(keys)),
        // 附件写到临时目录，不依赖平台文档目录。
        attachmentStorageProvider.overrideWith(
          (ref) => AttachmentStorage(Directory(p.join(tempDir.path, 'files'))),
        ),
        aiProviderFactoryProvider.overrideWith(
          (ref) =>
              (profile, apiKey) => fakeProvider,
        ),
      ],
    );
    // autoDispose 的 provider 在测试里没有 widget 监听，需持订阅防中途销毁。
    addTearDown(container.listen(chatControllerProvider, (_, _) {}).close);
    addTearDown(container.listen(modelSelectionProvider, (_, _) {}).close);

    final profiles = ProviderProfileRepository(db, SecureKeyStorage(keys));
    profile = await profiles.createProfile(
      name: '测试服务商',
      baseUrl: 'https://example.com/v1',
      protocol: ApiProtocol.openaiCompletions,
      models: const [
        ProfileModel(id: 'model-a', enabled: true, supportsReasoning: true),
      ],
      defaultModel: 'model-a',
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
    tempDir.deleteSync(recursive: true);
  });

  ChatController controller() =>
      container.read(chatControllerProvider.notifier);

  ChatState state() => container.read(chatControllerProvider);

  /// 等待发送流程推进到可观察状态（send 内部有多次异步落库）。
  Future<void> waitUntil(FutureOr<bool> Function() condition) async {
    var met = false;
    for (var i = 0; i < 100 && !met; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      met = await condition();
    }
    expect(met, isTrue, reason: '等待条件超时');
  }

  Future<ConversationThread> threadOf(String conversationId) async {
    final repository = await container.read(
      conversationRepositoryProvider.future,
    );
    return (await repository
        .watchThread(conversationId)
        .firstWhere((value) => value != null))!;
  }

  for (final reopen in [false, true]) {
    test('连续发送保持完整历史和父链（重新打开会话：$reopen）', () async {
      fakeProvider.streamFactory = () =>
          Stream.fromIterable(textResponse('回答1'));
      await controller().send('问题1');
      final conversationId = state().conversationId!;
      var thread = await threadOf(conversationId);

      if (reopen) {
        controller().startNewConversation();
        await controller().openConversation(conversationId);
      }

      for (var round = 2; round <= 3; round++) {
        final previousAnswerId = thread.currentMessageId;
        fakeProvider.streamFactory = () =>
            Stream.fromIterable(textResponse('回答$round'));
        await controller().send('问题$round');
        thread = await threadOf(conversationId);

        expect(state().conversationId, conversationId);
        expect(thread.conversation.title, '问题1');
        expect(thread.messages, hasLength(round * 2));
        expect(thread.branch, hasLength(round * 2));
        expect(thread.branch[round * 2 - 2].parentId, previousAnswerId);
        expect(thread.branch.last.parentId, thread.branch[round * 2 - 2].id);
        expect(thread.branch.last.text, '回答$round');

        final history = fakeProvider.lastRequest!.messages;
        expect(
          history.map(
            (message) => (
              message.role,
              message.parts.whereType<ResolvedText>().single.text,
            ),
          ),
          [
            for (var previous = 1; previous < round; previous++) ...[
              (ChatRole.user, '问题$previous'),
              (ChatRole.assistant, '回答$previous'),
            ],
            (ChatRole.user, '问题$round'),
          ],
        );
      }
    });
  }

  test('发送使用仓储当前分支，不把其他分支带入上下文', () async {
    fakeProvider.streamFactory = () => Stream.fromIterable(textResponse('回答1'));
    await controller().send('问题1');
    final conversationId = state().conversationId!;
    final first = await threadOf(conversationId);

    fakeProvider.streamFactory = () => Stream.fromIterable(textResponse('旧回答'));
    await controller().send('旧问题');
    final repository = await container.read(
      conversationRepositoryProvider.future,
    );
    await repository.setCurrentMessage(conversationId, first.currentMessageId!);

    fakeProvider.streamFactory = () => Stream.fromIterable(textResponse('新回答'));
    await controller().send('新问题');
    final thread = await threadOf(conversationId);
    expect(thread.messages, hasLength(6));
    expect(thread.branch.map((message) => message.text), [
      '问题1',
      '回答1',
      '新问题',
      '新回答',
    ]);
    expect(thread.branch[2].parentId, first.currentMessageId);
    expect(
      fakeProvider.lastRequest!.messages.map(
        (message) => message.parts.whereType<ResolvedText>().single.text,
      ),
      ['问题1', '回答1', '新问题'],
    );
  });

  test('推理等级随模型能力下发，不支持推理时不带推理字段', () async {
    fakeProvider.streamFactory = () => Stream.fromIterable(textResponse('好'));

    await controller().send('你好');
    expect(fakeProvider.lastRequest!.reasoningEffort, ReasoningEffort.off);

    await container
        .read(modelSelectionProvider.notifier)
        .selectEffort(ReasoningEffort.medium);
    await container.read(modelSelectionProvider.future);

    await controller().send('再来一次');
    expect(fakeProvider.lastRequest!.reasoningEffort, ReasoningEffort.medium);

    // 换成未登记能力的模型：沿用宽松默认，推理等级仍统一下发。
    final repository = await container.read(
      providerProfileRepositoryProvider.future,
    );
    await repository.saveProfile(
      profile.copyWith(
        models: const [ProfileModel(id: 'model-b', enabled: true)],
        defaultModel: 'model-b',
      ),
    );
    await container
        .read(settingsStorageProvider)
        .writeLastModelSelection(profileId: profile.id, model: 'model-b');
    container.refresh(modelSelectionProvider);
    await container.read(modelSelectionProvider.future);
    await controller().send('未登记模型');
    expect(fakeProvider.lastRequest!.reasoningEffort, ReasoningEffort.medium);

    // 显式关闭推理的模型：不下发推理字段。
    await repository.saveProfile(
      profile.copyWith(
        models: const [
          ProfileModel(id: 'model-b', enabled: true, supportsReasoning: false),
        ],
        defaultModel: 'model-b',
      ),
    );
    await container
        .read(settingsStorageProvider)
        .writeLastModelSelection(profileId: profile.id, model: 'model-b');
    container.refresh(modelSelectionProvider);
    await container.read(modelSelectionProvider.future);

    await controller().send('再来');
    expect(fakeProvider.lastRequest!.reasoningEffort, ReasoningEffort.off);
  });

  test('发送后两条消息落库，流式内容累积成 Part 并最终完成', () async {
    final chunks = StreamController<ChatChunk>();
    fakeProvider.streamFactory = () => chunks.stream;

    const text = '你好，请介绍一下你自己，这句话超过二十个字了';
    final sendFuture = controller().send(text);
    await waitUntil(() => state().conversationId != null);

    expect(state().conversationId, isNotNull);
    expect(state().isGenerating, isTrue);
    final conversationId = state().conversationId!;

    // 会话标题取首条消息前 20 字。
    final conversations = await db.select(db.conversations).get();
    expect(conversations.single.title, '你好，请介绍一下你自己，这句话超过二十个字了');

    chunks.add(const PartStart(partId: 'text_0', kind: PartKind.text));
    chunks.add(const TextDelta(partId: 'text_0', text: '你好'));
    await Future<void>.delayed(const Duration(milliseconds: 200));
    chunks.add(const TextDelta(partId: 'text_0', text: '，我是'));
    await Future<void>.delayed(const Duration(milliseconds: 200));

    // 节流写库后可见流式中间内容，状态为 streaming。
    var thread = await threadOf(conversationId);
    expect(thread.branch, hasLength(2));
    expect(thread.branch.first.role, ChatRole.user);
    expect(thread.branch.first.text, text);
    expect(thread.branch.last.status, MessageStatus.streaming);
    expect(thread.branch.last.text, '你好，我是');

    chunks.add(const TextDelta(partId: 'text_0', text: '相月'));
    chunks.add(
      const PartEnd(
        partId: 'text_0',
        part: TextPart(text: '你好，我是相月'),
      ),
    );
    chunks.add(const ResponseEnd());
    await chunks.close();
    await sendFuture;

    thread = await threadOf(conversationId);
    final answer = thread.branch.last;
    expect(answer.text, '你好，我是相月');
    expect(answer.status, MessageStatus.completed);
    expect(answer.modelLabel, 'model-a');
    expect(state().isGenerating, isFalse);

    // 请求上下文只带当前分支的已完成消息（用户消息），不含空回答占位。
    final request = fakeProvider.lastRequest!;
    expect(request.modelId, 'model-a');
    expect(request.messages, hasLength(1));
    expect(request.messages.single.role, ChatRole.user);
    expect(
      request.messages.single.parts.whereType<ResolvedText>().single.text,
      text,
    );
  });

  test('思考与正文分通道累积，思考耗时单独记录', () async {
    fakeProvider.streamFactory = () => Stream.fromIterable([
      const PartStart(partId: 'reasoning_0', kind: PartKind.reasoning),
      const ReasoningDelta(partId: 'reasoning_0', text: '先想'),
      const ReasoningDelta(partId: 'reasoning_0', text: '一下'),
      const PartEnd(
        partId: 'reasoning_0',
        part: ReasoningPart(publicText: '先想一下'),
      ),
      const PartStart(partId: 'text_0', kind: PartKind.text),
      const TextDelta(partId: 'text_0', text: '答案'),
      const PartEnd(
        partId: 'text_0',
        part: TextPart(text: '答案'),
      ),
      ResponseEnd(),
    ]);

    await controller().send('你好');
    final thread = await threadOf(state().conversationId!);
    final answer = thread.branch.last;

    expect(answer.parts.whereType<ReasoningPart>().single.publicText, '先想一下');
    expect(answer.text, '答案');
    expect(answer.status, MessageStatus.completed);
    expect(answer.thinkingDurationMs, isNotNull);
  });

  test('停止保留已收内容并标记 cancelled，不继续追加迟到增量', () async {
    final chunks = StreamController<ChatChunk>();
    fakeProvider.streamFactory = () => chunks.stream;

    final sendFuture = controller().send('你好');
    await waitUntil(() => state().isGenerating);
    final conversationId = state().conversationId!;

    chunks.add(const PartStart(partId: 'text_0', kind: PartKind.text));
    chunks.add(const TextDelta(partId: 'text_0', text: '部分内容'));
    await Future<void>.delayed(const Duration(milliseconds: 200));

    controller().stop();
    await sendFuture;

    expect(state().isGenerating, isFalse);
    var thread = await threadOf(conversationId);
    expect(thread.branch.last.text, '部分内容');
    expect(thread.branch.last.status, MessageStatus.cancelled);

    // 迟到增量不再追加。
    chunks.add(const TextDelta(partId: 'text_0', text: '不该出现'));
    await Future<void>.delayed(const Duration(milliseconds: 200));
    thread = await threadOf(conversationId);
    expect(thread.branch.last.text, '部分内容');

    await chunks.close();
  });

  for (final sendHeaders in [false, true]) {
    test('真实 HTTP 停止断开连接并落库：${sendHeaders ? '空闲流' : '等待响应'}', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final ready = Completer<void>();
      final disconnected = Completer<void>();
      Socket? connection;
      StreamSubscription<List<int>>? socketEvents;
      final requests = server.listen((request) async {
        try {
          await request.drain<void>();
          if (sendHeaders) {
            request.response.headers.contentType = ContentType(
              'text',
              'event-stream',
            );
            request.response.headers.chunkedTransferEncoding = false;
            request.response.persistentConnection = false;
          }
          // 接管底层连接，观察客户端主动断开；服务端不结束响应。
          connection = await request.response.detachSocket(
            writeHeaders: sendHeaders,
          );
          socketEvents = connection!.listen(
            (_) {},
            onDone: disconnected.complete,
          );
          if (sendHeaders) {
            connection!.write(
              'data: {"choices":[{"delta":{"content":"partial"}}]}\n\n',
            );
            await connection!.flush();
          }
          ready.complete();
        } catch (error, stackTrace) {
          ready.completeError(error, stackTrace);
        }
      });
      CancelToken? requestCancellation;
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              requestCancellation = options.cancelToken;
              handler.next(options);
            },
          ),
        );
      final provider = OpenAiCompletionsProvider(
        profile: profile.copyWith(
          baseUrl: 'http://127.0.0.1:${server.port}/v1',
          requiresKey: false,
        ),
        apiKey: '',
        dio: dio,
      );
      fakeProvider.streamFactory = () =>
          provider.streamChat(fakeProvider.lastRequest!);

      final sending = controller().send('停止测试');
      try {
        await ready.future.timeout(const Duration(seconds: 5));
        if (sendHeaders) {
          await waitUntil(() => state().streamingParts.isNotEmpty);
        }
        controller().stop();
        await sending.timeout(
          const Duration(seconds: 2),
          onTimeout: () => fail('停止后发送流程未结束'),
        );
        expect(requestCancellation?.isCancelled, isTrue);
        await disconnected.future.timeout(
          const Duration(seconds: 2),
          onTimeout: () => fail('停止后底层连接未断开'),
        );

        final answer = (await threadOf(state().conversationId!)).branch.last;
        expect(answer.status, MessageStatus.cancelled);
        expect(answer.text, sendHeaders ? 'partial' : '');
        expect(state().isGenerating, isFalse);
      } finally {
        controller().stop();
        await sending.timeout(const Duration(seconds: 5));
        dio.close(force: true);
        await socketEvents?.cancel();
        connection?.destroy();
        await requests.cancel();
        await server.close(force: true);
      }
    });
  }

  test('流内错误与连接错误都让回答标记 failed 并显示安全文案', () async {
    fakeProvider.streamFactory = () => Stream<ChatChunk>.fromIterable([
      const PartStart(partId: 'text_0', kind: PartKind.text),
      const TextDelta(partId: 'text_0', text: '半句'),
      const ResponseError(
        error: ProviderError(ProviderErrorCategory.rateLimit, '请求过于频繁，请稍后再试'),
      ),
    ]);

    await controller().send('你好');
    var thread = await threadOf(state().conversationId!);
    var answer = thread.branch.last;
    expect(answer.status, MessageStatus.failed);
    expect(answer.text, contains('半句'));
    expect(answer.text, contains('请求过于频繁，请稍后再试'));

    // 连接层异常同样映射成失败回答，而不是空气泡。
    fakeProvider.streamFactory = () =>
        Stream<ChatChunk>.error(const ServerFailure('boom'));
    await controller().send('再来');
    thread = await threadOf(state().conversationId!);
    answer = thread.branch.last;
    expect(answer.status, MessageStatus.failed);
    expect(answer.text, contains('服务商暂时不可用'));
  });

  test('流空跑结束标记 failed 并给出空响应提示', () async {
    fakeProvider.streamFactory = () => const Stream<ChatChunk>.empty();

    await controller().send('你好');
    final thread = await threadOf(state().conversationId!);

    expect(thread.branch.last.status, MessageStatus.failed);
    expect(thread.branch.last.text, contains('空响应'));
    expect(state().isGenerating, isFalse);
  });

  test('未配置模型时 send 抛 Failure，不创建会话与消息', () async {
    await (db.delete(db.providerProfiles)).go();
    // 先让配置流把「已无服务商」推给派生选择，再发送。
    await waitUntil(() async {
      container.invalidate(modelSelectionProvider);
      return await container.read(modelSelectionProvider.future) == null;
    });
    await expectLater(
      controller()
          .send('你好')
          .then<void>(
            (_) {},
            onError: (Object e) {
              throw e;
            },
          ),
      throwsA(isA<UnknownFailure>()),
    );
    await pumpEventQueue();

    expect(await db.select(db.conversations).get(), isEmpty);
    expect(await db.select(db.messages).get(), isEmpty);
    expect(state().conversationId, isNull);
    expect(state().isGenerating, isFalse);
  });
}
