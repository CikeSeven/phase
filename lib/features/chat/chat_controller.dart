import 'context/history_resolver.dart';
import 'context/context_configuration.dart';
import 'context/compaction_coordinator.dart';
import 'context/read_history_tool.dart';
import '../../../data/models/model_request_record.dart';
import '../../../data/models/model_catalog.dart';
import '../../../data/datasources/local/model_catalog_cache.dart';
import '../../../data/repositories/model_request_repository.dart';
import 'context/context_meter.dart';
import '../../data/models/token_usage.dart';
import '../../../data/models/agent_plan.dart';
import '../../../data/models/memory_entry.dart';
import '../../../data/repositories/plan_repository.dart';
import '../../../data/repositories/memory_repository.dart';
import '../../../data/repositories/agent_context_repository.dart';
import '../memory/memory_tools.dart';
import 'planning/planning_tools.dart';
import 'context/context_builder.dart';
import '../execution/wait_for_user_tool.dart';
import '../tools/tool_presentation.dart';
import '../../../data/repositories/workspace_repository.dart';
import '../workspace/workspace_files.dart';
import '../workspace/shell_tool.dart';
import '../workspace/install_tool.dart';
import '../workspace/prepare_skill_tool.dart';
import '../workspace/process_driver.dart';
import '../execution/execution_api.g.dart';
import '../execution/task_activity.dart';

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/error/failure.dart';
import '../../../core/error/provider_error.dart';
import '../../../core/utils/id.dart';
import '../../../core/utils/logger.dart';
import '../../../data/datasources/local/artifact_storage.dart';
import '../../../data/datasources/local/attachment_storage.dart';
import '../../../data/datasources/local/secure_key_storage.dart';
import '../../../data/models/agent_run.dart';
import '../../../data/models/assistant.dart';
import '../../../data/models/attachment.dart';
import '../../../data/models/chat_chunk.dart';
import '../../../data/models/chat_message.dart';
import '../../../data/models/chat_request.dart';
import '../../../data/models/conversation.dart';
import '../../../data/models/message_part.dart';
import '../../../data/models/model_selection.dart' as model;
import '../../../data/models/reasoning_effort.dart';
import '../../../data/models/tool_call_record.dart';
import '../../../data/models/tool_policy.dart';
import '../../../data/models/tool_source.dart';
import '../../../data/repositories/mcp_server_repository.dart';
import '../mcp/mcp_connections.dart';
import '../mcp/mcp_runtime.dart';
import '../../../data/models/api_protocol.dart';
import '../../../data/models/profile_model.dart';
import '../../../data/models/skill_installation.dart';
import '../../../data/models/provider_profile.dart';
import '../../../data/repositories/agent_run_repository.dart';
import '../../../data/repositories/assistant_repository.dart';
import '../../../data/repositories/conversation_repository.dart';
import '../../../data/repositories/tool_call_repository.dart';
import '../../../providers/ai_provider.dart';
import '../../../providers/dio_failure_mapper.dart';
import '../../../providers/provider_factory.dart';
import '../tools/agent_loop.dart';
import '../skills/read_skill_tool.dart';
import '../../../data/repositories/skill_repository.dart';
import '../tools/http_transport.dart';
import '../tools/run_recovery_controller.dart';
import '../tools/tool.dart';
import '../tools/tool_executor.dart';
import '../tools/tool_registry.dart';
import '../execution/execution_controller.dart';
import '../../../data/datasources/local/settings_storage.dart';
import '../execution/channel_driver.dart';
import 'model_selection.dart';
import 'model_retry.dart';

part 'chat_controller.g.dart';

/// 聊天页状态：当前会话、附件索引与流式中的内容块。
///
/// 持久化消息以 repository 的 watch 流为准；[streamingParts] 只服务
/// 流式期间尚未落库的最后一条回答。
class ChatState {
  const ChatState({
    this.streamingParts = const [],
    this.attachments = const {},
    this.isGenerating = false,
    this.runningConversationId,
    this.streamingMessageId,
    this.retry,
    this.mode = AgentMode.execute,
    this.contextBuild,
    this.contextConversationId,
    this.summarizing = false,
  });

  /// 正在生成的回答内容块（按 Part 顺序）。
  final List<MessagePart> streamingParts;

  /// 当前会话的附件索引，用于把 Part 里的附件引用还原成文件。
  final Map<String, Attachment> attachments;

  final bool isGenerating;
  final String? runningConversationId;
  final String? streamingMessageId;
  final ModelRetryState? retry;
  final AgentMode mode;
  final ContextBuild? contextBuild;
  final String? contextConversationId;
  final bool summarizing;

  ChatState copyWith({
    List<MessagePart>? streamingParts,
    Map<String, Attachment>? attachments,
    bool? isGenerating,
    String? runningConversationId,
    String? streamingMessageId,
    bool clearStreaming = false,
    bool clearRun = false,
    ModelRetryState? retry,
    bool clearRetry = false,
    AgentMode? mode,
    ContextBuild? contextBuild,
    String? contextConversationId,
    bool? summarizing,
    bool clearContext = false,
  }) {
    return ChatState(
      mode: mode ?? this.mode,
      contextBuild: clearContext ? null : contextBuild ?? this.contextBuild,
      contextConversationId: clearContext
          ? null
          : contextConversationId ?? this.contextConversationId,
      summarizing: clearRun ? false : summarizing ?? this.summarizing,
      retry: clearRetry || clearRun ? null : retry ?? this.retry,
      streamingParts: clearStreaming
          ? const []
          : streamingParts ?? this.streamingParts,
      attachments: attachments ?? this.attachments,
      isGenerating: isGenerating ?? this.isGenerating,
      runningConversationId: clearRun
          ? null
          : runningConversationId ?? this.runningConversationId,
      streamingMessageId: clearStreaming
          ? null
          : streamingMessageId ?? this.streamingMessageId,
    );
  }
}

/// 聊天状态在应用生命周期内保留：切到设置页再回来不应丢失当前会话与流式状态。
@Riverpod(
  keepAlive: true,
  dependencies: [
    ModelSelection,
    currentAssistant,
    ActiveConversation,
    settingsStorage,
    modelCatalog,
  ],
)
class ChatController extends _$ChatController implements AgentLoopHost {
  /// 仅在环境就绪时注入的内置工具。
  static const _environmentTools = {'shell', 'install_packages'};

  /// 流式增量写库的节流间隔：SSE chunk 远密于屏幕刷新。
  static const _flushInterval = Duration(milliseconds: 100);

  /// 流式内容发布到界面的间隔：正文与思考都走这个节拍合批。
  ///
  /// 每个 chunk 都刷 UI，等于让整段内容按帧重排——实测每千字约 0.55ms/帧，
  /// 几万字的思考就是每帧几十毫秒。合批之后刷新频率与内容长度无关
  /// （kelivo 50ms、Operit 200ms 是同款做法）。
  static const _publishInterval = Duration(milliseconds: 50);

  StreamSubscription<ChatChunk>? _subscription;
  Completer<void>? _doneCompleter;
  Timer? _flushTimer;
  Timer? _publishTimer;
  String? _streamingMessageId;

  ProviderError? _streamError;
  bool _acceptingChunks = false;

  /// 流式期间的块缓冲：partId → 已累积内容。
  final List<_LivePart> _liveParts = [];

  bool _stoppedManually = false;

  /// 当前运行：一次发送（或重新生成）对应一个 AgentRun，配置在开始时固定。
  AgentRun? _run;

  /// 运行内的模型选择快照：连接、能力与推理等级全程取它，不看中途改动。
  ChatModelSelection? _selection;
  ConversationRepository? _repository;
  AgentRunRepository? _runs;
  ArtifactStorage? _storage;
  ToolRegistry? _registry;
  ToolExecutor? _executor;
  RunCancellation? _cancellation;

  /// 本轮助手的最终内容块；工具引用在响应收口时与整轮记录一起保存。
  List<MessagePart> _turnParts = const [];
  TokenUsage? _turnUsage;
  ModelRequestRepository? _requests;
  String? _requestId;
  int _usageRevision = 0;
  String? _responseModelId;
  ContextMeasurement? _measurement;

  /// 本轮思考耗时；恢复已知工具结果时沿用原消息的值。
  int? _turnThinkingDurationMs;

  /// 本轮分支末尾的消息：下一轮助手消息与运行位置都指向它。
  String? _turnTailId;

  /// 本轮以错误或空回复收场时，运行结束原因取它。
  RunFinishReason? _turnFailure;
  bool _runFinished = false;
  bool _busy = false;
  bool _submittedPlan = false;
  int _viewRevision = 0;
  bool _responseComplete = false;
  Map<String, Attachment> _runAttachments = const {};
  Future<void> _pendingFlush = Future.value();
  Failure? _flushFailure;

  @override
  ChatState build() {
    ref.onDispose(() {
      _flushTimer?.cancel();
      _publishTimer?.cancel();
      _cancellation?.cancel();
      _acceptingChunks = false;
      _completeRequest();
    });
    return const ChatState();
  }

  void setMode(AgentMode mode) {
    if (!_busy && !state.isGenerating) state = state.copyWith(mode: mode);
  }

  void startNewConversation() {
    _viewRevision++;
    ref.read(activeConversationProvider.notifier).clear();
    state = state.copyWith(attachments: const {});
  }

  /// 切换到某个会话；消息由界面订阅仓储，附件索引进入时读取。
  Future<void> openConversation(String conversationId) async {
    final revision = ++_viewRevision;
    final repository = await ref.read(conversationRepositoryProvider.future);
    final thread = await repository.getThread(conversationId);
    if (thread == null || !ref.mounted || revision != _viewRevision) return;
    final attachments = await _attachmentIndex(conversationId, const []);
    if (!ref.mounted || revision != _viewRevision) return;
    ref.read(activeConversationProvider.notifier).open(conversationId);
    state = state.copyWith(attachments: attachments);
    // 会话绑定的助手可能不同：刷新派生选择。
    ref.invalidate(modelSelectionProvider);
  }

  /// 为当前会话切换助手；还没有会话时记为草稿，建会话时使用该助手。
  ///
  /// 草稿同时用于「会话内刚切换、尚未落库」的瞬间，保证下一次发送立即生效。
  Future<void> selectAssistant(String assistantId) async {
    final active = ref.read(activeConversationProvider);
    ref.read(activeConversationProvider.notifier).draftAssistant(assistantId);
    final conversationId = active.conversationId;
    if (conversationId == null) {
      ref.invalidate(modelSelectionProvider);
      return;
    }
    final repository = await ref.read(conversationRepositoryProvider.future);
    final thread = await repository.getThread(conversationId);
    if (thread == null) return;
    await repository.updateConversation(
      thread.conversation.copyWith(assistantId: assistantId),
    );
    ref.invalidate(modelSelectionProvider);
  }

  /// 新建助手（名称必填，其余留空表示未设置）。
  Future<Assistant> createAssistant({
    required String name,
    String systemPrompt = '',
    model.ModelSelection? defaultModelSelection,
    ToolPolicyConfig toolPolicy = defaultToolPolicyConfig,
    Set<String> skillIds = const {},
    MemoryScope memoryScope = MemoryScope.disabled,
  }) {
    return _guardAssistant('创建助手失败', () async {
      final repository = await ref.read(assistantRepositoryProvider.future);
      final assistant = Assistant(
        id: generateId(),
        name: name.trim(),
        systemPrompt: systemPrompt.trim(),
        defaultModelSelection: defaultModelSelection,
        toolPolicy: toolPolicy,
        skillIds: skillIds,
        memoryScope: memoryScope,
        createdAt: DateTime.now(),
      );
      await repository.save(assistant);
      // 新建的助手按列表顺序可能成为当前助手：刷新派生选择。
      ref.invalidate(modelSelectionProvider);
      return assistant;
    });
  }

  /// 更新助手；未传的字段保持不变（含清空默认模型）。
  Future<Assistant> updateAssistant({
    required String id,
    required String name,
    required String systemPrompt,
    model.ModelSelection? defaultModelSelection,
    bool clearDefaultModel = false,
    ToolPolicyConfig? toolPolicy,
    Set<String>? skillIds,
    MemoryScope? memoryScope,
  }) {
    return _guardAssistant('保存助手失败', () async {
      final repository = await ref.read(assistantRepositoryProvider.future);
      final existing = await repository.getById(id);
      if (existing == null) {
        throw const UnknownFailure('助手已不存在');
      }
      final updated = Assistant(
        id: existing.id,
        name: name.trim(),
        systemPrompt: systemPrompt.trim(),
        defaultModelSelection: clearDefaultModel
            ? null
            : (defaultModelSelection ?? existing.defaultModelSelection),
        toolPolicy: toolPolicy ?? existing.toolPolicy,
        skillIds: skillIds ?? existing.skillIds,
        memoryScope: memoryScope ?? existing.memoryScope,
        createdAt: existing.createdAt,
      );
      await repository.save(updated);
      ref.invalidate(modelSelectionProvider);
      return updated;
    });
  }

  /// 删除助手；已有会话保留，仅解除与助手的绑定。
  Future<void> deleteAssistant(String id) {
    return _guardAssistant('删除助手失败', () async {
      final repository = await ref.read(assistantRepositoryProvider.future);
      await repository.delete(id);
      ref.invalidate(modelSelectionProvider);
    });
  }

  /// 助手写操作的统一错误收口。
  Future<T> _guardAssistant<T>(
    String message,
    Future<T> Function() action,
  ) async {
    try {
      return await action();
    } on Failure {
      rethrow;
    } on Exception catch (e, st) {
      AppLogger.error(message, e, st);
      throw UnknownFailure(message, cause: e);
    }
  }

  /// 发送一条消息并流式接收回复。
  ///
  /// 前置失败（未选择模型、落库失败）抛出 [Failure] 由 UI 提示；
  /// 流式期间的错误写入助手消息（failed 状态）并保留已收内容。
  Future<void> send(
    String text, {
    List<Attachment> attachments = const [],
  }) async {
    if (_busy) return;
    _busy = true;
    try {
      await ref.read(runRecoveryControllerProvider.notifier).initialize();
      await _send(text, attachments: attachments);
    } finally {
      _busy = false;
    }
  }

  Future<void> _send(
    String text, {
    List<Attachment> attachments = const [],
  }) async {
    final trimmed = text.trim();
    if ((trimmed.isEmpty && attachments.isEmpty) || state.isGenerating) {
      return;
    }

    // 强刷：刚切换的助手/会话要立刻作用到本次请求，不依赖竞态的重建时机。
    final revision = _viewRevision;
    final selection = await ref.refresh(modelSelectionProvider.future);
    if (selection == null) {
      throw const UnknownFailure('尚未选择服务商与模型');
    }

    if (state.mode == AgentMode.plan && !selection.supportsTools) {
      throw const OperationFailure('计划模式需要支持工具调用的模型');
    }

    final repository = await ref.read(conversationRepositoryProvider.future);

    // 助手列表可能还在首次加载：先把列表与会话线程等就绪，
    // 否则本次请求会丢掉系统提示词与助手默认模型。
    final assistant = await awaitAssistantContext(ref);
    if (revision != _viewRevision) throw const OperationFailure('会话已切换，请重新发送');
    var conversationId = ref.read(activeConversationProvider).conversationId;
    _checkRecoveredConversation(conversationId);
    if (conversationId == null) {
      final conversation = await repository.createConversation(
        assistantId: assistant?.id,
        modelSelectionOverride: ref
            .read(activeConversationProvider)
            .draftModelSelection,
      );
      conversationId = conversation.id;
      if (revision == _viewRevision) {
        ref.read(activeConversationProvider.notifier).adopt(conversationId);
      }
    }
    final thread = await repository.getThread(conversationId);
    if (thread == null) {
      throw const UnknownFailure('会话不存在或已删除');
    }
    final claimed = [
      for (final attachment in attachments)
        attachment.withConversation(conversationId),
    ];
    for (final attachment in claimed) {
      await repository.saveAttachment(attachment);
      // 文档抽取在选择时已完成：结果（文本路径或失败原因）随附件落库。
      if (attachment.isDocument) {
        await repository.updateAttachmentExtraction(
          attachment.id,
          extractedTextPath: attachment.extractedTextPath,
          error: attachment.extractionError,
        );
      }
    }
    // 附件索引带上刚落库的这批，发送后即可在气泡里看到缩略图，
    // 同时用于把历史消息里的附件引用解析成请求内容。
    final attachmentIndex = await _attachmentIndex(conversationId, claimed);
    if (ref.read(activeConversationProvider).conversationId == conversationId) {
      state = state.copyWith(attachments: attachmentIndex);
    }

    final parentId = thread.currentMessageId;
    final userMessage = ChatMessage(
      id: generateId(),
      conversationId: conversationId,
      parentId: parentId,
      role: ChatRole.user,
      status: MessageStatus.completed,
      parts: [
        for (final attachment in claimed)
          if (attachment.isImage)
            ImagePart(attachmentId: attachment.id)
          else
            DocumentPart(attachmentId: attachment.id),
        if (trimmed.isNotEmpty) TextPart(text: trimmed),
      ],
      createdAt: DateTime.now(),
    );
    await repository.appendMessage(userMessage, updateTitle: parentId == null);

    await _startRun(
      repository: repository,
      conversationId: conversationId,
      inputMessageId: userMessage.id,
      selection: selection,
      assistant: assistant,
      mode: state.mode,
    );
  }

  /// 重新生成当前分支的最后一条回答。
  ///
  /// 新建一条回答挂在同一条用户消息下，旧回答保留在消息树里不覆盖；
  /// 有工具执行历史时不自动重做动作（S3 起生效）。
  Future<void> regenerate() async {
    if (_busy) return;
    _busy = true;
    try {
      await ref.read(runRecoveryControllerProvider.notifier).initialize();
      await _regenerate();
    } finally {
      _busy = false;
    }
  }

  Future<void> _regenerate() async {
    if (state.isGenerating) return;
    final conversationId = ref.read(activeConversationProvider).conversationId;
    if (conversationId == null) return;
    _checkRecoveredConversation(conversationId);

    final repository = await ref.read(conversationRepositoryProvider.future);
    final thread = await repository.getThread(conversationId);
    if (thread == null || thread.branch.isEmpty) return;

    // 找到最近一条用户消息：它就是本轮要重新回答的输入。
    final index = thread.branch.lastIndexWhere(
      (message) => message.role == ChatRole.user,
    );
    if (index < 0) return;
    final userMessage = thread.branch[index];

    final selection = await ref.refresh(modelSelectionProvider.future);
    if (selection == null) {
      throw const UnknownFailure('尚未选择服务商与模型');
    }
    final assistant = await awaitAssistantContext(ref);

    // 只重做最后的模型回答；已有动作与结果留在新分支的上下文中。
    // 即使停止时缺少结果消息，也保留调用，由上下文装配补齐实际错误。
    final toolHistory = thread.branch
        .skip(index + 1)
        .where(
          (message) => message.parts.any(
            (part) => part is ToolCallPart || part is ToolResultPart,
          ),
        );
    final parentId = toolHistory.lastOrNull?.id ?? userMessage.id;
    await repository.setCurrentMessage(conversationId, parentId);

    await _startRun(
      repository: repository,
      conversationId: conversationId,
      inputMessageId: userMessage.id,
      selection: selection,
      assistant: assistant,
      mode: state.mode,
    );
  }

  /// 复制指定会话：副本带同样的助手、模型覆盖与全部消息/分支结构，
  /// 并切换到副本；原会话不受影响。
  Future<String> duplicateFrom(String conversationId) async {
    final repository = await ref.read(conversationRepositoryProvider.future);
    final copy = await repository.duplicateConversation(conversationId);
    await openConversation(copy.id);
    return copy.id;
  }

  // --- AgentLoopHost：循环只决定顺序，真实 IO 都在控制器里 ---

  @override
  bool get isCancelled => _cancellation?.isCancelled ?? false;

  Future<List<Tool>> _agentTools({
    required AgentMode mode,
    required String? assistantId,
    required MemoryScope scope,
    required String inputMessageId,
  }) async => [
    ReadHistoryTool(
      await ref.read(conversationRepositoryProvider.future),
      await ref.read(toolCallRepositoryProvider.future),
    ),
    if (mode == AgentMode.plan)
      SubmitPlanTool(await ref.read(planRepositoryProvider.future)),
    if (scope != MemoryScope.disabled)
      for (final write in [false, true])
        if (mode != AgentMode.plan || !write)
          MemoryTool(
            repository: await ref.read(memoryRepositoryProvider.future),
            assistants: await ref.read(assistantRepositoryProvider.future),
            assistantId: assistantId,
            scope: scope,
            sourceMessageId: inputMessageId,
            write: write,
          ),
  ];

  Future<void> approvePlan(AgentPlan plan) async {
    if (_busy || state.isGenerating) throw const OperationFailure('请先结束当前任务');
    _busy = true;
    try {
      await ref.read(runRecoveryControllerProvider.notifier).initialize();
      _checkRecoveredConversation(plan.conversationId);
      if (ref.read(activeConversationProvider).conversationId !=
          plan.conversationId) {
        throw const OperationFailure('请返回计划所属会话后批准');
      }
      final revision = _viewRevision;
      final selection = await ref.refresh(modelSelectionProvider.future);
      final assistant = await awaitAssistantContext(ref);
      if (selection == null) throw const OperationFailure('尚未选择模型');
      if (revision != _viewRevision) throw const OperationFailure('会话已切换');
      await _startRun(
        repository: await ref.read(conversationRepositoryProvider.future),
        conversationId: plan.conversationId,
        inputMessageId: generateId(),
        selection: selection,
        assistant: assistant,
        approvedPlan: plan,
      );
    } finally {
      _busy = false;
    }
  }

  /// 无网络/写库的下一请求规划；预览与手动整理不创建会话或运行。
  Future<PreparedContext?> prepareContext(String conversationId) async {
    if (ref.read(activeConversationProvider).conversationId != conversationId) {
      return null;
    }
    final repository = await ref.read(conversationRepositoryProvider.future);
    final thread = await repository.getThread(conversationId);
    final selection = await ref.read(modelSelectionProvider.future);
    if (thread?.currentMessageId == null || selection == null) return null;
    final assistant = await awaitAssistantContext(ref);
    final mode = state.mode;
    final workspaces = await ref.read(workspaceRepositoryProvider.future);
    final workspaceId = thread!.conversation.workspaceId;
    final workspace = workspaceId == null
        ? null
        : await workspaces.snapshot(workspaceId);
    final extra = selection.supportsTools
        ? await _agentTools(
            mode: mode,
            assistantId: assistant?.id,
            scope: assistant?.memoryScope ?? MemoryScope.disabled,
            inputMessageId: thread.currentMessageId!,
          )
        : <Tool>[];
    final List<SkillInstallation> installations =
        selection.supportsTools && (assistant?.skillIds.isNotEmpty ?? false)
        ? await (await ref.read(skillRepositoryProvider.future)).list()
        : const [];
    final skills = [
      for (final item in installations)
        if (item.enabled &&
            !item.deleting &&
            assistant!.skillIds.contains(item.id))
          item.snapshot,
    ];
    final skillTool = skills.isEmpty
        ? null
        : ReadSkillTool(
            skills: skills,
            repository: await ref.read(skillRepositoryProvider.future),
            assistants: await ref.read(assistantRepositoryProvider.future),
            assistantId: assistant?.id,
            linuxAvailable: workspace?.linuxAvailable == true,
          );
    final registry = ToolRegistry([
      ...extra,
      ...ref.read(toolRegistryProvider).tools,
      ?skillTool,
      if (skillTool != null &&
          workspace?.linuxAvailable == true &&
          mode != AgentMode.plan)
        PrepareSkillTool(skillTool, workspace!, WorkspaceFiles(workspaces)),
    ]);
    final enabled = selection.supportsTools
        ? {
            ...?assistant?.toolPolicy.enabledTools,
            ...extra.map((t) => t.name),
            if (skillTool != null) 'read_skill',
            if (skillTool != null && workspace?.linuxAvailable == true)
              'prepare_skill',
          }
        : <String>{};
    enabled.removeWhere(
      (name) =>
          (_environmentTools.contains(name) &&
              workspace?.linuxAvailable != true) ||
          (name == 'capture_screen' && !selection.supportsImages) ||
          (mode == AgentMode.plan &&
              (registry.byName(name) == null ||
                  !allowedInPlan(registry.byName(name)!))),
    );
    final policies =
        assistant?.toolPolicy.overrides ?? const <String, ToolPolicy>{};
    final tools = registry.definitionsFor(enabled, policies);
    if (mode != AgentMode.plan && enabled.any((n) => n.startsWith('mcp_'))) {
      for (final entry in await (await ref.read(
        mcpServerRepositoryProvider.future,
      )).list()) {
        if (!entry.profile.enabled || entry.profile.deleting) continue;
        tools.addAll(
          entry.tools
              .where((t) => enabled.contains(t.name))
              .map(SnapshotToolDefinition.new),
        );
      }
    }
    final config = selection.profile.models
        .where((m) => m.id == selection.model)
        .firstOrNull;
    // 窗口/输出上限解析：用户手填 > models.dev 目录 > 本地默认 128000。
    final limits = resolveContextLimits(
      presetId: selection.profile.presetId,
      modelId: selection.model,
      userContextWindow: config?.contextWindow,
      userMaxOutputTokens: config?.maxOutputTokens,
      catalog: await ref.read(modelCatalogProvider.future),
    );
    if (!ref.mounted) return null;
    final configuration = RunConfiguration(
      connection: RunConnection(
        profileId: selection.profile.id,
        protocol: selection.profile.protocol.name,
        baseUrl: selection.profile.baseUrl,
        requiresKey: selection.profile.requiresKey,
      ),
      modelSelection: model.ModelSelection(
        profileId: selection.profile.id,
        modelId: selection.model,
        reasoningEffort: selection.effort,
        temperature: config?.temperature,
        maxOutputTokens: config?.maxOutputTokens,
      ),
      systemPrompt: assistant?.systemPrompt ?? '',
      mode: mode,
      contextWindow: limits.contextWindow,
      contextWindowSource: limits.source.name,
      catalogMaxOutputTokens: limits.catalogMaxOutputTokens,
      skills: skills,
      workspace: workspace,
      enabledTools: enabled,
      toolPolicies: policies,
      executionScope: ref.read(settingsStorageProvider).readExecutionScope(),
      supportsReasoning: selection.supportsReasoning,
    );
    final resolver = HistoryResolver(
      repository: repository,
      runs: await ref.read(agentRunRepositoryProvider.future),
      profile: selection.profile,
      registry: registry,
    );
    final messages = await resolver.resolve(
      thread.branch,
      await _attachmentIndex(conversationId, const []),
      currentModelId: selection.model,
    );
    return PreparedContext(
      assistantId: assistant?.id,
      reloadMessages: () async {
        final latest = await repository.getThread(conversationId);
        if (latest == null) return const [];
        final attachments = await repository.attachmentsFor(conversationId);
        return resolver.resolve(latest.branch, {
          for (final attachment in attachments) attachment.id: attachment,
        }, currentModelId: selection.model);
      },
      conversationId: conversationId,
      branchHeadId: thread.currentMessageId!,
      profile: selection.profile,
      configuration: configuration,
      protectedIds: {
        ?messages
            .where((m) => m.role == ChatRole.user)
            .lastOrNull
            ?.sourceMessageId,
      },
      request: ChatRequest(
        modelId: selection.model,
        messages: messages,
        systemPrompt: contextSystemPrompt(configuration),
        tools: tools,
        reasoningEffort: selection.supportsReasoning
            ? selection.effort
            : ReasoningEffort.off,
        temperature: config?.temperature,
        maxOutputTokens: config?.maxOutputTokens,
      ),
    );
  }

  Future<String> compactContext(String conversationId) async {
    if (_busy || state.isGenerating) throw const OperationFailure('请先结束当前任务');
    _busy = true;
    final cancellation = RunCancellation();
    _cancellation = cancellation;
    final revision = _viewRevision;
    state = state.copyWith(
      isGenerating: true,
      runningConversationId: conversationId,
      summarizing: true,
      clearContext: true,
    );
    try {
      await ref.read(runRecoveryControllerProvider.notifier).initialize();
      _checkRecoveredConversation(conversationId);
      final prepared = await prepareContext(conversationId);
      if (prepared == null) throw const OperationFailure('请选择模型并打开已有会话');
      if (cancellation.isCancelled) return '已停止整理';
      if (revision != _viewRevision) {
        throw const OperationFailure('会话已切换，请重新整理');
      }
      final key = prepared.profile.requiresKey
          ? await ref
                    .read(secureKeyStorageProvider)
                    .read(prepared.profile.id) ??
                ''
          : '';
      final result =
          await CompactionCoordinator(
            summaries: await ref.read(agentContextRepositoryProvider.future),
            requests: await ref.read(modelRequestRepositoryProvider.future),
          ).build(
            conversationId: conversationId,
            runId: null,
            branchHeadId: prepared.branchHeadId,
            profile: prepared.profile,
            provider: ref.read(aiProviderFactoryProvider)(
              prepared.profile,
              key,
            ),
            request: prepared.request,
            cancellation: cancellation,
            protectedIds: prepared.protectedIds,
            canReadHistory: prepared.canReadHistory,
            canReadHistoryNow: () =>
                _historyAllowed(prepared.request.tools, prepared.assistantId),
            reloadMessages: prepared.reloadMessages,
            contextWindow: prepared.configuration.contextWindow,
            windowSource: prepared.configuration.resolvedWindowSource,
            catalogMaxOutputTokens:
                prepared.configuration.catalogMaxOutputTokens,
            policy: prepared.configuration.contextPolicy,
            force: true,
          );
      if (ref.mounted && revision == _viewRevision) {
        state = state.copyWith(
          contextBuild: result,
          contextConversationId: conversationId,
        );
      }
      return cancellation.isCancelled
          ? '已停止整理'
          : result.compactionNotice ?? '上下文整理完成';
    } finally {
      cancellation.cancel();
      _cancellation = null;
      _busy = false;
      if (ref.mounted) {
        state = state.copyWith(isGenerating: false, clearRun: true);
      }
    }
  }

  /// 一次运行的完整过程：创建 AgentRun（固定配置）→ 交给 [AgentLoop] 驱动。
  ///
  /// 循环里每一步的真实 IO 由本控制器实现（[AgentLoopHost]）：一轮模型请求、
  /// 一次工具执行、结果回填与运行收口；中途改助手或模型只影响下一次运行。
  Future<void> _startRun({
    required ConversationRepository repository,
    required String conversationId,
    required String inputMessageId,
    required ChatModelSelection selection,
    required Assistant? assistant,
    AgentMode mode = AgentMode.execute,
    AgentPlan? approvedPlan,
  }) async {
    final runs = await ref.read(agentRunRepositoryProvider.future);
    final modelConfig = selection.profile.models
        .where((m) => m.id == selection.model)
        .firstOrNull;
    // 窗口/输出上限解析：用户手填 > models.dev 目录 > 本地默认 128000。
    // 目录输出上限只进本地预留，modelSelection 的 maxOutputTokens 仍只用用户值。
    final limits = resolveContextLimits(
      presetId: selection.profile.presetId,
      modelId: selection.model,
      userContextWindow: modelConfig?.contextWindow,
      userMaxOutputTokens: modelConfig?.maxOutputTokens,
      catalog: await ref.read(modelCatalogProvider.future),
    );
    if (!ref.mounted) throw const CancelledFailure('创建运行前已退出');

    if (mode == AgentMode.plan && !selection.supportsTools) {
      throw const OperationFailure('计划模式需要支持工具调用的模型');
    }
    final extraTools = selection.supportsTools
        ? await _agentTools(
            mode: mode,
            assistantId: assistant?.id,
            scope: assistant?.memoryScope ?? MemoryScope.disabled,
            inputMessageId: inputMessageId,
          )
        : <Tool>[];
    final baseRegistry = ToolRegistry([
      ...ref.read(toolRegistryProvider).tools,
      ...extraTools,
    ]);
    final enabled = selection.supportsTools
        ? {
            ...?assistant?.toolPolicy.enabledTools,
            ...extraTools.map((t) => t.name),
          }
        : <String>{};
    // 仅助手选择了 MCP 时访问目录；普通聊天没有扩展连接前置。
    final mcpEntries =
        mode != AgentMode.plan && enabled.any((name) => name.startsWith('mcp_'))
        ? await (await ref.read(mcpServerRepositoryProvider.future)).list()
        : const [];
    final skillLease =
        selection.supportsTools && (assistant?.skillIds.isNotEmpty ?? false)
        ? await (await ref.read(skillRepositoryProvider.future))
              .acquire(assistant!.skillIds)
        : null;
    WorkspaceLease? workspaceLease;
    try {
      final thread = await repository.getThread(conversationId);
      final workspaceId = thread?.conversation.workspaceId;
      if (workspaceId != null) {
        workspaceLease = await (await ref.read(
          workspaceRepositoryProvider.future,
        )).acquire(workspaceId);
      }
      final workspace = workspaceLease?.snapshot;
      final skills = skillLease?.skills ?? const [];
      final skillTool = skills.isEmpty
          ? null
          : ReadSkillTool(
              skills: skills,
              repository: await ref.read(skillRepositoryProvider.future),
              assistants: await ref.read(assistantRepositoryProvider.future),
              assistantId: assistant?.id,
              linuxAvailable: workspace?.linuxAvailable == true,
            );
      final prepareSkill =
          skillTool == null || workspace?.linuxAvailable != true
          ? null
          : PrepareSkillTool(
              skillTool,
              workspace!,
              WorkspaceFiles(
                await ref.read(workspaceRepositoryProvider.future),
              ),
            );
      final snapshots = <ToolSnapshot>[
        if (skillTool != null) skillTool.snapshot,
        if (prepareSkill != null && mode != AgentMode.plan)
          prepareSkill.snapshot,
        for (final tool in baseRegistry.tools)
          if ((mode != AgentMode.plan || allowedInPlan(tool)) &&
              enabled.contains(tool.name) &&
              (!_environmentTools.contains(tool.name) ||
                  workspace?.linuxAvailable == true))
            tool.snapshot,
        for (final entry in mcpEntries)
          if (entry.profile.enabled && !entry.profile.deleting)
            for (final tool in entry.tools)
              if (enabled.contains(tool.name)) tool,
      ];

      // 连接快照只存服务商 id、协议与地址，密钥按 id 在调用时读取。
      final candidate = AgentRun(
        id: generateId(),
        conversationId: conversationId,
        assistantId: assistant?.id,
        inputMessageId: inputMessageId,
        configuration: RunConfiguration(
          mode: mode,
          contextWindow: limits.contextWindow,
          contextWindowSource: limits.source.name,
          catalogMaxOutputTokens: limits.catalogMaxOutputTokens,
          memoryScope: assistant?.memoryScope ?? MemoryScope.disabled,
          planId: approvedPlan?.id,
          planRevision: approvedPlan?.revision,
          approvedPlan: approvedPlan?.text,
          connection: RunConnection(
            profileId: selection.profile.id,
            protocol: selection.profile.protocol.name,
            baseUrl: selection.profile.baseUrl,
            requiresKey: selection.profile.requiresKey,
          ),
          modelSelection: model.ModelSelection(
            profileId: selection.profile.id,
            modelId: selection.model,
            reasoningEffort: selection.effort,
            temperature: modelConfig?.temperature,
            maxOutputTokens: modelConfig?.maxOutputTokens,
          ),
          systemPrompt: assistant?.systemPrompt ?? '',
          toolSnapshots: snapshots,
          skills: skills,
          workspace: workspace,
          mcpServers: [
            for (final entry in mcpEntries)
              if (snapshots.any(
                (tool) =>
                    tool.source.kind == ToolSourceKind.mcp &&
                    tool.source.id == entry.profile.id,
              ))
                entry.profile,
          ],
          executionScope: ref
              .read(settingsStorageProvider)
              .readExecutionScope(),
          enabledTools: {
            for (final snapshot in snapshots)
              if (selection.supportsImages || snapshot.name != 'capture_screen')
                snapshot.name,
          },
          toolPolicies: selection.supportsTools
              ? assistant?.toolPolicy.overrides ?? const {}
              : const {},
          supportsReasoning: selection.supportsReasoning,
          supportsImages: selection.supportsImages,
          supportsTools: selection.supportsTools,
          compatOverrides: selection.profile.compatOverrides,
        ),
        createdAt: DateTime.now(),
      );
      final run = approvedPlan == null
          ? await runs.create(candidate)
          : await (await ref.read(planRepositoryProvider.future))
                .approveAndCreate(approvedPlan, candidate);

      try {
        await _driveRun(run, repository, selection);
      } on Failure {
        final stored = await runs.getById(run.id);
        if (stored?.status == RunStatus.running && stored?.turnCount == 0) {
          await runs.finish(
            run.id,
            status: RunStatus.failed,
            finishReason: RunFinishReason.storageError,
          );
        }
        rethrow;
      }
    } finally {
      workspaceLease?.close();
      await skillLease?.close();
    }
  }

  Future<void> _driveRun(
    AgentRun run,
    ConversationRepository repository,
    ChatModelSelection selection, {
    bool resuming = false,
  }) async {
    final runs = await ref.read(agentRunRepositoryProvider.future);
    final toolCalls = await ref.read(toolCallRepositoryProvider.future);
    final storage = await ref.read(artifactStorageProvider.future);
    final recovery = ref.read(runRecoveryControllerProvider.notifier);

    final mcp = run.configuration.mcpServers.isEmpty
        ? null
        : McpRunRuntime(
            run: run,
            repository: await ref.read(mcpServerRepositoryProvider.future),
            assistants: await ref.read(assistantRepositoryProvider.future),
            connections: ref.read(mcpConnectionsProvider),
          );
    final base = ref.read(toolRegistryProvider);
    final skillTool = run.configuration.skills.isEmpty
        ? null
        : ReadSkillTool(
            skills: run.configuration.skills,
            repository: await ref.read(skillRepositoryProvider.future),
            assistants: await ref.read(assistantRepositoryProvider.future),
            assistantId: run.assistantId,
            linuxAvailable: run.configuration.workspace?.linuxAvailable == true,
          );
    final binding = run.configuration.workspace;
    final workspaceRepository = binding == null
        ? null
        : await ref.read(workspaceRepositoryProvider.future);
    final workspaceFiles = workspaceRepository == null
        ? null
        : WorkspaceFiles(workspaceRepository);
    final processDriver = binding?.linuxAvailable != true
        ? null
        : ref.read(processDriverProvider);
    final agentTools = selection.supportsTools
        ? await _agentTools(
            mode: run.configuration.mode,
            assistantId: run.assistantId,
            scope: run.configuration.memoryScope,
            inputMessageId: run.inputMessageId,
          )
        : <Tool>[];
    final registry = ToolRegistry([
      ...agentTools,
      for (final tool in base.tools)
        if (!_environmentTools.contains(tool.name))
          if (tool is WaitForUserTool) WaitForUserTool(_waitForUser) else tool,
      if (binding?.linuxAvailable == true)
        ShellTool(
          workspace: binding,
          driver: processDriver,
          files: workspaceFiles,
        ),
      if (binding?.linuxAvailable == true)
        InstallTool(
          workspace: binding,
          repository: workspaceRepository,
          driver: processDriver,
        ),
      if (binding?.linuxAvailable == true && skillTool != null)
        PrepareSkillTool(skillTool, binding!, workspaceFiles!),
      ...?mcp?.tools(),
      ?skillTool,
    ]);
    final execution = ref.read(executionControllerProvider.notifier);
    final executor = ToolExecutor(
      registry: registry,
      toolCalls: toolCalls,
      runs: runs,
      onExecuting: (tool, arguments, toolCallId) {
        if (!ref.mounted) return;
        execution.updateActivity(
          run.id,
          ref
              .read(executionControllerProvider)
              .activity
              .copyWith(
                phase: TaskPanelPhase.executingTool,
                status: '正在${ToolPresentation.toolLabel(tool.name)}',
              )
              .upsert(
                TaskMessage(
                  id: 'tool/$toolCallId',
                  kind: TaskPanelMessageKind.tool,
                  label: '正在${ToolPresentation.toolLabel(tool.name)}',
                  text: _toolActivity(tool, arguments),
                ),
              ),
        );
      },
      currentPolicy: (tool) async {
        if (run.configuration.mode == AgentMode.plan && !allowedInPlan(tool)) {
          return ToolPolicy.deny;
        }
        if (tool is ReadHistoryTool) {
          final assistant = run.assistantId == null
              ? null
              : await (await ref.read(assistantRepositoryProvider.future))
                    .getById(run.assistantId!);
          return assistant?.toolPolicy.overrides['read_history'] ??
              ToolPolicy.allow;
        }
        if (tool is MemoryTool) return tool.currentPolicy();
        if (tool is ReadSkillTool) return tool.currentPolicy();
        if (tool is PrepareSkillTool) return tool.currentPolicy();
        if (tool is ShellTool) {
          final assistant = run.assistantId == null
              ? null
              : await (await ref.read(assistantRepositoryProvider.future))
                    .getById(run.assistantId!);
          return assistant?.toolPolicy.overrides['shell'] ?? ToolPolicy.deny;
        }
        if (tool.source.kind != ToolSourceKind.mcp) {
          return registry.policyFor(
            tool,
            run.configuration.enabledTools,
            run.configuration.toolPolicies,
          );
        }
        await mcp!.checkAvailable(tool.snapshot);
        return mcp.currentPolicy(tool.snapshot);
      },
      prepareChannel: (tool, arguments) async {
        execution.updateActivity(
          run.id,
          ref
              .read(executionControllerProvider)
              .activity
              .copyWith(
                phase: TaskPanelPhase.preparingTool,
                status: '准备${ToolPresentation.toolLabel(tool.name)}',
              ),
        );
        if (tool is ShellTool) {
          await processDriver!.beginTask(run.id, '工作区命令');
          await execution.showAvailablePanel(run.id);
        }
        if (tool.usesPlatform(arguments)) {
          await execution.ensureDeviceHost(
            run.id,
            deviceTask: tool.channel != ExecutionChannel.app,
          );
        }
      },
    );
    executor.onConfirmationRequired = _confirmToolCall;

    _run = run;
    _selection = selection;
    _repository = repository;
    _runs = runs;
    _requests = await ref.read(modelRequestRepositoryProvider.future);
    _storage = storage;
    _registry = registry;
    _executor = executor;
    _cancellation = RunCancellation();
    _runFinished = false;
    _submittedPlan = false;
    _turnFailure = null;
    _turnTailId = null;
    recovery.runStarted(run.id);
    WorkspaceLease? resumedWorkspace;
    final processStops = processDriver?.stops.listen((owner) {
      if (owner == run.id) stop();
    });
    try {
      if (resuming && binding != null) {
        resumedWorkspace = await workspaceRepository!.acquire(
          binding.id,
          expected: binding,
        );
      }
      execution.beginRun(
        run.id,
        stop: stop,
        scope: run.configuration.executionScope,
        readCurrentAppPolicy: () =>
            ref.read(settingsStorageProvider).readExecutionScope().appPolicy,
      );
      _runAttachments = await _attachmentIndex(run.conversationId, const []);
      state = state.copyWith(
        isGenerating: true,
        mode: run.configuration.mode,
        clearContext: true,
        clearStreaming: true,
        runningConversationId: run.conversationId,
        attachments:
            ref.read(activeConversationProvider).conversationId ==
                run.conversationId
            ? _runAttachments
            : null,
      );

      if (resuming && !await _restorePendingTools()) return;
      if (_submittedPlan) {
        await finish(
          isCancelled
              ? AgentFinishReason.cancelled
              : AgentFinishReason.completed,
        );
        return;
      }
      await AgentLoop(
        this,
        maxTurns: run.maxTurns == 0 ? null : run.maxTurns - run.turnCount,
      ).run();
    } on StorageFailure {
      await _requests!.interruptPending(
        runId: run.id,
        errorCode: 'storageError',
      );
      // 落库失败：运行按存储失败收口后再交给界面提示，不留永远 running 的运行。
      try {
        await _finishRun(RunStatus.failed, RunFinishReason.storageError);
      } on Failure {
        AppLogger.error('运行终态未能保存，启动时需核对');
      }
      rethrow;
    } on Failure {
      await _finishUnexpectedRun();
      rethrow;
    } catch (error, stackTrace) {
      AppLogger.error('运行异常：${error.runtimeType}', null, stackTrace);
      await _finishUnexpectedRun();
      throw UnknownFailure('运行执行失败', cause: error);
    } finally {
      _acceptingChunks = false;
      _flushTimer?.cancel();
      _flushTimer = null;
      _publishTimer?.cancel();
      _publishTimer = null;
      _streamingMessageId = null;
      _cancellation?.cancel();
      await mcp?.close();
      try {
        if (processDriver != null) await processDriver.endTask(run.id);
      } on Failure {
        AppLogger.warning('Linux 任务服务未确认结束');
      }
      await processStops?.cancel();
      resumedWorkspace?.close();
      try {
        await execution.endRun(run.id);
      } on Failure {
        // 控制器保留可见错误；不让服务清理失败跳过本地资源与运行收尾。
        AppLogger.warning('Android 任务服务未确认结束');
      }
      await _subscription?.cancel();
      _subscription = null;
      _doneCompleter = null;
      Failure? cleanupFailure;
      try {
        await _requests!.interruptPending(runId: run.id);
      } on Failure catch (error) {
        cleanupFailure = error;
      }
      _requestId = null;
      _run = null;
      _selection = null;
      _cancellation = null;
      _executor = null;
      if (ref.mounted) {
        // 清理与恢复索引刷新完成后才解锁发送，避免两个根任务交错写入。
        await recovery.runFinished().catchError((Object _) {});
      }
      if (ref.mounted) {
        state = state.copyWith(
          isGenerating: false,
          clearStreaming: true,
          clearRun: true,
        );
      }
      if (cleanupFailure != null) throw cleanupFailure;
    }
  }

  Future<void> _finishUnexpectedRun() async {
    try {
      await _finishRun(
        isCancelled ? RunStatus.stopped : RunStatus.failed,
        isCancelled
            ? RunFinishReason.cancelled
            : RunFinishReason.executionError,
      );
    } on Failure {
      AppLogger.error('运行终态未能保存，启动时需核对');
    }
  }

  void _checkRecoveredConversation(String? id) {
    final recovery = ref.read(runRecoveryControllerProvider);
    if (recovery.hasError) throw const OperationFailure('请先重试读取中断任务');
    if (id != null &&
        (recovery.value ?? []).any((entry) => entry.run.conversationId == id)) {
      throw const OperationFailure('请先继续或停止此会话的中断任务');
    }
  }

  /// 用户主动继续已保存的位置；配置取运行快照，不重新执行已知结果。
  Future<void> resumeRun(String runId) async {
    if (_busy) return;
    _busy = true;
    try {
      final recovery = ref.read(runRecoveryControllerProvider.notifier);
      await recovery.refresh();
      final entry = (ref.read(runRecoveryControllerProvider).value ?? [])
          .where((entry) => entry.run.id == runId)
          .firstOrNull;
      if (entry == null) throw const OperationFailure('此任务已结束');
      final run = entry.run;
      final config = run.configuration;
      final modelConfig = config.modelSelection;
      final protocol = ApiProtocol.values
          .where((p) => p.name == config.connection.protocol)
          .firstOrNull;
      if (protocol == null) throw const OperationFailure('运行的协议配置无效');
      final profile = ProviderProfile(
        id: config.connection.profileId,
        name: '运行配置',
        protocol: protocol,
        baseUrl: config.connection.baseUrl,
        requiresKey: config.connection.requiresKey,
        compatOverrides: config.compatOverrides,
        createdAt: run.createdAt,
        models: [
          ProfileModel(
            id: modelConfig.modelId,
            supportsReasoning: config.supportsReasoning,
            supportsImages: config.supportsImages,
            supportsTools: config.supportsTools,
            temperature: modelConfig.temperature,
            maxOutputTokens: modelConfig.maxOutputTokens,
            contextWindow: config.contextWindow,
          ),
        ],
      );
      await openConversation(run.conversationId);
      final repository = await ref.read(conversationRepositoryProvider.future);
      await _driveRun(
        run,
        repository,
        ChatModelSelection(
          profile: profile,
          model: modelConfig.modelId,
          supportsReasoning: config.supportsReasoning,
          supportsImages: config.supportsImages,
          supportsTools: config.supportsTools,
          effort: modelConfig.reasoningEffort,
        ),
        resuming: true,
      );
    } finally {
      _busy = false;
    }
  }

  Future<bool> _restorePendingTools() async {
    final run = _run!;
    final thread = await _repository!.getThread(run.conversationId);
    if (thread == null) throw const OperationFailure('会话已不存在');
    _run = await _runs!.resume(run.id);
    _turnTailId = thread.currentMessageId;
    final records = await _recordsFor(thread.branch);
    _submittedPlan =
        run.configuration.mode == AgentMode.plan &&
        records.values.any(
          (record) =>
              record.runId == run.id &&
              record.toolName == 'submit_plan' &&
              record.status == ToolCallStatus.succeeded,
        );
    for (final message in thread.branch.where(
      (m) => m.runId == run.id && m.role == ChatRole.assistant,
    )) {
      _turnParts = message.parts;
      _turnUsage = message.usage;
      _turnThinkingDurationMs = message.thinkingDurationMs;
      final turn = StreamedTurn(
        messageId: message.id,
        parts: message.parts,
        toolCalls: const [],
      );
      for (final part in message.parts.whereType<ToolCallPart>()) {
        final record = records[part.toolCallId];
        if (record == null) throw const OperationFailure('中断任务的工具记录不完整');
        if (record.resultMessageId != null) continue;
        final providerCallId = record.providerCallId;
        if (providerCallId == null) {
          throw const OperationFailure('中断调用缺少协议标识，无法继续');
        }
        if (isCancelled) {
          await finish(AgentFinishReason.cancelled);
          return false;
        }
        await executeTool(
          ToolCall(
            callId: providerCallId,
            toolName: record.toolName,
            arguments: record.arguments,
            providerData: record.providerData,
            recordId: record.id,
          ),
          turn,
        );
      }
    }
    return true;
  }

  /// 一轮模型请求：装配上下文 → 创建助手消息 → 流式累积 → 收口落库。
  @override
  Future<StreamedTurn> streamTurn() async {
    final run = _run!;
    final repository = _repository!;
    final selection = _selection!;

    final thread = await repository.getThread(run.conversationId);
    if (thread == null) {
      throw const UnknownFailure('会话不存在或已删除');
    }
    // 轮次在本轮模型调用前 +1；每次真实请求（含重试）另计尝试数。
    _run = await _runs!.beginTurn(run.id);
    final messages = await _resolveHistory(
      thread.branch,
      _runAttachments,
      currentModelId: selection.model,
    );

    return _requestWithRetry(
      selection,
      messages,
      parentId: thread.currentMessageId,
    );
  }

  /// 一次模型尝试保存为独立消息；失败尝试保留在同一父节点的历史分支。
  Future<StreamedTurn> _streamAttempt(
    AiProvider provider,
    ChatRequest request, {
    required String? parentId,
  }) async {
    final run = _run!;
    final repository = _repository!;
    final selection = _selection!;
    final assistantMessage = ChatMessage(
      id: generateId(),
      conversationId: run.conversationId,
      parentId: parentId,
      runId: run.id,
      role: ChatRole.assistant,
      status: MessageStatus.streaming,
      parts: const [],
      modelLabel: selection.model,
      createdAt: DateTime.now(),
    );
    _requestId = generateId();
    _usageRevision = 0;
    _responseModelId = null;
    await _requests!.prepare(
      ModelRequestRecord(
        id: _requestId!,
        conversationId: run.conversationId,
        runId: run.id,
        logicalTurn: run.turnCount,
        attemptIndex: _attemptIndex,
        profileId: run.configuration.connection.profileId,
        protocol: run.configuration.connection.protocol,
        requestedModelId: selection.model,
        assistantMessageId: assistantMessage.id,
        contextSnapshot: _measurement?.toSnapshot() ?? const {},
        createdAt: DateTime.now(),
      ),
    );
    await repository.appendMessage(assistantMessage);

    _liveParts.clear();
    ref
        .read(executionControllerProvider.notifier)
        .updateActivity(
          run.id,
          ref.read(executionControllerProvider).activity.waitForResponse(),
        );
    _streamingMessageId = assistantMessage.id;
    _streamError = null;
    _stoppedManually = isCancelled;
    _responseComplete = false;
    _flushFailure = null;
    _turnThinkingDurationMs = null;
    _turnParts = const [];
    _turnUsage = null;
    _turnFailure = null;
    _turnTailId = assistantMessage.id;
    state = state.copyWith(
      streamingParts: const [],
      streamingMessageId: assistantMessage.id,
    );

    try {
      if (!isCancelled) {
        await _consume(provider, request);
      }
    } finally {
      _finishThinking();
      _flushTimer?.cancel();
      _flushTimer = null;
      await _pendingFlush;
      _publishImmediately();
      if (ref.mounted) state = state.copyWith(clearStreaming: true);
      _streamingMessageId = null;
    }
    if (_flushFailure case final error?) {
      await _requests!.interruptPending(
        runId: run.id,
        errorCode: 'storageError',
      );
      throw error;
    }

    final parts = _partsFromLive(_liveParts);
    final toolCalls = _toolCallsFromLive();
    final failure =
        _streamError ??
        (!_responseComplete &&
                !isCancelled &&
                (parts.isNotEmpty || toolCalls.isNotEmpty)
            ? const ProviderError(
                ProviderErrorCategory.incompleteResponse,
                'incomplete response',
              )
            : null);
    _streamError = failure;
    _turnThinkingDurationMs = _currentThinkingDurationMs;

    if (_stoppedManually || isCancelled) {
      // 停止保留已收内容；未执行的调用不再进入调度。
      _turnParts = parts;
      await _settleAttempt(ModelRequestStatus.cancelled, () async {
        await repository.updateMessage(
          messageId: assistantMessage.id,
          parts: parts,
          status: MessageStatus.cancelled,
          thinkingDurationMs: _turnThinkingDurationMs,
        );
      });
      return StreamedTurn(
        messageId: assistantMessage.id,
        parts: _turnParts,
        toolCalls: const [],
        cancelled: true,
      );
    }

    if (failure != null) {
      // 流内错误与连接错误都保留已收内容，按失败收口。
      _turnFailure = failure.category == ProviderErrorCategory.contextLimit
          ? RunFinishReason.contextLimit
          : RunFinishReason.modelError;
      _turnParts = [...parts, TextPart(text: failure.userMessage)];
      await _settleAttempt(ModelRequestStatus.failed, () async {
        await repository.updateMessage(
          messageId: assistantMessage.id,
          parts: _turnParts,
          status: MessageStatus.failed,
          thinkingDurationMs: _turnThinkingDurationMs,
        );
      });
      return StreamedTurn(
        messageId: assistantMessage.id,
        parts: _turnParts,
        toolCalls: const [],
        failed: true,
      );
    }

    if (parts.isEmpty && toolCalls.isEmpty) {
      // 网关用非 SSE 错误体（HTTP 200 + JSON）时会空跑结束，明确报错。
      _turnFailure = RunFinishReason.emptyResponse;
      _turnParts = const [TextPart(text: '服务商返回了空响应，请检查模型名称与推理等级设置')];
      await _settleAttempt(ModelRequestStatus.failed, () async {
        await repository.updateMessage(
          messageId: assistantMessage.id,
          parts: _turnParts,
          status: MessageStatus.failed,
        );
      });
      return StreamedTurn(
        messageId: assistantMessage.id,
        parts: _turnParts,
        toolCalls: const [],
        failed: true,
      );
    }

    final records = [
      for (final call in toolCalls)
        ToolCallRecord(
          id: call.recordId!,
          runId: run.id,
          assistantMessageId: assistantMessage.id,
          providerCallId: call.callId,
          toolName: call.toolName,
          source: _registry!.byName(call.toolName)?.source,
          arguments: call.arguments,
          providerData: call.providerData,
          target: _registry!
              .byName(call.toolName)
              ?.describeAction(call.arguments),
          channel:
              _registry!.byName(call.toolName)?.channel ?? ExecutionChannel.app,
          defaultPolicy:
              _registry!.byName(call.toolName)?.defaultPolicy ??
              ToolPolicy.deny,
          status: call.argumentsError == null
              ? ToolCallStatus.prepared
              : ToolCallStatus.failed,
          result: call.argumentsError,
          errorCode: call.argumentsError == null ? null : 'invalidArguments',
          createdAt: DateTime.now(),
          finishedAt: call.argumentsError == null ? null : DateTime.now(),
        ),
    ];
    var callIndex = 0;
    _turnParts = [
      for (final part in _liveParts)
        if (part.kind == PartKind.toolCall)
          ToolCallPart(
            toolCallId: records[callIndex++].id,
            providerData: part.providerData,
          )
        else if (part.kind != PartKind.provider &&
            (part.buffer.isNotEmpty || part.providerData != null))
          part.toPart(),
    ];
    await _settleAttempt(ModelRequestStatus.completed, () async {
      await repository.completeToolTurn(
        messageId: assistantMessage.id,
        runId: run.id,
        parts: _turnParts,
        calls: records,
        thinkingDurationMs: _turnThinkingDurationMs,
      );
    });
    return StreamedTurn(
      messageId: assistantMessage.id,
      parts: _turnParts,
      toolCalls: toolCalls,
    );
  }

  int _attemptIndex = 1;
  Future<void> _settleAttempt(
    ModelRequestStatus status,
    Future<void> Function() persist,
  ) => _requests!.settle(
    _requestId!,
    status: status,
    usage: _turnUsage,
    revision: _usageRevision,
    usageComplete: _responseComplete && _turnUsage != null,
    responseModelId: _responseModelId,
    errorCode:
        _streamError?.category.name ??
        (status == ModelRequestStatus.failed ? _turnFailure?.name : null),
    persistResult: persist,
  );

  /// 执行一次工具调用：记录 → 结果消息 → 结果进入下一轮上下文。
  @override
  Future<ExecutedTool> executeTool(ToolCall call, StreamedTurn turn) async {
    final run = _run!;
    final cancellation = _cancellation!;
    final repository = _repository!;

    if (call.recordId == null) throw const OperationFailure('调用尚未持久化，不能执行');
    final channel =
        _registry!.byName(call.toolName)?.channel ?? ExecutionChannel.app;
    final executed = await _executor!.execute(
      ToolExecutionRequest(
        runId: run.id,
        assistantMessageId: turn.messageId,
        toolName: call.toolName,
        arguments: call.arguments,
        channel: channel,
        conversationId: run.conversationId,
        attachments: await _storage!.attachments(run.conversationId),
        workspaceDirectory: run.configuration.workspace?.rootPath ?? '',
        storage: _storage!,
        enabledTools: run.configuration.enabledTools,
        toolPolicies: run.configuration.toolPolicies,
        providerCallId: call.callId,
        providerData: call.providerData,
        recordId: call.recordId,
      ),
      cancellation,
      onProgress: (message) {
        if (!ref.mounted || cancellation.isCancelled) return;
        ref
            .read(executionControllerProvider.notifier)
            .updateActivity(
              run.id,
              ref
                  .read(executionControllerProvider)
                  .activity
                  .upsert(
                    TaskMessage(
                      id: 'tool/${call.recordId}',
                      kind: TaskPanelMessageKind.tool,
                      label: '正在${ToolPresentation.toolLabel(call.toolName)}',
                      text:
                          '${_toolActivity(_registry!.byName(call.toolName)!, call.arguments)}\n${panelExcerpt(message, limit: 160)}',
                    ),
                  ),
            );
      },
    );
    final record = executed.record;
    if (run.configuration.mode == AgentMode.plan &&
        record.toolName == 'submit_plan' &&
        record.status == ToolCallStatus.succeeded) {
      _submittedPlan = true;
    }
    final label = ToolPresentation.recordLabel(record);
    final status = switch (record.status) {
      ToolCallStatus.succeeded =>
        '执行了${record.toolName == 'shell' ? '命令' : label}',
      ToolCallStatus.rejected => '已拒绝$label',
      ToolCallStatus.cancelled => '已取消$label',
      _ => '$label失败',
    };
    final previousActivity = ref.read(executionControllerProvider).activity;
    ref
        .read(executionControllerProvider.notifier)
        .updateActivity(
          run.id,
          previousActivity
              .copyWith(
                phase: TaskPanelPhase.waitingModel,
                status: status,
                lastToolStatus: status,
              )
              .upsert(
                TaskMessage(
                  id: 'tool/${record.id}',
                  kind: TaskPanelMessageKind.tool,
                  label: status,
                  text:
                      previousActivity.messages
                          .where((entry) => entry.id == 'tool/${record.id}')
                          .firstOrNull
                          ?.text ??
                      (record.target ?? label),
                ),
              ),
        );
    if (record.status == ToolCallStatus.succeeded ||
        record.artifacts.isNotEmpty) {
      await _registerArtifacts(
        run.conversationId,
        toolReported: record.artifacts.isNotEmpty,
      );
    }

    final content = toolResultText(record);
    // 结果消息接在本轮末尾之后：多个结果按执行顺序串成同一条分支。
    final message = ChatMessage(
      id: generateId(),
      conversationId: run.conversationId,
      parentId: _turnTailId ?? turn.messageId,
      runId: run.id,
      role: ChatRole.tool,
      status: MessageStatus.completed,
      parts: [
        ToolResultPart(toolCallId: record.id),
        TextPart(text: content),
      ],
      createdAt: DateTime.now(),
    );
    // 结果记录与结果消息在同一事务提交（design 第五部分 §3.3）。
    final saved = await repository.saveToolResult(
      toolCallId: record.id,
      message: message,
    );
    _turnTailId = message.id;
    return ExecutedTool(
      callId: call.callId,
      content: content,
      isError: saved.status != ToolCallStatus.succeeded,
      record: saved,
      messageId: message.id,
      finishRun: _submittedPlan,
    );
  }

  /// 本轮工具结果已回填：记录分支位置并清空待处理调用。
  @override
  Future<void> finishTurn(StreamedTurn turn) async {
    final run = _run;
    if (run == null) return;
    _run = await _runs!.finishTurn(
      run.id,
      currentMessageId: _turnTailId ?? turn.messageId,
    );
  }

  /// 运行终态：按原因写状态与结束原因（design 第二部分 §4）。
  @override
  Future<void> finish(AgentFinishReason reason) async {
    final run = _run;
    if (run == null || _runFinished) return;
    if (reason == AgentFinishReason.turnLimit) {
      // 工具结果不展示为正文；仅保存运行失败会看起来像模型正常完成。
      final message = ChatMessage(
        id: generateId(),
        conversationId: run.conversationId,
        parentId: _turnTailId ?? run.currentMessageId ?? run.inputMessageId,
        runId: run.id,
        role: ChatRole.assistant,
        status: MessageStatus.failed,
        parts: [
          TextPart(
            text:
                '应用已达到本次运行的 ${run.maxTurns} 轮上限，任务已停止，并不代表工作已完成。'
                '已执行的工具结果已保留，可发送“继续”接着处理。',
          ),
        ],
        modelLabel: _selection?.model,
        createdAt: DateTime.now(),
      );
      await _repository!.appendMessage(message);
      _turnTailId = message.id;
    }
    final (RunStatus, RunFinishReason?) result = switch (reason) {
      // 本轮以错误或空回复收场时，运行按具体原因失败。
      AgentFinishReason.completed =>
        _turnFailure == null
            ? (RunStatus.completed, RunFinishReason.completed)
            : (RunStatus.failed, _turnFailure),
      AgentFinishReason.cancelled => (
        RunStatus.stopped,
        RunFinishReason.cancelled,
      ),
      AgentFinishReason.turnLimit => (
        RunStatus.failed,
        RunFinishReason.turnLimit,
      ),
    };
    return _finishRun(result.$1, result.$2);
  }

  /// 运行终态只写一次：循环收口与异常收尾共用。
  Future<void> _finishRun(
    RunStatus status,
    RunFinishReason? finishReason,
  ) async {
    final run = _run;
    if (run == null || _runFinished) return;
    _run = await _runs!.finish(
      run.id,
      status: status,
      finishReason: finishReason,
      currentMessageId: _turnTailId,
    );
    _runFinished = true;
  }

  /// 请求用户确认：等待期间运行记 awaitingConfirmation 与待确认调用。
  ///
  /// 应用级控制器持有待确认请求；页面销毁/移交不改变决定或原期限。
  /// 到期按拒绝，停止由执行器按取消收口。
  Future<ToolDecision> _confirmToolCall(ToolConfirmationRequest request) async {
    final run = _run;
    if (run != null) {
      _run = await _runs!.awaitConfirmation(run.id, request.record.id);
    }
    final cancellation = _cancellation;
    if (cancellation == null) return ToolDecision.expired;
    return ref
        .read(executionControllerProvider.notifier)
        .confirm(request, cancellation);
  }

  Future<void> _waitForUser(
    ToolContext context,
    String prompt,
    RunCancellation cancellation,
  ) async {
    _run = await _runs!.awaitUser(context.runId, context.toolCallId);
    await ref
        .read(executionControllerProvider.notifier)
        .waitForUser(
          UserActionRequest(
            runId: context.runId,
            toolCallId: context.toolCallId,
            prompt: prompt,
          ),
          cancellation,
        );
    cancellation.throwIfCancelled();
    _run = await _runs!.resume(context.runId);
  }

  /// 停止生成：结束本轮模型请求与正在进行的工具执行。
  ///
  /// 等待确认中停止不执行动作（记录 cancelled）；执行中停止请求工具取消，
  /// 工具实际返回的结果如实记录（design 第二部分 §6）。
  void stop() {
    if (_cancellation == null) return;
    _finishThinking();
    _stoppedManually = true;
    _cancellation?.cancel();
    _acceptingChunks = false;
    _completeRequest();
  }

  void _completeRequest() {
    final done = _doneCompleter;
    if (done != null && !done.isCompleted) done.complete();
  }

  /// 重试当前模型轮：请求上下文固定，先保存失败尝试再退避，不重放工具。
  Future<StreamedTurn> _requestWithRetry(
    ChatModelSelection selection,
    List<ResolvedMessage> messages, {
    required String? parentId,
  }) async {
    final apiKey = selection.profile.requiresKey
        ? await ref.read(secureKeyStorageProvider).read(selection.profile.id) ??
              ''
        : '';
    final provider = ref.read(aiProviderFactoryProvider)(
      selection.profile,
      apiKey,
    );
    // 模型参数来自该模型的配置；未设置时不下发，由服务端默认决定。
    final modelConfig = selection.profile.models
        .where((model) => model.id == selection.model)
        .firstOrNull;
    final systemPrompt = contextSystemPrompt(_run!.configuration);
    final tools = _toolDefinitions();
    ContextBuild context;
    try {
      context = await _buildContext(provider, messages, systemPrompt, tools);
    } on OperationFailure catch (failure) {
      if (isCancelled) {
        return StreamedTurn(
          messageId: parentId ?? '',
          parts: const [],
          toolCalls: const [],
          cancelled: true,
        );
      }
      final message = ChatMessage(
        id: generateId(),
        conversationId: _run!.conversationId,
        parentId: parentId,
        runId: _run!.id,
        role: ChatRole.assistant,
        status: MessageStatus.failed,
        parts: [TextPart(text: failure.userMessage)],
        createdAt: DateTime.now(),
      );
      await _repository!.appendMessage(message);
      _turnTailId = message.id;
      _turnFailure = RunFinishReason.contextLimit;
      return StreamedTurn(
        messageId: message.id,
        parts: message.parts,
        toolCalls: const [],
        failed: true,
      );
    }
    if (isCancelled) {
      return StreamedTurn(
        messageId: parentId ?? '',
        parts: const [],
        toolCalls: const [],
        cancelled: true,
      );
    }
    if (ref.mounted) {
      state = state.copyWith(
        contextBuild: context,
        contextConversationId: _run!.conversationId,
      );
    }
    var request =
        context.preparedRequest ??
        ChatRequest(
          modelId: selection.model,
          systemPrompt: systemPrompt,
          messages: context.messages,
          tools: tools,
          // 模型不支持推理时不下发任何推理字段。
          reasoningEffort: selection.supportsReasoning
              ? selection.effort
              : ReasoningEffort.off,
          temperature: modelConfig?.temperature,
          maxOutputTokens: modelConfig?.maxOutputTokens,
        );

    final policy = ref.read(modelRetryPolicyProvider);
    var recoveredContext = false;
    for (var attempt = 0; ; attempt++) {
      _attemptIndex = attempt + 1;
      final turn = await _streamAttempt(provider, request, parentId: parentId);
      if (isCancelled || turn.cancelled) return turn;
      final error = _streamError;
      if (error == null) return turn;
      if (error.category == ProviderErrorCategory.contextLimit &&
          !recoveredContext) {
        recoveredContext = true;
        final previousGeneration = context.measurement?.generation;
        try {
          context = await _buildContext(
            provider,
            messages,
            systemPrompt,
            tools,
            force: true,
          );
        } on OperationFailure {
          return turn;
        }
        if (isCancelled ||
            context.measurement?.generation == previousGeneration) {
          return turn;
        }
        request = context.preparedRequest!;
        if (ref.mounted) state = state.copyWith(contextBuild: context);
        continue;
      }
      final delay = policy.delayFor(error, attempt + 1);
      if (delay == null) return turn;
      if (ref.mounted) {
        state = state.copyWith(
          retry: ModelRetryState(
            attempt: attempt + 1,
            maxRetries: policy.maxRetries,
            delay: delay,
          ),
        );
        ref
            .read(executionControllerProvider.notifier)
            .updateActivity(
              _run!.id,
              ref
                  .read(executionControllerProvider)
                  .activity
                  .copyWith(
                    phase: TaskPanelPhase.waitingModel,
                    status: '等待自动重试 ${attempt + 1}/${policy.maxRetries}',
                  ),
            );
      }
      await waitForModelRetry(delay, _cancellation!);
      if (ref.mounted) state = state.copyWith(clearRetry: true);
      if (isCancelled) return turn;
    }
  }

  Future<ContextBuild> _buildContext(
    AiProvider provider,
    List<ResolvedMessage> messages,
    String system,
    List<ToolDefinition> tools, {
    bool force = false,
  }) async {
    final run = _run!;
    final repository = await ref.read(agentContextRepositoryProvider.future);
    final context =
        await CompactionCoordinator(
          summaries: repository,
          requests: _requests!,
        ).build(
          conversationId: run.conversationId,
          runId: run.id,
          branchHeadId: (await _repository!.getThread(run.conversationId))!
              .currentMessageId!,
          profile: _selection!.profile,
          provider: provider,
          request: ChatRequest(
            modelId: _selection!.model,
            messages: messages,
            systemPrompt: system,
            tools: tools,
            reasoningEffort: run.configuration.supportsReasoning
                ? run.configuration.modelSelection.reasoningEffort
                : ReasoningEffort.off,
            temperature: run.configuration.modelSelection.temperature,
            maxOutputTokens: run.configuration.modelSelection.maxOutputTokens,
          ),
          cancellation: _cancellation!,
          protectedIds: {
            run.inputMessageId,
            ?messages
                .where((m) => m.role == ChatRole.user)
                .lastOrNull
                ?.sourceMessageId,
          },
          canReadHistory: tools.any((t) => t.name == 'read_history'),
          canReadHistoryNow: () => _historyAllowed(tools, run.assistantId),
          reloadMessages: () async {
            final thread = await _repository!.getThread(run.conversationId);
            return thread == null
                ? const []
                : _resolveHistory(
                    thread.branch,
                    _runAttachments,
                    currentModelId: _selection!.model,
                  );
          },
          contextWindow: run.configuration.contextWindow,
          windowSource: run.configuration.resolvedWindowSource,
          catalogMaxOutputTokens: run.configuration.catalogMaxOutputTokens,
          policy: run.configuration.contextPolicy,
          force: force,
          onSummarizing: (value) {
            if (ref.mounted) state = state.copyWith(summarizing: value);
          },
        );
    _measurement = context.measurement;
    return context;
  }

  Future<bool> _historyAllowed(
    List<ToolDefinition> tools,
    String? assistantId,
  ) async {
    if (!tools.any((t) => t.name == 'read_history')) return false;
    if (assistantId == null) return true;
    final assistant = await (await ref.read(assistantRepositoryProvider.future))
        .getById(assistantId);
    return assistant != null &&
        assistant.toolPolicy.overrides['read_history'] != ToolPolicy.deny;
  }

  /// 订阅一次请求的事件流，直到结束、出错或被停止。
  Future<void> _consume(AiProvider provider, ChatRequest request) async {
    if (isCancelled) return;
    await _requests!.start(
      _requestId!,
      onStart: () async {
        _run = await _runs!.countModelAttempt(_run!.id);
      },
    );
    if (isCancelled) {
      await _requests!.cancelBeforeStart(_requestId!, undoAttempt: true);
      return;
    }
    final done = Completer<void>();
    StreamSubscription<ChatChunk>? subscription;
    _doneCompleter = done;
    _acceptingChunks = true;
    try {
      subscription = provider
          .streamChat(request)
          .listen(
            (chunk) {
              if (identical(_doneCompleter, done)) _onChunk(chunk);
            },
            onError: (Object error, StackTrace stackTrace) {
              if (!_acceptingChunks || !identical(_doneCompleter, done)) return;
              _acceptingChunks = false;
              _finishThinking();
              if (error is StorageFailure) {
                if (!done.isCompleted) done.completeError(error, stackTrace);
              } else {
                _streamError = mapProviderException(error);
                if (!done.isCompleted) done.complete();
              }
            },
            onDone: () {
              _finishThinking();
              if (!done.isCompleted) done.complete();
            },
            cancelOnError: true,
          );
      _subscription = subscription;
      await done.future;
    } on StorageFailure {
      rethrow;
    } catch (error) {
      _streamError = mapProviderException(error);
    } finally {
      _acceptingChunks = false;
      _finishThinking();
      try {
        await subscription?.cancel();
      } catch (error) {
        if (!isCancelled && !_responseComplete) {
          _streamError ??= mapProviderException(error);
        }
        AppLogger.warning('模型流清理失败');
      }
      if (identical(_subscription, subscription)) _subscription = null;
      if (identical(_doneCompleter, done)) _doneCompleter = null;
    }
  }

  /// 本次运行下发的工具定义：助手策略与模型工具能力都满足才下发。
  List<ToolDefinition> _toolDefinitions() {
    final selection = _selection;
    final run = _run;
    final registry = _registry;
    if (selection == null || run == null || registry == null) return const [];
    if (!selection.supportsTools) return const [];
    return registry.definitionsFor({
      for (final name in run.configuration.enabledTools)
        if (run.configuration.mode != AgentMode.plan ||
            (registry.byName(name) != null &&
                allowedInPlan(registry.byName(name)!)))
          name,
    }, run.configuration.toolPolicies);
  }

  /// 本轮的工具调用：完整响应结束后才解析参数片段。
  List<ToolCall> _toolCallsFromLive() {
    final calls = <ToolCall>[];
    for (final part in _liveParts) {
      if (part.kind != PartKind.toolCall) continue;
      final parsed = _parseToolArguments(part.buffer.toString());
      calls.add(
        ToolCall(
          callId: part.callId ?? part.partId,
          toolName: part.toolName ?? '',
          arguments: parsed.arguments,
          argumentsError: parsed.error,
          providerData: part.providerData,
          recordId: generateId(),
        ),
      );
    }
    return calls;
  }

  /// 解析工具参数：不完整或不是 JSON 对象的片段如实报错，
  /// 不从正文里提取命令「就近执行」。
  ({Map<String, dynamic> arguments, String? error}) _parseToolArguments(
    String fragment,
  ) {
    final text = fragment.trim();
    // 无参数的工具不会给出参数片段。
    if (text.isEmpty) return (arguments: const {}, error: null);
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      return (arguments: const {}, error: '工具参数不是完整的 JSON，本次调用未执行；请重新给出完整参数');
    }
    if (decoded is Map<String, dynamic>) {
      return (arguments: decoded, error: null);
    }
    return (arguments: const {}, error: '工具参数必须是 JSON 对象，本次调用未执行');
  }

  /// 产物登记与附件索引刷新：写文件产生的产物要出现在会话附件里。
  ///
  /// [toolReported] 表示工具自己已登记并引用了产物（不会出现在待登记扫描里），
  /// 索引同样要刷新，否则卡片与气泡查不到这份文件。
  Future<void> _registerArtifacts(
    String conversationId, {
    bool toolReported = false,
  }) async {
    final storage = _storage;
    if (storage == null) return;
    try {
      final registered = await storage.registerPendingArtifacts(conversationId);
      if (registered.isEmpty && !toolReported) return;
      _runAttachments = await _attachmentIndex(conversationId, const []);
      if (ref.read(activeConversationProvider).conversationId ==
          conversationId) {
        state = state.copyWith(attachments: _runAttachments);
      }
    } on Failure {
      rethrow;
    } on Exception {
      throw const OperationFailure('产物登记失败，请处理后再继续任务');
    }
  }

  void _onChunk(ChatChunk chunk) {
    if (!_acceptingChunks || isCancelled || !ref.mounted) return;
    switch (chunk) {
      case PartStart():
        if (chunk.kind == PartKind.toolCall) {
          _finishThinking();
          _liveParts.add(_LivePart.toolCall(chunk.partId));
        } else if (chunk.kind == PartKind.provider) {
          _liveParts.add(_LivePart.provider(chunk.partId));
        } else {
          final part = _LivePart(chunk.partId, chunk.kind);
          if (chunk.initialContent?.isNotEmpty == true) {
            part.buffer.write(chunk.initialContent);
            _markProgress(part);
          }
          _liveParts.add(part);
        }
      case TextDelta():
        _livePart(chunk.partId, PartKind.text).buffer.write(chunk.text);
        if (chunk.text.isNotEmpty) _finishThinking();
      case ReasoningDelta():
        final part = _livePart(chunk.partId, PartKind.reasoning);
        part.buffer.write(chunk.text);
        if (chunk.text.isNotEmpty) _markProgress(part);
      case ToolCallDelta():
        _finishThinking();
        final part = _livePart(chunk.partId, PartKind.toolCall);
        part.callId = chunk.callId ?? part.callId;
        part.toolName = chunk.toolName ?? part.toolName;
        // 参数片段只累积；完整响应结束后才解析，不逐段解析。
        if (chunk.argumentsFragment != null) {
          part.buffer.write(chunk.argumentsFragment);
        }
      case PartEnd():
        final part = _liveParts.where((entry) => entry.partId == chunk.partId);
        if (part.isEmpty) break;
        // 完整块以协议收口结果为准。
        switch (chunk.part) {
          case TextPart(:final text):
            part.first.buffer
              ..clear()
              ..write(text);
            if (text.isNotEmpty) _finishThinking();
          case ReasoningPart(:final publicText, :final providerData):
            part.first.buffer
              ..clear()
              ..write(publicText);
            part.first.providerData = providerData ?? part.first.providerData;
            if (publicText.isNotEmpty) _markProgress(part.first);
            part.first.finishThinking();
          case ToolCallPart(:final toolCallId, :final providerData):
            // 协议收口的调用 id 是回填配对的依据。
            part.first.callId = toolCallId;
            part.first.providerData = providerData ?? part.first.providerData;
          default:
            break;
        }
      case UsageChunk(:final usage):
        _turnUsage = usage;
        _usageRevision++;
      case ResponseModel(:final modelId):
        _responseModelId = modelId;
        _usageRevision++;
      case ResponseEnd(:final complete):
        _finishThinking();
        _responseComplete = complete;
        if (!complete) {
          _streamError = const ProviderError(
            ProviderErrorCategory.incompleteResponse,
            'response ended before completion',
          );
        }
        _acceptingChunks = false;
        _completeRequest();
      case ResponseError(:final error):
        _finishThinking();
        // 流内错误即本次响应结束：保留已收内容，按失败收口。
        _streamError = error;
        _acceptingChunks = false;
        _completeRequest();
    }
    _scheduleFlush();
  }

  _LivePart _livePart(String partId, PartKind kind) {
    for (final part in _liveParts) {
      if (part.partId == partId) return part;
    }
    final part = _LivePart(partId, kind);
    _liveParts.add(part);
    return part;
  }

  void _markProgress(_LivePart part) {
    switch (part.kind) {
      case PartKind.reasoning:
        if (part.thinkingStartedAt != null) return;
        _finishThinking();
        part.thinkingStartedAt = DateTime.now();
      case PartKind.text:
        _finishThinking();
      default:
        break;
    }
  }

  void _finishThinking() {
    for (final part in _liveParts) {
      part.finishThinking();
    }
  }

  int? get _currentThinkingDurationMs {
    int? total;
    for (final part in _liveParts) {
      final duration = part.currentThinkingDurationMs;
      if (duration != null) total = (total ?? 0) + duration;
    }
    return total;
  }

  void _scheduleFlush() {
    _publishTimer ??= Timer(_publishInterval, _publishNow);
    _flushTimer ??= Timer(_flushInterval, _flushNow);
  }

  /// 把累积的流式内容合批发布到界面；定时器停在这里，下一次增量再起。
  void _publishNow() {
    _publishTimer = null;
    if (_liveParts.isEmpty || !ref.mounted) return;
    state = state.copyWith(streamingParts: _partsFromLive(_liveParts));
    final runId = _run?.id;
    if (runId == null || isCancelled) return;
    final visible = _liveParts.where((part) => part.buffer.isNotEmpty);
    final last = visible.lastOrNull;
    final phase = switch (last?.kind) {
      PartKind.reasoning => TaskPanelPhase.thinking,
      PartKind.text => TaskPanelPhase.responding,
      PartKind.toolCall => TaskPanelPhase.preparingTool,
      _ => TaskPanelPhase.waitingModel,
    };
    final activity = ref.read(executionControllerProvider).activity;
    final messageId = _streamingMessageId;
    if (messageId == null) return;
    final parts = [
      for (final part in _liveParts)
        if ((part.kind == PartKind.reasoning || part.kind == PartKind.text) &&
            part.buffer.isNotEmpty)
          TaskMessage(
            id: '$messageId/${part.partId}',
            kind: part.kind == PartKind.reasoning
                ? TaskPanelMessageKind.reasoning
                : TaskPanelMessageKind.text,
            label: part.kind == PartKind.reasoning ? '思考' : '相月',
            text: part.buffer.toString(),
          ),
    ];
    ref
        .read(executionControllerProvider.notifier)
        .updateActivity(
          runId,
          activity
              .replaceResponse(messageId, parts)
              .copyWith(
                phase: phase,
                status: switch (phase) {
                  TaskPanelPhase.thinking => '正在思考',
                  TaskPanelPhase.responding => '正在回复',
                  TaskPanelPhase.preparingTool => '正在准备工具调用',
                  _ => activity.waitingStatus,
                },
              ),
        );
  }

  /// 收口前把最后一批增量立即发布，界面不会停在半句话上。
  void _publishImmediately() {
    _publishTimer?.cancel();
    _publishTimer = null;
    _publishNow();
  }

  void _flushNow() {
    _flushTimer = null;
    final messageId = _streamingMessageId;
    if (messageId == null) return;
    final parts = _partsFromLive(_liveParts);
    final thinkingDuration = _currentThinkingDurationMs;
    final requestId = _requestId;
    final usage = _turnUsage;
    final revision = _usageRevision;
    final responseModel = _responseModelId;
    _pendingFlush = _pendingFlush.then((_) async {
      if (_flushFailure != null) return;
      try {
        if (requestId != null) {
          await _requests!.sample(
            requestId,
            usage,
            revision,
            responseModelId: responseModel,
          );
        }
        await _repository!.updateMessage(
          messageId: messageId,
          parts: parts,
          status: MessageStatus.streaming,
          thinkingDurationMs: thinkingDuration,
        );
      } on Failure catch (error) {
        _flushFailure = error;
        _acceptingChunks = false;
        _completeRequest();
      }
    });
  }

  Future<List<ResolvedMessage>> _resolveHistory(
    List<ChatMessage> messages,
    Map<String, Attachment> attachments, {
    required String currentModelId,
  }) => HistoryResolver(
    repository: _repository!,
    runs: _runs!,
    profile: _selection!.profile,
    registry: _registry!,
  ).resolve(messages, attachments, currentModelId: currentModelId);

  Future<Map<String, ToolCallRecord>> _recordsFor(List<ChatMessage> messages) =>
      historyRecords(_repository!, messages);

  Future<Map<String, Attachment>> _attachmentIndex(
    String conversationId,
    List<Attachment> justAdded,
  ) async {
    final repository = await ref.read(conversationRepositoryProvider.future);
    final stored = await repository.attachmentsFor(conversationId);
    return {
      for (final attachment in stored) attachment.id: attachment,
      for (final attachment in justAdded) attachment.id: attachment,
    };
  }
}

/// 流式期间的块缓冲；落库时转换成正式 Part。
class _LivePart {
  _LivePart(this.partId, this.kind);

  _LivePart.toolCall(this.partId)
    : kind = PartKind.toolCall,
      callId = null,
      toolName = null;

  _LivePart.provider(this.partId) : kind = PartKind.provider;

  final String partId;
  final PartKind kind;
  final StringBuffer buffer = StringBuffer();
  String? callId;
  String? toolName;
  DateTime? thinkingStartedAt;
  int? thinkingDurationMs;

  int? get currentThinkingDurationMs {
    final started = thinkingStartedAt;
    if (started == null) return null;
    final elapsed = DateTime.now().difference(started).inMilliseconds;
    return thinkingDurationMs ?? (elapsed < 0 ? 0 : elapsed);
  }

  void finishThinking() {
    thinkingDurationMs ??= currentThinkingDurationMs;
  }

  /// 协议块收口时带回来的状态：思考签名、加密推理、工具签名等。
  /// 它必须落在消息里，否则下一轮无法原样回传（design 第五部分 §4.3）。
  Map<String, dynamic>? providerData;

  MessagePart toPart() {
    final text = buffer.toString();
    return switch (kind) {
      PartKind.text => TextPart(text: text, partId: partId),
      PartKind.reasoning => ReasoningPart(
        publicText: text,
        partId: partId,
        providerData: providerData,
        startedAt: thinkingStartedAt,
        durationMs: thinkingDurationMs,
      ),
      // 工具调用以 ToolCallPart（引用记录 id）补进消息，协议块不落库。
      PartKind.toolCall ||
      PartKind.provider => TextPart(text: '', partId: partId),
    };
  }
}

/// 把流式缓冲转成消息内容块；空块不进入结果。
///
/// 只有协议状态的块（redacted thinking、只带回加密载荷的推理）也算内容：
/// 它们没有可展示的文本，但缺了就没法回传。
List<MessagePart> _partsFromLive(List<_LivePart> liveParts) {
  return [
    for (final part in liveParts)
      if (part.kind != PartKind.toolCall &&
          part.kind != PartKind.provider &&
          (part.buffer.isNotEmpty || part.providerData != null))
        part.toPart(),
  ];
}

String _toolActivity(Tool tool, Map<String, dynamic> arguments) =>
    tool.name == 'shell'
    ? '\$ ${panelExcerpt(arguments['command'] as String? ?? '', limit: 300)}'
    : panelExcerpt(tool.describeAction(arguments), limit: 300);

/// 内置工具集：文件工具只访问应用私有目录，HTTP 工具走独立的 Dio 实例。
///
/// 单独开注入点是为了让测试能替换工具集（记录调用的假工具、替代网络实现），
/// 与 [aiProviderFactoryProvider] 同样的理由。
@Riverpod(keepAlive: true)
ToolRegistry toolRegistry(Ref ref) {
  final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 15)));
  ref.onDispose(() => dio.close(force: true));
  return buildBuiltInRegistry(
    platform: () => ref.read(channelDriverProvider),
    httpFetch: (request) => fetchToolHttp(dio, request),
  );
}

/// 单一重试预算，协议传输不再叠加第二层自动重试。
@Riverpod(keepAlive: true)
ModelRetryPolicy modelRetryPolicy(Ref ref) => const ModelRetryPolicy();

/// 工具运行的存储能力：会话附件、按会话隔离的产物目录与产物登记。
///
/// 附件索引由仓储注入：数据源只依赖模型与文件系统。
@Riverpod(keepAlive: true)
Future<ArtifactStorage> artifactStorage(Ref ref) async {
  final attachments = await ref.watch(attachmentStorageProvider.future);
  final repository = await ref.watch(conversationRepositoryProvider.future);
  return ArtifactStorage(
    root: attachments.root,
    loadAttachments: repository.attachmentsFor,
    saveAttachment: repository.saveAttachment,
  );
}

/// 会话列表流（置顶优先、按更新时间倒序）。
@riverpod
Stream<List<Conversation>> conversations(Ref ref) async* {
  final repository = await ref.watch(conversationRepositoryProvider.future);
  yield* repository.watchConversations();
}

/// 某会话的当前分支视图。
@riverpod
Stream<ConversationThread?> conversationThread(
  Ref ref,
  String conversationId,
) async* {
  final repository = await ref.watch(conversationRepositoryProvider.future);
  yield* repository.watchThread(conversationId);
}

/// 视图展示的消息：当前分支 + 流式中的最后一条回答，同一次运行合并为回答区。
///
/// [thread] 来自 repository 的 watch 流，是持久化事实；
/// [state] 只提供尚未落库的流式内容。
///
/// 工具结果消息（role: tool）是回填给模型的上下文，不作为对话正文展示：
/// 调用与结果由助手消息里的 [ToolCallPart] 引用记录、以工具卡片渲染，
/// 模型提出的调用与执行结果不冒充助手回答。
///
/// 工具循环每轮落一条助手消息（数据层如此，协议回填依赖它），这里把属于
/// 同一次运行的连续助手消息合并成一个回答区：用户看到一次发送产生一个连贯
/// 回答，工具卡片留在回答区里（按 Part 顺序渲染）。合并只发生在视图层，
/// 不改写任何落库内容。
List<ChatMessage> visibleMessages(ConversationThread thread, ChatState state) {
  // 流式内容覆盖的是当前分支末尾那条助手消息（本次运行正在写入的行）。
  // 分支末尾是隐藏的结果消息时不覆盖：那时流式内容属于上一轮，覆盖已落库的
  // 助手消息会把它的工具卡片抹掉。
  final streaming = state.isGenerating && state.streamingParts.isNotEmpty;
  final tail = thread.branch.length - 1;
  final visible = <ChatMessage>[];
  for (var index = 0; index <= tail; index++) {
    final message = thread.branch[index];
    if (message.role == ChatRole.tool) continue;
    final live =
        streaming &&
        index == tail &&
        message.role == ChatRole.assistant &&
        message.id == state.streamingMessageId;
    visible.add(
      live
          ? message.copyWith(
              parts: state.streamingParts,
              status: MessageStatus.streaming,
            )
          : message,
    );
  }
  return _mergeAnswerRuns(visible);
}

/// 合并工具轮之前，把仅含一个公开思考块的消息总耗时归还给该块。
/// 多块且没有逐块计时的记录无法拆分，不把整轮耗时冒充任一段的时间。
ChatMessage _withRecordedThinkingDuration(ChatMessage message) {
  final duration = message.thinkingDurationMs;
  if (duration == null || message.status == MessageStatus.streaming) {
    return message;
  }
  final reasoning = message.parts
      .whereType<ReasoningPart>()
      .where((part) => part.publicText.isNotEmpty)
      .toList();
  if (reasoning.length != 1 || reasoning.single.durationMs != null) {
    return message;
  }
  final part = reasoning.single;
  return message.copyWith(
    parts: [
      for (final entry in message.parts)
        if (identical(entry, part))
          ReasoningPart(
            publicText: part.publicText,
            partId: part.partId,
            providerData: part.providerData,
            startedAt: part.startedAt,
            durationMs: duration,
          )
        else
          entry,
    ],
  );
}

/// 把同一次运行的连续助手消息合并为一个回答区。
///
/// 只看相邻两条：中间夹着用户消息（另一次运行的输入）或 runId 不同
/// （重新生成产生的新回答与旧回答）都不合并；runId 为 null 的老消息
/// 彼此相邻时按同一次运行处理。
List<ChatMessage> _mergeAnswerRuns(List<ChatMessage> messages) {
  final merged = <ChatMessage>[];
  for (final message in messages) {
    final previous = merged.isEmpty ? null : merged.last;
    if (previous != null &&
        previous.role == ChatRole.assistant &&
        message.role == ChatRole.assistant &&
        previous.runId == message.runId) {
      merged[merged.length - 1] = _mergeAnswers(previous, message);
      continue;
    }
    merged.add(message);
  }
  return merged;
}

/// 两条同一次运行的助手消息合并成一条渲染用消息。
///
/// 身份沿用首条：流式期间新增一轮不会重建气泡，阅读位置与思考面板的
/// 手动展开状态都保留。状态取最后一次终态，任一还在流式则按流式展示
/// （生成光标留在回答区末尾）；用量取最后一次有值的；思考耗时按各轮合计。
ChatMessage _mergeAnswers(ChatMessage head, ChatMessage tail) {
  head = _withRecordedThinkingDuration(head);
  tail = _withRecordedThinkingDuration(tail);
  final headThinking = head.thinkingDurationMs;
  final tailThinking = tail.thinkingDurationMs;
  return ChatMessage(
    id: head.id,
    conversationId: head.conversationId,
    parentId: head.parentId,
    runId: head.runId,
    role: head.role,
    status: head.status == MessageStatus.streaming
        ? MessageStatus.streaming
        : tail.status,
    parts: _mergeAnswerParts(head, tail),
    // 一次运行内模型不会更换：模型名取第一条有值的。
    modelLabel: head.modelLabel ?? tail.modelLabel,
    usage: tail.usage ?? head.usage,
    thinkingDurationMs: headThinking == null
        ? tailThinking
        : (tailThinking == null ? headThinking : headThinking + tailThinking),
    createdAt: head.createdAt,
  );
}

/// 拼接两条消息的内容块，保持各自的 Part 顺序。
///
/// 只在正文接正文时补一个空行：两轮正文直接相连会被渲染成一段。思考不补——
/// 每轮思考各自成区，工具调用或正文天然把它们隔开。
List<MessagePart> _mergeAnswerParts(ChatMessage head, ChatMessage tail) {
  final parts = [...head.parts];
  if (tail.parts.isNotEmpty &&
      parts.isNotEmpty &&
      parts.last is TextPart &&
      tail.parts.first is TextPart) {
    parts.add(const TextPart(text: '\n\n'));
  }
  return [...parts, ...tail.parts];
}

/// 助手列表；先确保内置助手存在再发出。
@Riverpod(keepAlive: true)
Stream<List<Assistant>> assistants(Ref ref) async* {
  if (!ref.mounted) return;
  final repository = await ref.watch(assistantRepositoryProvider.future);
  if (!ref.mounted) return;
  await repository.ensureDefault();
  if (!ref.mounted) return;
  yield* repository.watchAssistants();
}

/// 当前生效的助手。
///
/// 已打开的会话用会话绑定的助手；新会话用草稿助手；两者都没有、
/// 或绑定的助手已被删除时回退到列表第一个（内置助手）。
///
/// 只读内存中的列表与线程：调用方先 await 好这两路数据（见
/// [awaitAssistantContext]），避免把「尚未加载」误判成「没有助手」。
@Riverpod(keepAlive: true, dependencies: [assistants, conversationThread])
Assistant? currentAssistant(Ref ref, ActiveConversationState active) {
  final assistants = ref.watch(assistantsProvider).value ?? const <Assistant>[];
  final conversationId = active.conversationId;
  final bound = conversationId == null
      ? null
      : ref
            .watch(conversationThreadProvider(conversationId))
            .value
            ?.conversation
            .assistantId;
  return resolveAssistant(
    assistants,
    draftAssistantId: active.draftAssistantId,
    boundAssistantId: bound,
  );
}

/// 从助手列表里解析当前助手。
///
/// 优先级：本次会话显式选择（草稿）→ 会话绑定的助手 → 列表第一个。
/// 草稿在会话建立后继续代表「用户刚为这个会话选定的助手」，因此排在绑定的
/// 助手之前；下发到会话的绑定关系由 [ChatController.selectAssistant] 落库。
///
/// 发送（[awaitAssistantContext]）与模型选择共用这一处规则。
Assistant? resolveAssistant(
  List<Assistant> assistants, {
  String? draftAssistantId,
  String? boundAssistantId,
}) {
  if (assistants.isEmpty) return null;
  final wanted = draftAssistantId ?? boundAssistantId;
  if (wanted != null) {
    for (final assistant in assistants) {
      if (assistant.id == wanted) return assistant;
    }
  }
  return assistants.first;
}

/// 发送前的助手解析：先把列表等就绪，再按当前会话/草稿取助手。
///
/// 供 [ChatController.send] 使用；不使用 provider 的 `.value`，那样在流式
/// provider 已就绪时也可能读到 null。
Future<Assistant?> awaitAssistantContext(Ref ref) async {
  final assistants = await ref.read(assistantsProvider.future);
  if (assistants.isEmpty) return null;
  final active = ref.read(activeConversationProvider);
  var boundId = active.draftAssistantId;
  final conversationId = active.conversationId;
  if (conversationId != null) {
    final repository = await ref.read(conversationRepositoryProvider.future);
    final thread = await repository.getThread(conversationId);
    boundId = thread?.conversation.assistantId ?? boundId;
  }
  return resolveAssistant(
    assistants,
    draftAssistantId: active.draftAssistantId,
    boundAssistantId: boundId,
  );
}

/// 当前会话状态：会话 id 与新会话的助手、显式模型选择。
///
/// 单独成状态：会话选择既影响聊天控制器，也影响助手/模型解析，
/// 由它避免「选择依赖会话、会话依赖选择」的循环。
class ActiveConversationState {
  const ActiveConversationState({
    this.conversationId,
    this.draftAssistantId,
    this.draftModelSelection,
  });

  /// 当前打开的会话；null 表示新会话（尚未落库）。
  final String? conversationId;

  /// 本次会话显式选定的助手，切到其他会话时清空。
  final String? draftAssistantId;

  /// 新会话确认的模型选择；建会话时保存到 modelSelectionOverride。
  final model.ModelSelection? draftModelSelection;
}

@Riverpod(keepAlive: true)
class ActiveConversation extends _$ActiveConversation {
  @override
  ActiveConversationState build() => const ActiveConversationState();

  /// 打开某个已有会话；草稿助手不再需要。
  void open(String conversationId) {
    state = ActiveConversationState(conversationId: conversationId);
  }

  /// 回到新会话状态（或开始新的会话）。
  void clear() => state = const ActiveConversationState();

  /// 发送后新会话已有 id：记录它，并保留本次会话选定的助手。
  void adopt(String conversationId) {
    state = ActiveConversationState(
      conversationId: conversationId,
      draftAssistantId: state.draftAssistantId,
    );
  }

  /// 本次会话选定的助手（新会话尚未落库、或刚切换时）。
  void draftAssistant(String assistantId) {
    state = ActiveConversationState(
      conversationId: state.conversationId,
      draftAssistantId: assistantId,
      draftModelSelection: state.draftModelSelection,
    );
  }

  void draftModel(model.ModelSelection selection) {
    state = ActiveConversationState(
      conversationId: state.conversationId,
      draftAssistantId: state.draftAssistantId,
      draftModelSelection: selection,
    );
  }
}
