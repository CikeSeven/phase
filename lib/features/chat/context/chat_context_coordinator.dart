import '../../../core/error/failure.dart';
import '../../../core/utils/logger.dart';
import '../../../data/datasources/local/secure_key_storage.dart';
import '../../../data/models/agent_run.dart';
import '../../../data/models/attachment.dart';
import '../../../data/models/chat_message.dart';
import '../../../data/models/chat_request.dart';
import '../../../data/models/reasoning_effort.dart';
import '../../../data/models/provider_profile.dart';
import '../../../data/repositories/agent_context_repository.dart';
import '../../../data/repositories/agent_run_repository.dart';
import '../../../data/repositories/conversation_repository.dart';
import '../../../data/repositories/model_request_repository.dart';
import '../../../providers/ai_provider.dart';
import '../../tools/tool.dart';
import '../chat_model_selection.dart';
import '../runtime/chat_run_factory.dart';
import '../runtime/chat_run_update.dart';
import 'compaction_coordinator.dart';
import 'context_builder.dart';
import 'context_configuration.dart';
import 'history_resolver.dart';

/// 上下文接线不持有页面状态，也不另建计量、摘要或历史事实来源。
class ChatContextCoordinator {
  const ChatContextCoordinator({
    required this.conversations,
    required this.runs,
    required this.summaries,
    required this.requests,
    required this.keys,
    required this.buildProvider,
  });
  final ConversationRepository conversations;
  final AgentRunRepository runs;
  final AgentContextRepository summaries;
  final ModelRequestRepository requests;
  final SecureKeyStorage keys;
  final AiProvider Function(ProviderProfile, String) buildProvider;

  Future<Map<String, Attachment>> attachments(String conversationId) async => {
    for (final attachment in await conversations.availableAttachmentsFor(
      conversationId,
    ))
      attachment.id: attachment,
  };

  Future<List<ResolvedMessage>> resolve({
    required List<ChatMessage> messages,
    required Map<String, Attachment> attachments,
    required ChatModelSelection selection,
    required ToolRegistry registry,
  }) => HistoryResolver(
    repository: conversations,
    runs: runs,
    profile: selection.profile,
    registry: registry,
  ).resolve(messages, attachments, currentModelId: selection.model);

  Future<PreparedContext> prepare({
    required ConversationThread thread,
    required ChatModelSelection selection,
    required String? assistantId,
    required ChatRunPreview preview,
  }) async {
    final configuration = preview.configuration;
    final resolver = HistoryResolver(
      repository: conversations,
      runs: runs,
      profile: selection.profile,
      registry: preview.catalog.registry,
    );
    final resolved = await resolver.resolve(
      thread.branch,
      await attachments(thread.conversation.id),
      currentModelId: selection.model,
    );
    final messages = previewRuntimeContext(
      resolved,
      thread.branch,
      configuration,
    );
    return PreparedContext(
      assistantId: assistantId,
      conversationId: thread.conversation.id,
      branchHeadId: thread.currentMessageId!,
      profile: selection.profile,
      configuration: configuration,
      protectedIds: {
        ?messages
            .where((m) => m.role == ChatRole.user)
            .lastOrNull
            ?.sourceMessageId,
      },
      reloadMessages: () async {
        final latest = await conversations.getThread(thread.conversation.id);
        if (latest == null) return const [];
        final resolved = await resolver.resolve(
          latest.branch,
          await attachments(thread.conversation.id),
          currentModelId: selection.model,
        );
        return previewRuntimeContext(resolved, latest.branch, configuration);
      },
      request: ChatRequest(
        modelId: selection.model,
        messages: messages,
        systemPrompt: contextSystemPrompt(configuration),
        tools: preview.catalog.definitions,
        reasoningEffort: selection.supportsReasoning
            ? selection.effort
            : ReasoningEffort.off,
        temperature: configuration.modelSelection.temperature,
        maxOutputTokens: configuration.modelSelection.maxOutputTokens,
      ),
    );
  }

  Future<ContextBuild> _preparedBuild(
    PreparedContext prepared,
    RunCancellation cancellation,
    AiProvider provider, {
    required bool measureOnly,
  }) => CompactionCoordinator(summaries: summaries, requests: requests).build(
    conversationId: prepared.conversationId,
    runId: null,
    branchHeadId: prepared.branchHeadId,
    profile: prepared.profile,
    provider: provider,
    request: prepared.request,
    cancellation: cancellation,
    protectedIds: prepared.protectedIds,
    canReadHistory: prepared.canReadHistory,
    canReadHistoryNow: () async => prepared.canReadHistory,
    reloadMessages: prepared.reloadMessages,
    contextWindow: prepared.configuration.contextWindow,
    windowSource: prepared.configuration.resolvedWindowSource,
    catalogMaxOutputTokens: prepared.configuration.catalogMaxOutputTokens,
    policy: prepared.configuration.contextPolicy,
    force: !measureOnly,
    measureOnly: measureOnly,
  );

  Future<ContextBuild> measure(
    PreparedContext prepared,
    RunCancellation cancellation,
  ) => _preparedBuild(
    prepared,
    cancellation,
    buildProvider(prepared.profile, ''),
    measureOnly: true,
  );

  Future<ContextBuild> compact(
    PreparedContext prepared,
    RunCancellation cancellation,
  ) async {
    final key = prepared.profile.requiresKey
        ? await keys.read(prepared.profile.id) ?? ''
        : '';
    return _preparedBuild(
      prepared,
      cancellation,
      buildProvider(prepared.profile, key),
      measureOnly: false,
    );
  }

  Future<ContextBuild> buildForRun({
    required AgentRun run,
    required ChatModelSelection selection,
    required ToolRegistry registry,
    required List<ToolDefinition> tools,
    required AiProvider provider,
    required List<ResolvedMessage> messages,
    required Map<String, Attachment> attachments,
    required RunCancellation cancellation,
    bool force = false,
    bool measureOnly = false,
    void Function(bool)? onSummarizing,
  }) async {
    final config = run.configuration;
    return CompactionCoordinator(
      summaries: summaries,
      requests: requests,
    ).build(
      conversationId: run.conversationId,
      runId: run.id,
      branchHeadId: (await conversations.getThread(run.conversationId))!
          .currentMessageId!,
      profile: selection.profile,
      provider: provider,
      request: ChatRequest(
        modelId: selection.model,
        messages: messages,
        systemPrompt: contextSystemPrompt(config),
        tools: tools,
        reasoningEffort: config.supportsReasoning
            ? config.modelSelection.reasoningEffort
            : ReasoningEffort.off,
        temperature: config.modelSelection.temperature,
        maxOutputTokens: config.modelSelection.maxOutputTokens,
      ),
      cancellation: cancellation,
      protectedIds: {
        run.inputMessageId,
        ?messages
            .where((m) => m.role == ChatRole.user)
            .lastOrNull
            ?.sourceMessageId,
      },
      canReadHistory: tools.any((tool) => tool.name == 'read_history'),
      canReadHistoryNow: () async =>
          tools.any((tool) => tool.name == 'read_history'),
      reloadMessages: () async {
        final thread = await conversations.getThread(run.conversationId);
        return thread == null
            ? const []
            : resolve(
                messages: thread.branch,
                attachments: attachments,
                selection: selection,
                registry: registry,
              );
      },
      contextWindow: config.contextWindow,
      windowSource: config.resolvedWindowSource,
      catalogMaxOutputTokens: config.catalogMaxOutputTokens,
      policy: config.contextPolicy,
      force: force,
      measureOnly: measureOnly,
      onSummarizing: onSummarizing,
    );
  }

  /// 结果收口后仅刷新展示；不触发摘要、准入或新的 API 请求。
  Future<void> refreshForRun({
    required AgentRun run,
    required ChatModelSelection selection,
    required ToolRegistry registry,
    required List<ToolDefinition> tools,
    required Map<String, Attachment> attachments,
    required RunCancellation cancellation,
    required ChatRunObserver observe,
  }) async {
    if (cancellation.isCancelled) return;
    try {
      final thread = await conversations.getThread(run.conversationId);
      if (thread == null || cancellation.isCancelled) return;
      final messages = await resolve(
        messages: thread.branch,
        attachments: attachments,
        selection: selection,
        registry: registry,
      );
      if (cancellation.isCancelled) return;
      final context = await buildForRun(
        run: run,
        selection: selection,
        registry: registry,
        tools: tools,
        provider: buildProvider(selection.profile, ''),
        messages: messages,
        attachments: attachments,
        cancellation: cancellation,
        measureOnly: true,
      );
      if (!cancellation.isCancelled) {
        observe(ChatContextMeasured(run.id, run.conversationId, context));
      }
    } on StorageFailure {
      rethrow;
    } catch (_) {
      AppLogger.warning('更新上下文占用失败，保留上次显示');
    }
  }
}
