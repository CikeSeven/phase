import 'dart:async';
import 'dart:convert';
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
import 'package:phase/data/models/attachment.dart';
import 'package:phase/data/models/chat_chunk.dart';
import 'package:phase/data/models/chat_message.dart';
import 'package:phase/data/models/chat_request.dart';
import 'package:phase/data/models/message_part.dart';
import 'package:phase/data/models/model_selection.dart' as model;
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

  String? activeConversation() =>
      container.read(activeConversationProvider).conversationId;

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
      final conversationId = activeConversation()!;
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

        expect(activeConversation(), conversationId);
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

  test('重新生成：新回答挂在同一条用户消息下，旧回答保留', () async {
    fakeProvider.streamFactory = () =>
        Stream.fromIterable(textResponse('第一次回答'));
    await controller().send('问题');
    final conversationId = activeConversation()!;
    final before = await threadOf(conversationId);
    expect(before.branch.map((message) => message.text), ['问题', '第一次回答']);

    fakeProvider.streamFactory = () =>
        Stream.fromIterable(textResponse('第二次回答'));
    await controller().regenerate();

    final after = await threadOf(conversationId);
    // 当前分支只剩新回答；旧回答仍在消息树里（同级分支）。
    expect(after.branch.map((message) => message.text), ['问题', '第二次回答']);
    expect(after.messages, hasLength(3));
    expect(
      after.messages.where((message) => message.text == '第一次回答'),
      hasLength(1),
    );
    // 两次回答挂在同一条用户消息下。
    final parentId = after.branch.first.id;
    expect(after.branch.last.parentId, parentId);
    final old = after.messages.firstWhere((message) => message.text == '第一次回答');
    expect(old.parentId, parentId);
  });

  test('复制会话：副本保留全部消息与分支，原会话不变', () async {
    fakeProvider.streamFactory = () => Stream.fromIterable(textResponse('回答'));
    await controller().send('问题');
    final sourceId = activeConversation()!;
    final source = await threadOf(sourceId);

    final copyId = await controller().duplicateFrom(sourceId);
    expect(copyId, isNot(sourceId));
    expect(activeConversation(), copyId);

    final copy = await threadOf(copyId);
    expect(copy.conversation.title, '问题（副本）');
    expect(copy.messages, hasLength(2));
    expect(copy.branch.map((message) => message.text), ['问题', '回答']);
    // 副本里的消息 id 与父链都是新的，但指向关系一致。
    expect(copy.branch.last.id, isNot(source.branch.last.id));
    expect(copy.branch.last.parentId, copy.branch.first.id);

    // 原会话不受影响。
    final unchanged = await threadOf(sourceId);
    expect(unchanged.messages, hasLength(2));
    expect(unchanged.branch.last.id, source.branch.last.id);
  });

  test('复制带附件的会话后，删除原会话仍可用副本上下文继续发送', () async {
    fakeProvider.streamFactory = () => Stream.fromIterable(textResponse('回答'));
    final storage = await container.read(attachmentStorageProvider.future);
    final image = await storage.save(
      name: 'image.png',
      mimeType: 'image/png',
      kind: AttachmentKind.image,
      bytes: const [1, 2, 3],
    );
    final text = await storage.save(
      name: 'notes.txt',
      mimeType: 'text/plain',
      kind: AttachmentKind.text,
      bytes: utf8.encode('原始文本'),
    );
    final pdf = await storage.save(
      name: 'report.pdf',
      mimeType: 'application/pdf',
      kind: AttachmentKind.pdf,
      bytes: const [37, 80, 68, 70],
    );
    final extraction = await storage.saveExtractedText(pdf.id, 'PDF 抽取正文');
    await controller().send(
      '读取附件',
      attachments: [
        image,
        text,
        pdf.withExtraction(extractedTextPath: extraction),
      ],
    );
    final originalId = activeConversation()!;
    final copyId = await controller().duplicateFrom(originalId);
    final repository = await container.read(
      conversationRepositoryProvider.future,
    );
    await repository.deleteConversation(originalId);
    await controller().send('继续');

    expect(activeConversation(), copyId);
    final originalInput = fakeProvider.lastRequest!.messages.first.parts;
    expect(originalInput.whereType<ResolvedText>().map((part) => part.text), [
      '原始文本',
      'PDF 抽取正文',
      '读取附件',
    ]);
    final copiedImage = originalInput
        .whereType<ResolvedImage>()
        .single
        .attachment;
    expect(copiedImage.id, isNot(image.id));
    expect(copiedImage.conversationId, copyId);
    expect(await File(copiedImage.localPath).readAsBytes(), [1, 2, 3]);
    expect((await threadOf(copyId)).branch, hasLength(4));
  });

  test('文档附件用抽取文本参与请求，失败时如实告知', () async {
    fakeProvider.streamFactory = () => Stream.fromIterable(textResponse('好'));
    final storage = await container.read(attachmentStorageProvider.future);

    // 抽取成功的 PDF：请求里出现抽取文本，不出现原始二进制。
    final pdf = await storage.save(
      name: '报告.pdf',
      mimeType: 'application/pdf',
      kind: AttachmentKind.pdf,
      bytes: const [37, 80, 68, 70],
    );
    final extractedPath = await storage.saveExtractedText(pdf.id, '第一段：季度总结。');
    await controller().send(
      '看下这份文档',
      attachments: [pdf.withExtraction(extractedTextPath: extractedPath)],
    );
    // 请求消息里既有附件文本也有用户正文：拼起来看内容。
    String userText(ChatRequest request) => request.messages.last.parts
        .whereType<ResolvedText>()
        .map((part) => part.text)
        .join('\n');
    var request = fakeProvider.lastRequest!;
    expect(userText(request), contains('第一段：季度总结。'));
    expect(userText(request), contains('看下这份文档'));

    // 抽取失败的文档：请求里说明该附件没有文字，而不是默默丢掉。
    final scanned = await storage.save(
      name: '扫描件.pdf',
      mimeType: 'application/pdf',
      kind: AttachmentKind.pdf,
      bytes: const [37, 80, 68, 70],
    );
    await controller().send(
      '再看这份',
      attachments: [scanned.withExtraction(error: '没有可提取的文字（扫描件需要 OCR）')],
    );
    request = fakeProvider.lastRequest!;
    expect(userText(request), contains('扫描件需要 OCR'));

    // 抽取结果随附件落库。
    final repository = await container.read(
      conversationRepositoryProvider.future,
    );
    final stored = await repository.attachmentsFor(activeConversation()!);
    final savedPdf = stored.firstWhere((item) => item.id == pdf.id);
    expect(savedPdf.extractedTextPath, extractedPath);
    final savedScanned = stored.firstWhere((item) => item.id == scanned.id);
    expect(savedScanned.extractionError, contains('OCR'));
  });

  test('模型参数按配置下发，未设置时不下发', () async {
    fakeProvider.streamFactory = () => Stream.fromIterable(textResponse('好'));
    final repository = await container.read(
      providerProfileRepositoryProvider.future,
    );

    await repository.saveProfile(
      profile.copyWith(
        models: const [
          ProfileModel(
            id: 'model-a',
            enabled: true,
            supportsReasoning: true,
            temperature: 0.4,
            maxOutputTokens: 2048,
          ),
        ],
        defaultModel: 'model-a',
      ),
    );
    await controller().send('你好');
    var request = fakeProvider.lastRequest!;
    expect(request.temperature, 0.4);
    expect(request.maxOutputTokens, 2048);

    // 未设置参数：不下发，由服务端默认决定。保存后让选择重建再发送。
    await repository.saveProfile(
      profile.copyWith(
        models: const [
          ProfileModel(id: 'model-a', enabled: true, supportsReasoning: true),
        ],
        defaultModel: 'model-a',
      ),
    );
    // fake-async 下 Drift 的表变更不会推给界面/状态：显式重读配置与选择。
    await container.refresh(providerProfilesProvider.future);
    await container.refresh(modelSelectionProvider.future);
    await controller().send('再来');
    request = fakeProvider.lastRequest!;
    expect(request.temperature, isNull);
    expect(request.maxOutputTokens, isNull);
  });

  test('助手系统提示词随请求下发，新会话绑定该助手', () async {
    fakeProvider.streamFactory = () => Stream.fromIterable(textResponse('好'));
    final assistant = await controller().createAssistant(
      name: '代码助手',
      systemPrompt: '只回答与代码有关的问题。',
    );

    await controller().selectAssistant(assistant.id);
    await controller().send('你好');
    expect(
      fakeProvider.lastRequest!.systemPrompt,
      startsWith('只回答与代码有关的问题。\n'),
    );
    expect(fakeProvider.lastRequest!.systemPrompt, contains('list_apps'));

    final repository = await container.read(
      conversationRepositoryProvider.future,
    );
    final conversation = await repository.getThread(activeConversation()!);
    expect(conversation!.conversation.assistantId, assistant.id);
  });

  test('助手默认模型覆盖「最近使用」，未设置时回落', () async {
    fakeProvider.streamFactory = () => Stream.fromIterable(textResponse('好'));
    final repository = await container.read(
      providerProfileRepositoryProvider.future,
    );
    await repository.saveProfile(
      profile.copyWith(
        models: const [
          ProfileModel(id: 'model-a', enabled: true, supportsReasoning: true),
          ProfileModel(id: 'assistant-model', enabled: true),
        ],
      ),
    );
    final assistant = await controller().createAssistant(
      name: '指定模型助手',
      defaultModelSelection: model.ModelSelection(
        profileId: profile.id,
        modelId: 'assistant-model',
      ),
    );
    // 新会话使用该助手（列表里排在更前的内置助手此时不含默认模型）。
    await controller().selectAssistant(assistant.id);
    await controller().send('你好');
    expect(fakeProvider.lastRequest!.modelId, 'assistant-model');

    // 未设置默认模型的助手：回落到「最近使用」的模型。
    final fallback = await controller().createAssistant(name: '跟随助手');
    await controller().selectAssistant(fallback.id);
    await controller().send('再来');
    expect(fakeProvider.lastRequest!.modelId, 'model-a');
  });

  for (final beforeFirstSend in [true, false]) {
    test('显式选择覆盖助手默认值并随会话保存（发送前选择：$beforeFirstSend）', () async {
      fakeProvider.streamFactory = () => Stream.fromIterable(textResponse('好'));
      final profiles = await container.read(
        providerProfileRepositoryProvider.future,
      );
      final other = await profiles.createProfile(
        name: '另一个服务商',
        baseUrl: 'https://example.invalid/v1',
        models: const [ProfileModel(id: 'model-b', supportsReasoning: true)],
      );
      final assistant = await controller().createAssistant(
        name: '指定模型',
        defaultModelSelection: model.ModelSelection(
          profileId: profile.id,
          modelId: 'model-a',
          reasoningEffort: ReasoningEffort.medium,
        ),
      );
      await controller().selectAssistant(assistant.id);
      if (!beforeFirstSend) await controller().send('第一轮');
      await container
          .read(modelSelectionProvider.notifier)
          .select(other.id, 'model-b', effort: ReasoningEffort.high);
      if (beforeFirstSend) {
        expect(activeConversation(), isNull);
        expect(await db.select(db.conversations).get(), isEmpty);
      }
      final selected = (await container.read(modelSelectionProvider.future))!;
      expect(selected.profile.id, other.id);
      expect(selected.model, 'model-b');
      expect(selected.effort, ReasoningEffort.high);
      await controller().send('使用手动选择');
      expect(fakeProvider.lastRequest!.modelId, 'model-b');
      expect(fakeProvider.lastRequest!.reasoningEffort, ReasoningEffort.high);
      final id = activeConversation()!;
      final saved = (await threadOf(id)).conversation.modelSelectionOverride!;
      expect(saved.profileId, other.id);
      expect(saved.modelId, 'model-b');
      expect(saved.reasoningEffort, ReasoningEffort.high);

      controller().startNewConversation();
      await controller().selectAssistant(assistant.id);
      final defaultSelection = (await container.read(
        modelSelectionProvider.future,
      ))!;
      expect(defaultSelection.model, 'model-a');
      expect(defaultSelection.effort, ReasoningEffort.medium);
      await controller().send('独立会话');

      await controller().openConversation(id);
      await controller().send('重开原会话');
      expect(fakeProvider.lastRequest!.modelId, 'model-b');
      expect(fakeProvider.lastRequest!.reasoningEffort, ReasoningEffort.high);
      final copyId = await controller().duplicateFrom(id);
      await controller().send('副本');
      expect(activeConversation(), copyId);
      expect(fakeProvider.lastRequest!.modelId, 'model-b');
      expect(fakeProvider.lastRequest!.reasoningEffort, ReasoningEffort.high);
    });
  }

  test('单独修改推理等级不会切换模型或改写助手默认值', () async {
    fakeProvider.streamFactory = () => Stream.fromIterable(textResponse('好'));
    final assistant = await controller().createAssistant(
      name: '推理助手',
      defaultModelSelection: model.ModelSelection(
        profileId: profile.id,
        modelId: 'model-a',
        reasoningEffort: ReasoningEffort.medium,
      ),
    );
    await controller().selectAssistant(assistant.id);
    await container
        .read(modelSelectionProvider.notifier)
        .selectEffort(ReasoningEffort.off);
    await controller().send('关闭思考');
    final conversationId = activeConversation()!;
    expect(fakeProvider.lastRequest!.modelId, 'model-a');
    expect(fakeProvider.lastRequest!.reasoningEffort, ReasoningEffort.off);
    await controller().openConversation(conversationId);
    expect(
      (await container.read(modelSelectionProvider.future))!.effort,
      ReasoningEffort.off,
    );
    final unchanged = (await container.read(assistantsProvider.future))
        .singleWhere((item) => item.id == assistant.id);
    expect(
      unchanged.defaultModelSelection!.reasoningEffort,
      ReasoningEffort.medium,
    );
  });

  test('发送使用仓储当前分支，不把其他分支带入上下文', () async {
    fakeProvider.streamFactory = () => Stream.fromIterable(textResponse('回答1'));
    await controller().send('问题1');
    final conversationId = activeConversation()!;
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
      profile.copyWith(models: const [], defaultModel: 'model-b'),
    );
    await container.refresh(providerProfilesProvider.future);
    await container
        .read(modelSelectionProvider.notifier)
        .select(profile.id, 'model-b');
    await container.read(modelSelectionProvider.future);
    await controller().send('未登记模型');
    expect(fakeProvider.lastRequest!.modelId, 'model-b');
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
    await container.refresh(providerProfilesProvider.future);
    await container
        .read(modelSelectionProvider.notifier)
        .select(profile.id, 'model-b');
    await container.read(modelSelectionProvider.future);

    await controller().send('再来');
    expect(fakeProvider.lastRequest!.reasoningEffort, ReasoningEffort.off);
  });

  test('发送后两条消息落库，流式内容累积成 Part 并最终完成', () async {
    final chunks = StreamController<ChatChunk>();
    fakeProvider.streamFactory = () => chunks.stream;

    const text = '你好，请介绍一下你自己，这句话超过二十个字了';
    final sendFuture = controller().send(text);
    // 会话 id 在请求发出前就写好，状态可能还没进入生成中：等状态本身。
    await waitUntil(() => state().isGenerating);

    expect(activeConversation(), isNotNull);
    final conversationId = activeConversation()!;

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
    final thread = await threadOf(activeConversation()!);
    final answer = thread.branch.last;

    expect(answer.parts.whereType<ReasoningPart>().single.publicText, '先想一下');
    expect(answer.text, '答案');
    expect(answer.status, MessageStatus.completed);
    expect(answer.thinkingDurationMs, isNotNull);
    final reasoning = answer.parts.whereType<ReasoningPart>().single;
    expect(reasoning.durationMs, answer.thinkingDurationMs);
    expect(reasoning.startedAt, isNotNull);
  });

  test('多段思考各自计时并落库，结束后的正文等待不计入任一段', () async {
    final chunks = StreamController<ChatChunk>();
    fakeProvider.streamFactory = () => chunks.stream;
    final send = controller().send('逐段计时');
    await waitUntil(() => fakeProvider.lastRequest != null);
    chunks.add(const PartStart(partId: 'r0', kind: PartKind.reasoning));
    chunks.add(const ReasoningDelta(partId: 'r0', text: '第一段'));
    await waitUntil(
      () => state().streamingParts.whereType<ReasoningPart>().isNotEmpty,
    );
    final started = state().streamingParts
        .whereType<ReasoningPart>()
        .single
        .startedAt;
    expect(started, isNotNull);
    // 正文开始应结束第一段，无需等待协议在响应末尾补 PartEnd。
    chunks.add(const TextDelta(partId: 't0', text: '中间正文'));
    await waitUntil(
      () =>
          state().streamingParts.whereType<ReasoningPart>().single.durationMs !=
          null,
    );
    final firstDuration = state().streamingParts
        .whereType<ReasoningPart>()
        .single
        .durationMs!;
    expect(firstDuration, greaterThan(0));
    chunks.add(const ReasoningDelta(partId: 'r1', text: '第二段'));
    await waitUntil(
      () => state().streamingParts.whereType<ReasoningPart>().length == 2,
    );
    chunks.add(
      const PartEnd(
        partId: 'r1',
        part: ReasoningPart(publicText: '第二段'),
      ),
    );
    await waitUntil(
      () =>
          state().streamingParts.whereType<ReasoningPart>().last.durationMs !=
          null,
    );
    final secondDuration = state().streamingParts
        .whereType<ReasoningPart>()
        .last
        .durationMs!;
    await Future<void>.delayed(const Duration(milliseconds: 100));
    chunks.add(const TextDelta(partId: 't1', text: '最终正文'));
    chunks.add(const ResponseEnd());
    await chunks.close();
    await send;
    final message = (await threadOf(activeConversation()!)).branch.last;
    final parts = message.parts.whereType<ReasoningPart>().toList();
    expect(parts.map((part) => part.durationMs), [
      firstDuration,
      secondDuration,
    ]);
    expect(parts.first.startedAt, started);
    expect(message.thinkingDurationMs, firstDuration + secondDuration);
    expect(message.status, MessageStatus.completed);
  });

  for (final finish in ['tool', 'stop', 'error']) {
    test('公开思考在 $finish 边界结束计时并保留落库结果', () async {
      final chunks = StreamController<ChatChunk>();
      fakeProvider.streamFactory = () => chunks.stream;
      final send = controller().send('结束计时');
      await waitUntil(() => fakeProvider.lastRequest != null);
      chunks.add(const ReasoningDelta(partId: 'r0', text: '已收思考'));
      await waitUntil(
        () => state().streamingParts.whereType<ReasoningPart>().isNotEmpty,
      );
      int? durationAtBoundary;
      if (finish == 'tool') {
        chunks.add(const PartStart(partId: 'call', kind: PartKind.toolCall));
        await waitUntil(
          () =>
              state().streamingParts
                  .whereType<ReasoningPart>()
                  .single
                  .durationMs !=
              null,
        );
        durationAtBoundary = state().streamingParts
            .whereType<ReasoningPart>()
            .single
            .durationMs;
        await Future<void>.delayed(const Duration(milliseconds: 80));
        // 停止不执行只有部分参数的调用，工具生成时间不算思考。
        controller().stop();
      } else if (finish == 'stop') {
        controller().stop();
      } else {
        chunks.add(
          const ResponseError(
            error: ProviderError(ProviderErrorCategory.auth, 'fixture'),
          ),
        );
      }
      await send;
      await chunks.close();
      final message = (await threadOf(activeConversation()!)).branch.last;
      final reasoning = message.parts.whereType<ReasoningPart>().single;
      expect(reasoning.durationMs, greaterThan(0));
      expect(message.thinkingDurationMs, reasoning.durationMs);
      if (durationAtBoundary != null) {
        expect(reasoning.durationMs, durationAtBoundary);
      }
      expect(
        message.status,
        finish == 'error' ? MessageStatus.failed : MessageStatus.cancelled,
      );
    });
  }

  test('仅完成快照提供公开思考也记录耗时，隐藏推理不伪造计时', () async {
    fakeProvider.streamFactory = () => Stream.fromIterable(const [
      PartStart(partId: 'hidden', kind: PartKind.reasoning),
      PartEnd(
        partId: 'hidden',
        part: ReasoningPart(
          publicText: '',
          providerData: {'signature': 'fixture'},
        ),
      ),
      PartStart(partId: 'snapshot', kind: PartKind.reasoning),
      PartEnd(
        partId: 'snapshot',
        part: ReasoningPart(publicText: '公开摘要快照'),
      ),
      ResponseEnd(),
    ]);
    await controller().send('完成快照');
    final message = (await threadOf(activeConversation()!)).branch.last;
    final parts = message.parts.whereType<ReasoningPart>().toList();
    expect(parts.first.durationMs, isNull);
    expect(parts.first.startedAt, isNull);
    expect(parts.last.durationMs, isNotNull);
    expect(message.thinkingDurationMs, parts.last.durationMs);
  });

  test('停止保留已收内容并标记 cancelled，不继续追加迟到增量', () async {
    final chunks = StreamController<ChatChunk>();
    fakeProvider.streamFactory = () => chunks.stream;

    final sendFuture = controller().send('你好');
    await waitUntil(() => state().isGenerating);
    final conversationId = activeConversation()!;

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

        final answer = (await threadOf(activeConversation()!)).branch.last;
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
    var thread = await threadOf(activeConversation()!);
    var answer = thread.branch.last;
    expect(answer.status, MessageStatus.failed);
    expect(answer.text, contains('半句'));
    expect(answer.text, contains('请求过于频繁，请稍后再试'));

    // 连接层异常同样映射成失败回答，而不是空气泡。
    fakeProvider.streamFactory = () =>
        Stream<ChatChunk>.error(const ServerFailure('boom'));
    await controller().send('再来');
    thread = await threadOf(activeConversation()!);
    answer = thread.branch.last;
    expect(answer.status, MessageStatus.failed);
    expect(answer.text, contains('服务商暂时不可用'));
  });

  test('流空跑结束标记 failed 并给出空响应提示', () async {
    fakeProvider.streamFactory = () => const Stream<ChatChunk>.empty();

    await controller().send('你好');
    final thread = await threadOf(activeConversation()!);

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
    expect(activeConversation(), isNull);
    expect(state().isGenerating, isFalse);
  });
}
