import 'dart:async';
import 'dart:io';

import 'package:phase/data/repositories/workspace_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:phase/core/error/failure.dart';
import 'package:phase/data/datasources/local/app_database.dart';
import 'package:phase/data/datasources/local/secure_key_storage.dart';
import 'package:phase/data/models/agent_run.dart';
import 'package:phase/data/models/api_protocol.dart';
import 'package:phase/data/models/assistant.dart';
import 'package:phase/data/models/attachment.dart';
import 'package:phase/data/models/chat_message.dart';
import 'package:phase/data/models/message_part.dart';
import 'package:phase/data/models/model_selection.dart';
import 'package:phase/data/models/profile_model.dart';
import 'package:phase/data/models/reasoning_effort.dart';
import 'package:phase/data/models/tool_call_record.dart';
import 'package:phase/data/models/tool_policy.dart';
import 'package:phase/data/repositories/agent_run_repository.dart';
import 'package:phase/data/repositories/assistant_repository.dart';
import 'package:phase/data/repositories/conversation_repository.dart';
import 'package:phase/data/repositories/provider_profile_repository.dart';
import 'package:phase/data/repositories/tool_call_repository.dart';

import '../../support/fake_secure_storage.dart';

/// 仓储行为：会话分支、附件归属、运行与工具状态流转、服务商模型合并。
void main() {
  late Directory tempDir;
  late AppDatabase db;
  late ConversationRepository conversations;
  late AgentRunRepository runs;
  late ToolCallRepository toolCalls;
  late AssistantRepository assistants;
  late ProviderProfileRepository providers;

  const hexKey =
      '00112233445566778899aabbccddeeff'
      '00112233445566778899aabbccddeeff';

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('phase_repos');
    db = openAppDatabase(
      path: p.join(tempDir.path, 'phase.sqlite'),
      hexKey: hexKey,
    );
    conversations = ConversationRepository(
      db,
      workspaces: WorkspaceRepository(db, tempDir),
    );
    runs = AgentRunRepository(db);
    toolCalls = ToolCallRepository(db);
    assistants = AssistantRepository(db);
    providers = ProviderProfileRepository(
      db,
      SecureKeyStorage(FakeSecureStorage()),
    );
  });

  tearDown(() async {
    await db.close();
    tempDir.deleteSync(recursive: true);
  });

  ChatMessage message({
    required String id,
    required String conversationId,
    required ChatRole role,
    String? parentId,
    String? runId,
    List<MessagePart> parts = const [],
    MessageStatus status = MessageStatus.completed,
  }) {
    return ChatMessage(
      id: id,
      conversationId: conversationId,
      parentId: parentId,
      runId: runId,
      role: role,
      status: status,
      parts: parts,
      createdAt: DateTime.now(),
    );
  }

  test('会话创建、消息追加与分支还原', () async {
    final conversation = await conversations.createConversation(title: '新会话');
    expect(conversation.currentMessageId, isNull);

    final first = message(
      id: 'm1',
      conversationId: conversation.id,
      role: ChatRole.user,
      parts: const [TextPart(text: '帮我读一下这份文档')],
    );
    await conversations.appendMessage(first, updateTitle: true);

    final answer = message(
      id: 'm2',
      conversationId: conversation.id,
      role: ChatRole.assistant,
      parentId: 'm1',
      parts: const [TextPart(text: '好的')],
    );
    await conversations.appendMessage(answer);

    final thread = await conversations
        .watchThread(conversation.id)
        .firstWhere((value) => value != null);
    expect(thread!.branch.map((m) => m.id), ['m1', 'm2']);
    expect(thread.currentMessageId, 'm2');
    // 首条用户消息成为会话标题。
    expect(thread.conversation.title, '帮我读一下这份文档');
  });

  test('会话读取与持续订阅区分空会话、分支切换和删除', () async {
    final conversation = await conversations.createConversation();
    expect(await conversations.getThread('missing'), isNull);
    expect((await conversations.getThread(conversation.id))!.branch, isEmpty);
    final updates = StreamIterator(conversations.watchThread(conversation.id));
    Future<ConversationThread?> nextThread() async {
      expect(
        await updates.moveNext().timeout(const Duration(seconds: 5)),
        isTrue,
      );
      return updates.current;
    }

    try {
      expect((await nextThread())!.branch, isEmpty);
      await conversations.appendMessage(
        message(id: 'm1', conversationId: conversation.id, role: ChatRole.user),
      );
      expect((await nextThread())!.branch.single.id, 'm1');
      await conversations.appendMessage(
        message(
          id: 'm2',
          conversationId: conversation.id,
          role: ChatRole.assistant,
          parentId: 'm1',
        ),
      );
      expect((await nextThread())!.currentMessageId, 'm2');

      await conversations.setCurrentMessage(conversation.id, 'm1');
      final branch = (await nextThread())!;
      expect(branch.branch.single.id, 'm1');
      expect(branch.messages, hasLength(2));
      expect(
        (await conversations.getThread(conversation.id))!.currentMessageId,
        'm1',
      );

      await conversations.deleteConversation(conversation.id);
      expect(await nextThread(), isNull);
      expect(await conversations.getThread(conversation.id), isNull);
    } finally {
      await updates.cancel();
    }
  });

  for (final status in [
    MessageStatus.completed,
    MessageStatus.cancelled,
    MessageStatus.failed,
  ]) {
    test('同一订阅收到消息增量与终态：${status.name}', () async {
      final conversation = await conversations.createConversation();
      await conversations.appendMessage(
        message(
          id: 'answer',
          conversationId: conversation.id,
          role: ChatRole.assistant,
          status: MessageStatus.streaming,
        ),
      );
      final updates = StreamIterator(
        conversations.watchThread(conversation.id),
      );
      Future<ChatMessage> nextMessage() async {
        expect(
          await updates.moveNext().timeout(const Duration(seconds: 5)),
          isTrue,
        );
        return updates.current!.branch.last;
      }

      try {
        expect((await nextMessage()).text, isEmpty);
        await conversations.updateMessage(
          messageId: 'answer',
          parts: const [TextPart(text: '部分内容')],
          status: MessageStatus.streaming,
        );
        final streaming = await nextMessage();
        expect(streaming.text, '部分内容');
        expect(streaming.status, MessageStatus.streaming);

        await conversations.updateMessage(
          messageId: 'answer',
          parts: const [TextPart(text: '最终内容')],
          status: status,
        );
        final finished = await nextMessage();
        expect(finished.text, '最终内容');
        expect(finished.status, status);
        expect(
          (await conversations.getThread(conversation.id))!.branch.last.status,
          status,
        );
      } finally {
        await updates.cancel();
      }
    });
  }

  test('重新生成：新回答挂到同一父节点，旧回答保留在消息树', () async {
    final conversation = await conversations.createConversation();
    await conversations.appendMessage(
      message(
        id: 'm1',
        conversationId: conversation.id,
        role: ChatRole.user,
        parts: const [TextPart(text: '你好')],
      ),
    );
    await conversations.appendMessage(
      message(
        id: 'm2',
        conversationId: conversation.id,
        role: ChatRole.assistant,
        parentId: 'm1',
        parts: const [TextPart(text: '第一次回答')],
      ),
    );
    // 重新生成：把指针移回用户消息，再追加一条同级回答。
    await conversations.setCurrentMessage(conversation.id, 'm1');
    await conversations.appendMessage(
      message(
        id: 'm3',
        conversationId: conversation.id,
        role: ChatRole.assistant,
        parentId: 'm1',
        parts: const [TextPart(text: '第二次回答')],
      ),
    );

    final thread = await conversations
        .watchThread(conversation.id)
        .firstWhere((value) => value != null);
    expect(thread!.branch.map((m) => m.id), ['m1', 'm3']);
    // 旧回答仍在消息树里，没有被删除或覆盖。
    expect(thread.messages.map((m) => m.id), containsAll(['m1', 'm2', 'm3']));
  });

  test('附件按会话归属，删除会话后可查询产物引用', () async {
    final conversation = await conversations.createConversation();
    final artifact = Attachment(
      id: 'a1',
      conversationId: conversation.id,
      kind: AttachmentKind.artifact,
      name: '摘要.md',
      mimeType: 'text/markdown',
      size: 128,
      localPath: p.join(tempDir.path, 'summary.md'),
      createdAt: DateTime.now(),
    );
    await conversations.saveAttachment(artifact);
    expect(
      (await conversations.attachmentsFor(conversation.id)).map((a) => a.id),
      ['a1'],
    );

    await conversations.deleteConversation(conversation.id);
    expect(await conversations.attachmentsFor(conversation.id), isEmpty);
  });

  test('运行从创建到结束的计数与终态', () async {
    final conversation = await conversations.createConversation();
    await conversations.appendMessage(
      message(
        id: 'm1',
        conversationId: conversation.id,
        role: ChatRole.user,
        parts: const [TextPart(text: '跑一下')],
      ),
    );
    final run = AgentRun(
      id: 'r1',
      conversationId: conversation.id,
      inputMessageId: 'm1',
      configuration: RunConfiguration(
        connection: const RunConnection(
          profileId: 'p1',
          protocol: 'openaiCompletions',
          baseUrl: 'https://example.com/v1',
          requiresKey: true,
        ),
        modelSelection: const ModelSelection(
          profileId: 'p1',
          modelId: 'gpt-x',
          reasoningEffort: ReasoningEffort.medium,
        ),
        systemPrompt: '你是助手',
      ),
      createdAt: DateTime.now(),
    );
    await runs.create(run);

    await runs.beginTurn('r1');
    await runs.countModelAttempt('r1');
    await runs.awaitConfirmation('r1', 'c1');
    final awaiting = await runs.getById('r1');
    expect(awaiting!.status, RunStatus.awaitingConfirmation);
    expect(awaiting.activeToolCallId, 'c1');
    expect(awaiting.turnCount, 1);
    expect(awaiting.modelAttemptCount, 1);

    final finished = await runs.finish(
      'r1',
      status: RunStatus.completed,
      finishReason: RunFinishReason.completed,
      currentMessageId: 'm1',
      usage: const TokenUsage(inputTokens: 10, outputTokens: 20),
    );
    expect(finished.status, RunStatus.completed);
    expect(finished.activeToolCallId, isNull);
    expect(finished.usage?.inputTokens, 10);
    expect(await runs.unfinished(), isEmpty);
  });

  test('工具记录：确认后执行，结果与拒绝各自落库', () async {
    final conversation = await conversations.createConversation();
    await conversations.appendMessage(
      message(
        id: 'm1',
        conversationId: conversation.id,
        role: ChatRole.user,
        parts: const [TextPart(text: '写个文件')],
      ),
    );
    await runs.create(
      AgentRun(
        id: 'r1',
        conversationId: conversation.id,
        inputMessageId: 'm1',
        configuration: RunConfiguration(
          connection: const RunConnection(
            profileId: 'p1',
            protocol: 'openaiCompletions',
            baseUrl: 'https://example.com/v1',
            requiresKey: true,
          ),
          modelSelection: const ModelSelection(
            profileId: 'p1',
            modelId: 'gpt-x',
          ),
          systemPrompt: '',
        ),
        createdAt: DateTime.now(),
      ),
    );

    await toolCalls.create(
      ToolCallRecord(
        id: 'c1',
        runId: 'r1',
        assistantMessageId: 'm1',
        toolName: 'write_file',
        arguments: const {'path': 'a.md', 'content': 'hi'},
        channel: ExecutionChannel.app,
        defaultPolicy: ToolPolicy.ask,
        createdAt: DateTime.now(),
      ),
    );

    final awaiting = await toolCalls.requestConfirmation('c1');
    expect(awaiting.status, ToolCallStatus.awaitingConfirmation);
    expect(
      awaiting.confirmationExpiresAt!.difference(
        awaiting.confirmationRequestedAt!,
      ),
      ToolCallRepository.confirmationTimeout,
    );

    await toolCalls.recordDecision('c1', ToolDecision.approved);
    await toolCalls.markExecuting('c1');
    final done = await toolCalls.markSucceeded(
      'c1',
      result: '已写入 a.md',
      artifacts: ['a2'],
    );
    expect(done.status, ToolCallStatus.succeeded);
    expect(done.artifacts, ['a2']);
    expect((await toolCalls.getByRun('r1')).single.id, 'c1');
  });

  test('工具失败保留原参数和已知响应，不建立人工核验状态', () async {
    final conversation = await conversations.createConversation();
    await conversations.appendMessage(
      message(id: 'm1', conversationId: conversation.id, role: ChatRole.user),
    );
    await runs.create(
      AgentRun(
        id: 'r1',
        conversationId: conversation.id,
        inputMessageId: 'm1',
        configuration: RunConfiguration(
          connection: const RunConnection(
            profileId: 'p1',
            protocol: 'openaiCompletions',
            baseUrl: 'https://example.com/v1',
            requiresKey: true,
          ),
          modelSelection: const ModelSelection(
            profileId: 'p1',
            modelId: 'gpt-x',
          ),
          systemPrompt: '',
        ),
        createdAt: DateTime.now(),
      ),
    );
    await toolCalls.create(
      ToolCallRecord(
        id: 'c1',
        runId: 'r1',
        assistantMessageId: 'm1',
        toolName: 'click_node',
        arguments: const {'nodeId': 'n3'},
        channel: ExecutionChannel.accessibility,
        defaultPolicy: ToolPolicy.ask,
        createdAt: DateTime.now(),
      ),
    );
    await toolCalls.markExecuting('c1');
    final failed = await toolCalls.markFailed(
      'c1',
      errorCode: 'timeout',
      result: '请求超时',
    );
    expect(failed.status, ToolCallStatus.failed);
    expect(failed.result, '请求超时');
    expect(failed.arguments['nodeId'], 'n3');
  });

  test('默认相月使用固定身份，重复初始化保留编辑，改名后仍不可删除', () async {
    await assistants.save(
      Assistant(
        id: 'custom-assistant',
        name: '相月',
        systemPrompt: '',
        createdAt: DateTime(2026),
      ),
    );
    final first = await assistants.ensureDefault();
    expect(first.id, defaultAssistantId);
    expect(first.name, '相月');
    await assistants.save(
      first.copyWith(name: '我的助手', systemPrompt: '保留修改后的提示词'),
    );
    final second = await assistants.ensureDefault();
    expect(second.id, first.id);
    expect(second.name, '我的助手');
    expect(second.systemPrompt, '保留修改后的提示词');
    expect(
      (await assistants.getAssistants()).map((assistant) => assistant.id),
      [defaultAssistantId, 'custom-assistant'],
    );
    expect(
      (await assistants.watchAssistants().first).first.id,
      defaultAssistantId,
    );

    final conversation = await conversations.createConversation(
      assistantId: first.id,
    );
    await expectLater(
      assistants.delete(first.id),
      throwsA(isA<OperationFailure>()),
    );
    expect((await assistants.getById(first.id))!.name, '我的助手');
    final thread = await conversations.getThread(conversation.id);
    expect(thread!.conversation.assistantId, first.id);
  });

  test('自建同名相月可删除，已有会话保留并解除绑定', () async {
    await assistants.ensureDefault();
    final custom = await assistants.save(
      Assistant(
        id: 'custom-assistant',
        name: '相月',
        systemPrompt: '',
        createdAt: DateTime(2026),
      ),
    );
    final conversation = await conversations.createConversation(
      assistantId: custom.id,
    );
    await assistants.delete(custom.id);

    final thread = await conversations
        .watchThread(conversation.id)
        .firstWhere((value) => value != null);
    expect(thread!.conversation.assistantId, isNull);
    expect(await assistants.getById(custom.id), isNull);
    expect((await assistants.getAssistants()).single.id, defaultAssistantId);
  });

  test('工具策略：deny 的工具不开放，ask 用默认策略', () async {
    final assistant = await assistants.save(
      Assistant(
        id: 'as1',
        name: '执行助手',
        systemPrompt: '',
        toolPolicy: const ToolPolicyConfig(
          policies: {
            'write_file': ToolPolicy.ask,
            applicationOperationsPolicyKey: ToolPolicy.allow,
            'shell': ToolPolicy.deny,
          },
        ),
        createdAt: DateTime.now(),
      ),
    );
    expect(assistant.toolPolicy.enabledTools, {
      'write_file',
      'install_packages',
      ...applicationOperationTools,
    });
    expect(assistant.toolPolicy.overrides, {
      'write_file': ToolPolicy.ask,
      applicationOperationsPolicyKey: ToolPolicy.allow,
      'shell': ToolPolicy.deny,
      'install_packages': ToolPolicy.ask,
    });
  });

  test('服务商模型按 id 合并，手动能力设置优先', () async {
    final created = await providers.createProfile(
      name: '深度求索',
      baseUrl: 'https://api.deepseek.com',
      protocol: ApiProtocol.openaiCompletions,
    );
    final withModels = await providers.saveProfile(
      created.copyWith(
        models: const [
          ProfileModel(
            id: 'deepseek-chat',
            supportsReasoning: false,
            supportsTools: true,
            contextWindow: 64000,
          ),
        ],
      ),
    );
    expect(withModels.models.single.supportsTools, isTrue);

    // 重新获取模型列表：已有能力保持不变，新模型使用默认能力。
    final stored = await providers.getProfile(withModels.id);
    final merged = providers.mergeModels(stored!.models, const [
      ProfileModel(id: 'deepseek-chat', displayName: 'DeepSeek Chat'),
      ProfileModel(id: 'deepseek-reasoner'),
    ]);
    expect(merged.map((m) => m.id), ['deepseek-chat', 'deepseek-reasoner']);
    expect(merged.first.supportsTools, isTrue);
    expect(merged.first.contextWindow, 64000);
    expect(merged.first.displayName, 'DeepSeek Chat');
    expect(merged.first.enabled, isTrue);
  });

  test('删除服务商级联删除模型，并清除对应 Key', () async {
    final profile = await providers.createProfile(
      name: '临时',
      baseUrl: 'https://example.com/v1',
    );
    await providers.saveProfile(
      profile.copyWith(models: const [ProfileModel(id: 'm1')]),
    );
    await providers.writeApiKey(profile.id, 'sk-test');
    expect(await providers.readApiKey(profile.id), 'sk-test');

    await providers.deleteProfile(profile.id);
    expect(await providers.getProfile(profile.id), isNull);
    expect(await providers.readApiKey(profile.id), isNull);
    expect(await db.select(db.models).get(), isEmpty);
  });
}
