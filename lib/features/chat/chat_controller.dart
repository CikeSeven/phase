import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
import '../../../data/repositories/agent_run_repository.dart';
import '../../../data/repositories/assistant_repository.dart';
import '../../../data/repositories/conversation_repository.dart';
import '../../../data/repositories/tool_call_repository.dart';
import '../../../providers/ai_provider.dart';
import '../../../providers/provider_factory.dart';
import '../tools/agent_loop.dart';
import '../tools/http_tool.dart';
import '../tools/tool.dart';
import '../tools/tool_executor.dart';
import '../tools/tool_registry.dart';
import 'model_selection.dart';

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
  });

  /// 正在生成的回答内容块（按 Part 顺序）。
  final List<MessagePart> streamingParts;

  /// 当前会话的附件索引，用于把 Part 里的附件引用还原成文件。
  final Map<String, Attachment> attachments;

  final bool isGenerating;

  ChatState copyWith({
    List<MessagePart>? streamingParts,
    Map<String, Attachment>? attachments,
    bool? isGenerating,
  }) {
    return ChatState(
      streamingParts: streamingParts ?? this.streamingParts,
      attachments: attachments ?? this.attachments,
      isGenerating: isGenerating ?? this.isGenerating,
    );
  }
}

/// 聊天状态在应用生命周期内保留：切到设置页再回来不应丢失当前会话与流式状态。
@Riverpod(
  keepAlive: true,
  dependencies: [ModelSelection, currentAssistant, ActiveConversation],
)
class ChatController extends _$ChatController implements AgentLoopHost {
  /// 流式增量写库的节流间隔：SSE chunk 远密于屏幕刷新。
  static const _flushInterval = Duration(milliseconds: 100);

  /// 回填给模型的工具结果上限（字节）；超出时截断并附截断标记。
  static const _maxToolResultBytes = 8 * 1024;

  /// 尚未产生输出的临时模型错误最多重试次数（design 第二部分 §7）。
  static const _maxModelRetries = 2;

  StreamSubscription<ChatChunk>? _subscription;
  Completer<void>? _doneCompleter;
  Timer? _flushTimer;
  String? _streamingMessageId;

  /// 本轮助手消息 id：流式结束后仍可用于补写工具调用引用。
  String? _turnMessageId;
  ProviderError? _streamError;

  /// 流式期间的块缓冲：partId → 已累积内容。
  final List<_LivePart> _liveParts = [];

  DateTime? _thinkingStartedAt;
  DateTime? _firstTextAt;
  bool _stoppedManually = false;

  /// 界面注册的工具确认入口（S4 的确认面板接入这里）。
  ///
  /// 未注册时执行器按超时拒绝处理，不把动作当成已批准。回调里不显示、
  /// 不记录参数以外的内容；接口只接收摘要与期限。
  Future<ToolDecision> Function(ToolConfirmationRequest request)?
  onToolConfirmation;

  /// 当前运行：一次发送（或重新生成）对应一个 AgentRun，配置在开始时固定。
  AgentRun? _run;

  /// 运行内的模型选择快照：连接、能力与推理等级全程取它，不看中途改动。
  ChatModelSelection? _selection;
  ConversationRepository? _repository;
  ToolCallRepository? _toolCalls;
  AgentRunRepository? _runs;
  ArtifactStorage? _storage;
  ToolRegistry? _registry;
  ToolExecutor? _executor;
  RunCancellation? _cancellation;

  /// 本轮助手的最终内容块（含执行后补上的 ToolCallPart）。
  List<MessagePart> _turnParts = const [];
  MessageStatus _turnStatus = MessageStatus.streaming;
  TokenUsage? _turnUsage;

  /// 本轮思考耗时：在收口时定下来，补写调用引用时不重算。
  int? _turnThinkingDurationMs;

  /// 本轮分支末尾的消息：下一轮助手消息与运行位置都指向它。
  String? _turnTailId;

  /// 本轮以错误或空回复收场时，运行结束原因取它。
  RunFinishReason? _turnFailure;
  bool _runFinished = false;

  @override
  ChatState build() {
    ref.onDispose(() {
      _flushTimer?.cancel();
      unawaited(_subscription?.cancel());
      _doneCompleter?.complete();
    });
    return const ChatState();
  }

  void startNewConversation() {
    ref.read(activeConversationProvider.notifier).clear();
    state = const ChatState();
  }

  /// 切换到某个会话；消息由界面订阅仓储，附件索引进入时读取。
  Future<void> openConversation(String conversationId) async {
    final repository = await ref.read(conversationRepositoryProvider.future);
    final thread = await repository.getThread(conversationId);
    if (thread == null) return;
    ref.read(activeConversationProvider.notifier).open(conversationId);
    state = ChatState(
      attachments: await _attachmentIndex(conversationId, const []),
    );
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
  }) {
    return _guardAssistant('创建助手失败', () async {
      final repository = await ref.read(assistantRepositoryProvider.future);
      final assistant = Assistant(
        id: generateId(),
        name: name.trim(),
        systemPrompt: systemPrompt.trim(),
        defaultModelSelection: defaultModelSelection,
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
        toolPolicy: existing.toolPolicy,
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
    final trimmed = text.trim();
    if ((trimmed.isEmpty && attachments.isEmpty) || state.isGenerating) {
      return;
    }

    // 强刷：刚切换的助手/会话要立刻作用到本次请求，不依赖竞态的重建时机。
    final selection = await ref.refresh(modelSelectionProvider.future);
    if (selection == null) {
      throw const UnknownFailure('尚未选择服务商与模型');
    }

    final repository = await ref.read(conversationRepositoryProvider.future);

    // 助手列表可能还在首次加载：先把列表与会话线程等就绪，
    // 否则本次请求会丢掉系统提示词与助手默认模型。
    final assistant = await awaitAssistantContext(ref);
    var conversationId = ref.read(activeConversationProvider).conversationId;
    if (conversationId == null) {
      final conversation = await repository.createConversation(
        assistantId: assistant?.id,
        modelSelectionOverride: ref
            .read(activeConversationProvider)
            .draftModelSelection,
      );
      conversationId = conversation.id;
      ref.read(activeConversationProvider.notifier).adopt(conversationId);
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
    state = state.copyWith(attachments: attachmentIndex);

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
    );
  }

  /// 重新生成当前分支的最后一条回答。
  ///
  /// 新建一条回答挂在同一条用户消息下，旧回答保留在消息树里不覆盖；
  /// 有工具执行历史时不自动重做动作（S3 起生效）。
  Future<void> regenerate() async {
    if (state.isGenerating) return;
    final conversationId = ref.read(activeConversationProvider).conversationId;
    if (conversationId == null) return;

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

    // 分支指针回到该用户消息：新回答成为它的下一条，旧回答保留为历史分支。
    await repository.setCurrentMessage(conversationId, userMessage.id);

    await _startRun(
      repository: repository,
      conversationId: conversationId,
      inputMessageId: userMessage.id,
      selection: selection,
      assistant: assistant,
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
  }) async {
    final runs = await ref.read(agentRunRepositoryProvider.future);
    final toolCalls = await ref.read(toolCallRepositoryProvider.future);
    final storage = await ref.read(artifactStorageProvider.future);

    // 连接快照只存服务商 id、协议与地址，密钥按 id 在调用时读取。
    final run = await runs.create(
      AgentRun(
        id: generateId(),
        conversationId: conversationId,
        assistantId: assistant?.id,
        inputMessageId: inputMessageId,
        configuration: RunConfiguration(
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
          ),
          systemPrompt: assistant?.systemPrompt ?? '',
          enabledTools: assistant?.toolPolicy.enabledTools ?? const {},
          toolPolicies: assistant?.toolPolicy.overrides ?? const {},
        ),
        createdAt: DateTime.now(),
      ),
    );

    final registry = ref.read(toolRegistryProvider);
    final executor = ToolExecutor(
      registry: registry,
      toolCalls: toolCalls,
      runs: runs,
      // 记录一创建就把调用写进助手消息：工具卡片在"等待确认"时就出现，
      // 而不是等执行结束才补上。
      onRecordCreated: (record) {
        final messageId = _turnMessageId;
        if (messageId == null) return Future<void>.value();
        return _attachToolCallPart(
          messageId,
          record.id,
          providerData: record.providerData,
        );
      },
    );
    if (onToolConfirmation != null) {
      executor.onConfirmationRequired = _confirmToolCall;
    }

    _run = run;
    _selection = selection;
    _repository = repository;
    _toolCalls = toolCalls;
    _runs = runs;
    _storage = storage;
    _registry = registry;
    _executor = executor;
    _cancellation = RunCancellation();
    _runFinished = false;
    _turnFailure = null;
    _turnTailId = null;
    state = state.copyWith(
      isGenerating: true,
      streamingParts: const [],
      attachments: await _attachmentIndex(conversationId, const []),
    );

    try {
      await AgentLoop(this, maxTurns: run.maxTurns).run();
    } on Failure {
      // 落库失败：运行按存储失败收口后再交给界面提示，不留永远 running 的运行。
      await _finishRun(RunStatus.failed, RunFinishReason.storageError);
      rethrow;
    } finally {
      _flushTimer?.cancel();
      _flushTimer = null;
      _streamingMessageId = null;
      _run = null;
      _selection = null;
      _cancellation = null;
      _executor = null;
      state = state.copyWith(isGenerating: false, streamingParts: const []);
    }
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
    final messages = await _resolveHistory(thread.branch, state.attachments);

    final assistantMessage = ChatMessage(
      id: generateId(),
      conversationId: run.conversationId,
      parentId: thread.currentMessageId,
      runId: run.id,
      role: ChatRole.assistant,
      status: MessageStatus.streaming,
      parts: const [],
      modelLabel: selection.model,
      createdAt: DateTime.now(),
    );
    await repository.appendMessage(assistantMessage);

    _liveParts.clear();
    _streamingMessageId = assistantMessage.id;
    _turnMessageId = assistantMessage.id;
    _streamError = null;
    _stoppedManually = false;
    _thinkingStartedAt = null;
    _firstTextAt = null;
    _turnParts = const [];
    _turnStatus = MessageStatus.streaming;
    _turnUsage = null;
    _turnFailure = null;
    _turnTailId = assistantMessage.id;
    state = state.copyWith(streamingParts: const []);

    await _requestWithRetry(selection, messages);

    final parts = _partsFromLive(_liveParts);
    final toolCalls = _toolCallsFromLive();
    final failure = _streamError;
    _streamError = null;
    _flushTimer?.cancel();
    _flushTimer = null;
    _streamingMessageId = null;
    _subscription = null;
    _doneCompleter = null;
    _turnThinkingDurationMs = _currentThinkingDurationMs;

    if (_stoppedManually) {
      // 停止保留已收内容；未执行的调用不再进入调度。
      _turnStatus = MessageStatus.cancelled;
      _turnParts = parts;
      await repository.updateMessage(
        messageId: assistantMessage.id,
        parts: parts,
        status: MessageStatus.cancelled,
        usage: _turnUsage,
        thinkingDurationMs: _turnThinkingDurationMs,
      );
      return StreamedTurn(
        messageId: assistantMessage.id,
        parts: _turnParts,
        toolCalls: const [],
        cancelled: true,
      );
    }

    if (failure != null) {
      // 流内错误与连接错误都保留已收内容，按失败收口。
      _turnStatus = MessageStatus.failed;
      _turnFailure = RunFinishReason.modelError;
      _turnParts = [...parts, TextPart(text: failure.userMessage)];
      await repository.updateMessage(
        messageId: assistantMessage.id,
        parts: _turnParts,
        status: MessageStatus.failed,
        usage: _turnUsage,
        thinkingDurationMs: _turnThinkingDurationMs,
      );
      return StreamedTurn(
        messageId: assistantMessage.id,
        parts: _turnParts,
        toolCalls: const [],
        failed: true,
      );
    }

    if (parts.isEmpty && toolCalls.isEmpty) {
      // 网关用非 SSE 错误体（HTTP 200 + JSON）时会空跑结束，明确报错。
      _turnStatus = MessageStatus.failed;
      _turnFailure = RunFinishReason.emptyResponse;
      _turnParts = const [TextPart(text: '服务商返回了空响应，请检查模型名称与推理等级设置')];
      await repository.updateMessage(
        messageId: assistantMessage.id,
        parts: _turnParts,
        status: MessageStatus.failed,
      );
      return StreamedTurn(
        messageId: assistantMessage.id,
        parts: _turnParts,
        toolCalls: const [],
        failed: true,
      );
    }

    _turnStatus = MessageStatus.completed;
    _turnParts = parts;
    await repository.updateMessage(
      messageId: assistantMessage.id,
      parts: parts,
      status: MessageStatus.completed,
      usage: _turnUsage,
      thinkingDurationMs: _turnThinkingDurationMs,
    );
    return StreamedTurn(
      messageId: assistantMessage.id,
      parts: _turnParts,
      toolCalls: toolCalls,
    );
  }

  /// 执行一次工具调用：记录 → 结果消息 → 结果进入下一轮上下文。
  @override
  Future<ExecutedTool> executeTool(ToolCall call, StreamedTurn turn) async {
    final run = _run!;
    final cancellation = _cancellation!;
    final repository = _repository!;

    ToolCallRecord record;
    final argumentsError = call.argumentsError;
    if (argumentsError != null) {
      // 参数不完整：如实记为参数错误并回填，不派发、不猜命令。
      record = await _recordInvalidArguments(run, turn, call, argumentsError);
    } else {
      final executed = await _executor!.execute(
        ToolExecutionRequest(
          runId: run.id,
          assistantMessageId: turn.messageId,
          toolName: call.toolName,
          arguments: call.arguments,
          channel: ExecutionChannel.app,
          conversationId: run.conversationId,
          attachments: await _storage!.attachments(run.conversationId),
          storage: _storage!,
          enabledTools: run.configuration.enabledTools,
          toolPolicies: run.configuration.toolPolicies,
          providerCallId: call.callId,
          providerData: call.providerData,
        ),
        cancellation,
      );
      record = executed.record;
      if (record.status == ToolCallStatus.succeeded) {
        await _registerArtifacts(
          run.conversationId,
          toolReported: record.artifacts.isNotEmpty,
        );
      }
    }

    // 助手消息里只引用记录 id：参数与结果留在 tool_calls 记录里。
    await _attachToolCallPart(turn.messageId, record.id);

    if (record.status == ToolCallStatus.unknown) {
      // 结果未确认：不写结果消息，运行挂起等待核验，不自动重做动作。
      _run = await _runs!.waitForResult(run.id, record.id);
      return ExecutedTool(
        callId: call.callId,
        content: record.result ?? _statusText(record.status),
        isError: true,
        record: record,
      );
    }

    final content = _resultText(record);
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
  Future<void> finish(AgentFinishReason reason) {
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
      AgentFinishReason.unknownResult => (RunStatus.awaitingResult, null),
    };
    if (reason == AgentFinishReason.unknownResult) {
      // 结果未确认是挂起而不是结束：状态与待核验调用已由 waitForResult 落库，
      // 这里不写终态与结束原因，也不自动重做动作。
      _runFinished = true;
      return Future.value();
    }
    return _finishRun(result.$1, result.$2);
  }

  /// 运行终态只写一次：循环收口与异常收尾共用。
  Future<void> _finishRun(
    RunStatus status,
    RunFinishReason? finishReason,
  ) async {
    final run = _run;
    if (run == null || _runFinished) return;
    _runFinished = true;
    _run = await _runs!.finish(
      run.id,
      status: status,
      finishReason: finishReason,
      currentMessageId: _turnTailId,
    );
  }

  /// 请求用户确认：等待期间运行记 awaitingConfirmation 与待确认调用。
  ///
  /// 没有界面、到点或停止都不把动作当成已批准：前两者按拒绝，停止按取消
  /// （执行器在回调返回后统一按取消收口）。
  Future<ToolDecision> _confirmToolCall(ToolConfirmationRequest request) async {
    final run = _run;
    if (run != null) {
      _run = await _runs!.awaitConfirmation(run.id, request.record.id);
    }
    final handler = onToolConfirmation;
    final cancellation = _cancellation;
    if (handler == null || cancellation == null) return ToolDecision.expired;

    final remaining = request.expiresAt.difference(DateTime.now());
    final expired = Completer<ToolDecision>();
    final timer = Timer(
      remaining.isNegative ? Duration.zero : remaining,
      () => expired.complete(ToolDecision.expired),
    );
    try {
      final decision = await Future.any([
        handler(request).catchError((Object error, StackTrace stackTrace) {
          AppLogger.error('工具确认失败', error, stackTrace);
          return ToolDecision.expired;
        }),
        expired.future,
        cancellation.whenCancelled.then((_) => ToolDecision.expired),
      ]);
      return decision;
    } finally {
      timer.cancel();
    }
  }

  /// 停止生成：结束本轮模型请求与正在进行的工具执行。
  ///
  /// 等待确认中停止不执行动作（记录 cancelled）；执行中停止请求工具取消，
  /// 工具实际返回的结果如实记录（design 第二部分 §6）。
  void stop() {
    if (!state.isGenerating) return;
    _stoppedManually = true;
    _cancellation?.cancel();
    unawaited(_subscription?.cancel());
    _doneCompleter?.complete();
  }

  /// 一次真实请求：订阅事件流，累积内容直到结束、出错或停止。
  ///
  /// 只有尚未产生输出的临时错误（网络、限流）才重试，最多 [_maxModelRetries]
  /// 次，每次计入 modelAttemptCount；工具没有自动重试。
  Future<void> _requestWithRetry(
    ChatModelSelection selection,
    List<ResolvedMessage> messages,
  ) async {
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
    final request = ChatRequest(
      modelId: selection.model,
      systemPrompt: _run?.configuration.systemPrompt ?? '',
      messages: messages,
      tools: _toolDefinitions(),
      // 模型不支持推理时不下发任何推理字段。
      reasoningEffort: selection.supportsReasoning
          ? selection.effort
          : ReasoningEffort.off,
      temperature: modelConfig?.temperature,
      maxOutputTokens: modelConfig?.maxOutputTokens,
    );

    for (var attempt = 0; ; attempt++) {
      _run = await _runs!.countModelAttempt(_run!.id);
      await _consume(provider, request);
      final error = _streamError;
      if (error == null || !error.retryable || _stoppedManually) return;
      // 已产生的输出不重放，避免把半句话拼成两份。
      if (_liveParts.any((part) => part.buffer.isNotEmpty)) return;
      if (attempt >= _maxModelRetries) return;
      _liveParts.clear();
      _streamError = null;
    }
  }

  /// 订阅一次请求的事件流，直到结束、出错或被停止。
  Future<void> _consume(AiProvider provider, ChatRequest request) async {
    final doneCompleter = Completer<void>();
    void completeOnce() {
      if (!doneCompleter.isCompleted) {
        doneCompleter.complete();
      }
    }

    // 不能用 asFuture：它会覆盖 onError，且取消后永不完成（stop 会挂死）。
    final subscription = provider
        .streamChat(request)
        .listen(
          _onChunk,
          onError: (Object error) {
            _streamError = error is ProviderError
                ? error
                : ProviderError(
                    ProviderErrorCategory.providerError,
                    error is Failure ? error.userMessage : '连接服务商失败',
                    cause: error,
                  );
            completeOnce();
          },
          onDone: completeOnce,
          cancelOnError: true,
        );
    _subscription = subscription;
    _doneCompleter = doneCompleter;
    await doneCompleter.future;
  }

  /// 本次运行下发的工具定义：助手策略与模型工具能力都满足才下发。
  List<ToolDefinition> _toolDefinitions() {
    final selection = _selection;
    final run = _run;
    final registry = _registry;
    if (selection == null || run == null || registry == null) return const [];
    if (!selection.supportsTools) return const [];
    return registry.definitionsFor(
      run.configuration.enabledTools,
      run.configuration.toolPolicies,
    );
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

  /// 参数 JSON 非法：记为参数错误并回填，不派发。
  Future<ToolCallRecord> _recordInvalidArguments(
    AgentRun run,
    StreamedTurn turn,
    ToolCall call,
    String reason,
  ) {
    final tool = _registry!.byName(call.toolName);
    final now = DateTime.now();
    return _toolCalls!.create(
      ToolCallRecord(
        id: generateId(),
        runId: run.id,
        assistantMessageId: turn.messageId,
        providerCallId: call.callId,
        toolName: call.toolName,
        arguments: call.arguments,
        providerData: call.providerData,
        target: tool?.describeAction(call.arguments),
        channel: ExecutionChannel.app,
        defaultPolicy: tool?.defaultPolicy ?? ToolPolicy.ask,
        status: ToolCallStatus.failed,
        result: reason,
        errorCode: 'invalidArguments',
        createdAt: now,
        finishedAt: now,
      ),
    );
  }

  /// 把调用引用补进助手消息；消息只存记录 id，不复制参数。
  ///
  /// 记录创建时补一次（卡片在等待确认/执行中就出现），执行后再补一次
  /// 时同一调用只保留一份。
  Future<void> _attachToolCallPart(
    String messageId,
    String toolCallId, {
    Map<String, dynamic>? providerData,
  }) async {
    final alreadyAttached = _turnParts.any(
      (part) => part is ToolCallPart && part.toolCallId == toolCallId,
    );
    if (alreadyAttached) return;
    _turnParts = [
      ..._turnParts,
      ToolCallPart(toolCallId: toolCallId, providerData: providerData),
    ];
    await _repository!.updateMessage(
      messageId: messageId,
      parts: _turnParts,
      status: _turnStatus,
      usage: _turnUsage,
      thinkingDurationMs: _turnThinkingDurationMs,
    );
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
      state = state.copyWith(
        attachments: await _attachmentIndex(conversationId, const []),
      );
    } on Exception catch (error, stackTrace) {
      // 登记失败不影响结果回填：产物仍在磁盘上，可再次登记。
      AppLogger.error('产物登记失败', error, stackTrace);
    }
  }

  /// 回填给模型与结果消息的文本；记录里没有结果时按状态给出说明。
  String _resultText(ToolCallRecord record) =>
      _truncateResult(record.result ?? _statusText(record.status));

  String _statusText(ToolCallStatus status) => switch (status) {
    ToolCallStatus.rejected => '用户拒绝了本次动作，没有执行。',
    ToolCallStatus.cancelled => '本次调用已取消，没有取得结果。',
    ToolCallStatus.unknown => '本次动作已派发，但结果未确认。',
    ToolCallStatus.prepared ||
    ToolCallStatus.awaitingConfirmation ||
    ToolCallStatus.executing => '本次调用没有返回内容。',
    ToolCallStatus.succeeded => '工具执行完成，但没有返回内容。',
    ToolCallStatus.failed => '工具执行失败，没有返回内容。',
  };

  /// 结果按上限截断：超出时附截断标记，不把整段输出塞进上下文。
  String _truncateResult(String text) {
    final bytes = utf8.encode(text);
    if (bytes.length <= _maxToolResultBytes) return text;
    final head = utf8.decode(
      bytes.sublist(0, _maxToolResultBytes),
      allowMalformed: true,
    );
    return '$head\n【结果已截断：超过 ${_maxToolResultBytes ~/ 1024}KB】';
  }

  void _onChunk(ChatChunk chunk) {
    switch (chunk) {
      case PartStart():
        if (chunk.kind == PartKind.toolCall) {
          _liveParts.add(_LivePart.toolCall(chunk.partId));
        } else if (chunk.kind == PartKind.provider) {
          _liveParts.add(_LivePart.provider(chunk.partId));
        } else {
          final part = _LivePart(chunk.partId, chunk.kind);
          if (chunk.initialContent?.isNotEmpty == true) {
            part.buffer.write(chunk.initialContent);
          }
          _liveParts.add(part);
          _markProgress(chunk.kind);
        }
      case TextDelta():
        _livePart(chunk.partId, PartKind.text).buffer.write(chunk.text);
        _markProgress(PartKind.text);
      case ReasoningDelta():
        _livePart(chunk.partId, PartKind.reasoning).buffer.write(chunk.text);
        _markProgress(PartKind.reasoning);
      case ToolCallDelta():
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
          case ReasoningPart(:final publicText):
            part.first.buffer
              ..clear()
              ..write(publicText);
          case ToolCallPart(:final toolCallId):
            // 协议收口的调用 id 是回填配对的依据。
            part.first.callId = toolCallId;
          default:
            break;
        }
      case UsageChunk(:final usage):
        _turnUsage = usage;
      case ResponseEnd():
        break;
      case ResponseError(:final error):
        // 流内错误即本次响应结束：保留已收内容，按失败收口。
        _streamError = error;
        unawaited(_subscription?.cancel());
        _doneCompleter?.complete();
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

  void _markProgress(PartKind kind) {
    switch (kind) {
      case PartKind.reasoning:
        _thinkingStartedAt ??= DateTime.now();
      case PartKind.text:
        if (_thinkingStartedAt != null) {
          _firstTextAt ??= DateTime.now();
        }
      default:
        break;
    }
  }

  int? get _currentThinkingDurationMs {
    final started = _thinkingStartedAt;
    if (started == null) return null;
    return (_firstTextAt ?? DateTime.now()).difference(started).inMilliseconds;
  }

  void _scheduleFlush() {
    state = state.copyWith(streamingParts: _partsFromLive(_liveParts));
    _flushTimer ??= Timer(_flushInterval, _flushNow);
  }

  void _flushNow() {
    _flushTimer = null;
    final messageId = _streamingMessageId;
    if (messageId == null) return;
    // 节流写库：内存视图每帧都新，落库按 [_flushInterval] 合并。
    unawaited(
      ref
          .read(conversationRepositoryProvider.future)
          .then(
            (repository) => repository.updateMessage(
              messageId: messageId,
              parts: _partsFromLive(_liveParts),
              status: MessageStatus.streaming,
              thinkingDurationMs: _currentThinkingDurationMs,
            ),
          ),
    );
  }

  /// 当前分支 + 工具记录 → 一次请求的内容（design 第二部分 §3）。
  ///
  /// 工具调用与结果按记录成组保留：调用引用的记录与结果消息都存在才进入
  /// 请求，结果未确认的调用整体略过，不留下孤立调用或孤立结果。
  Future<List<ResolvedMessage>> _resolveHistory(
    List<ChatMessage> messages,
    Map<String, Attachment> attachments,
  ) async {
    final records = await _recordsFor(messages);
    // 结果文本以结果消息为准：拒绝等状态只写进结果消息，记录里可能没有。
    final results = <String, ResolvedToolResult>{};
    for (final message in messages) {
      for (final part in message.parts) {
        if (part is! ToolResultPart) continue;
        final record = records[part.toolCallId];
        final callId = record?.providerCallId;
        if (record == null || callId == null) continue;
        results[part.toolCallId] = ResolvedToolResult(
          callId: callId,
          content: _truncateResult(
            message.text.isNotEmpty
                ? message.text
                : (record.result ?? _statusText(record.status)),
          ),
          isError: record.status == ToolCallStatus.failed,
        );
      }
    }

    final resolved = <ResolvedMessage>[];
    for (final message in messages) {
      final parts = <ResolvedPart>[];
      for (final part in message.parts) {
        switch (part) {
          case TextPart(:final text):
            if (text.isNotEmpty) parts.add(ResolvedText(text));
          case ReasoningPart(:final publicText, :final providerData):
            if (publicText.isNotEmpty) {
              parts.add(
                ResolvedReasoning(publicText, providerData: providerData),
              );
            }
          case ImagePart(:final attachmentId):
            final attachment = attachments[attachmentId];
            if (attachment != null) parts.add(ResolvedImage(attachment));
          case DocumentPart(:final attachmentId):
            final text = _readExtractedText(attachments[attachmentId]);
            if (text != null) parts.add(ResolvedText(text));
          case ToolCallPart(:final toolCallId):
            final record = records[toolCallId];
            final callId = record?.providerCallId;
            // 结果未确认（或记录缺失）的调用不进入请求：不能只有调用没有结果。
            if (record == null || callId == null) break;
            if (!results.containsKey(toolCallId)) break;
            parts.add(
              ResolvedToolCall(
                callId: callId,
                toolName: record.toolName,
                arguments: record.arguments,
                providerData: record.providerData,
              ),
            );
          case ToolResultPart(:final toolCallId):
            // 结果由所在消息自己回填（协议要求它与调用分属不同角色）。
            final result = results[toolCallId];
            if (result != null) parts.add(result);
          case ProviderPart():
            // 协议块不进入请求。
            break;
        }
      }
      if (parts.isEmpty) continue;
      resolved.add(ResolvedMessage(role: message.role, parts: parts));
    }
    return resolved;
  }

  /// 分支里引用到的工具记录：消息只存记录 id，参数与结果按 id 读回。
  Future<Map<String, ToolCallRecord>> _recordsFor(
    List<ChatMessage> messages,
  ) async {
    final ids = <String>{};
    for (final message in messages) {
      for (final part in message.parts) {
        switch (part) {
          case ToolCallPart(:final toolCallId):
          case ToolResultPart(:final toolCallId):
            ids.add(toolCallId);
          default:
            break;
        }
      }
    }
    if (ids.isEmpty) return const {};
    return _repository!.toolCallsByIds(ids);
  }

  /// 读取附件的文本内容。
  ///
  /// 文档用抽取结果（PDF/DOCX 在导入时抽取），文本文件直接读原文件；
  /// 抽取失败时把失败原因作为内容交给模型，让它知道这份文档没有文字，
  /// 而不是让请求里凭空少一份附件。
  String? _readExtractedText(Attachment? attachment) {
    if (attachment == null) return null;
    final error = attachment.extractionError;
    if (error != null) {
      return '【附件「${attachment.name}」未能提取文字：$error】';
    }
    final path = attachment.extractedTextPath ?? attachment.localPath;
    try {
      return File(path).readAsStringSync();
    } on FileSystemException {
      return null;
    }
  }

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

  MessagePart toPart() {
    final text = buffer.toString();
    return switch (kind) {
      PartKind.text => TextPart(text: text, partId: partId),
      PartKind.reasoning => ReasoningPart(publicText: text, partId: partId),
      // 工具调用以 ToolCallPart（引用记录 id）补进消息，协议块不落库。
      PartKind.toolCall ||
      PartKind.provider => TextPart(text: '', partId: partId),
    };
  }
}

/// 把流式缓冲转成消息内容块；空块不进入结果。
List<MessagePart> _partsFromLive(List<_LivePart> liveParts) {
  return [
    for (final part in liveParts)
      if (part.kind != PartKind.toolCall &&
          part.kind != PartKind.provider &&
          part.buffer.isNotEmpty)
        part.toPart(),
  ];
}

/// 内置工具集：文件工具只访问应用私有目录，HTTP 工具走独立的 Dio 实例。
///
/// 单独开注入点是为了让测试能替换工具集（记录调用的假工具、替代网络实现），
/// 与 [aiProviderFactoryProvider] 同样的理由。
@Riverpod(keepAlive: true)
ToolRegistry toolRegistry(Ref ref) {
  final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 15)));
  ref.onDispose(() => dio.close(force: true));
  return buildBuiltInRegistry(
    httpFetch: (request) => _fetchOverHttp(dio, request),
  );
}

/// 工具 HTTP 请求：只带超时，不挂日志拦截器。
///
/// 工具请求的 URL、请求头与正文都可能带用户数据（AGENTS.md §5），
/// 因此这条通道不记录任何请求内容；错误只回给工具，不写日志。
Future<HttpFetchResult> _fetchOverHttp(
  Dio dio,
  HttpFetchRequest request,
) async {
  try {
    final response = await dio.request<List<int>>(
      request.uri.toString(),
      data: request.body,
      options: Options(
        method: request.method,
        headers: request.headers,
        responseType: ResponseType.bytes,
        receiveTimeout: request.timeout,
        sendTimeout: request.timeout,
        // 4xx/5xx 是工具要如实汇报的结果，不当作连接异常。
        validateStatus: (status) => true,
      ),
    );
    final bytes = response.data ?? const <int>[];
    final truncated = bytes.length > request.maxBytes;
    return HttpFetchResult(
      statusCode: response.statusCode ?? 0,
      body: truncated ? bytes.sublist(0, request.maxBytes) : bytes,
      truncated: truncated,
    );
  } on DioException catch (error) {
    throw HttpFetchException(_fetchErrorCode(error), _fetchErrorMessage(error));
  }
}

String _fetchErrorCode(DioException error) => switch (error.type) {
  DioExceptionType.connectionTimeout ||
  DioExceptionType.sendTimeout ||
  DioExceptionType.receiveTimeout => 'timeout',
  DioExceptionType.cancel => 'cancelled',
  DioExceptionType.badCertificate => 'badCertificate',
  _ => 'network',
};

/// 错误文案只说明发生了什么，不回显 URL、请求头或异常原文。
String _fetchErrorMessage(DioException error) => switch (error.type) {
  DioExceptionType.connectionTimeout ||
  DioExceptionType.sendTimeout ||
  DioExceptionType.receiveTimeout =>
    '请求超时（${error.requestOptions.receiveTimeout?.inSeconds ?? 0} 秒）',
  DioExceptionType.cancel => '请求已取消',
  DioExceptionType.badCertificate => '服务端证书校验失败',
  DioExceptionType.connectionError => '连接服务器失败',
  _ => '请求未能完成',
};

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

/// 启动时尚未结束的运行：界面据此显示「结果未确认」等中断状态。
///
/// 只读取状态：不自动重跑任何动作，也不从日志回放（design 第二部分 §7）。
@Riverpod(keepAlive: true)
Future<List<AgentRun>> unfinishedRuns(Ref ref) async {
  final runs = await ref.watch(agentRunRepositoryProvider.future);
  return runs.unfinished();
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
        streaming && index == tail && message.role == ChatRole.assistant;
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
/// 跨轮拼接时同类内容之间补一个空行：两轮正文直接相连会读成一句话，两轮思考
/// 直接相连会读成一段。边界上夹着工具调用时不补——卡片本身就是分段，
/// 再插空行会在回答区里多出一个空段落。
List<MessagePart> _mergeAnswerParts(ChatMessage head, ChatMessage tail) {
  final parts = [...head.parts];
  final tailParts = [...tail.parts];
  if (tailParts.isNotEmpty) {
    if (parts.isNotEmpty &&
        parts.last is TextPart &&
        tailParts.first is TextPart) {
      parts.add(const TextPart(text: '\n\n'));
    }
    // 思考分段渲染在同一个面板里，跨轮之间没有别的分隔可言。
    final thinking = tailParts.indexWhere(
      (part) => part is ReasoningPart && part.publicText.isNotEmpty,
    );
    if (thinking >= 0 && _hasThinking(head)) {
      tailParts.insert(thinking, const ReasoningPart(publicText: '\n\n'));
    }
  }
  return [...parts, ...tailParts];
}

bool _hasThinking(ChatMessage message) => message.parts.any(
  (part) => part is ReasoningPart && part.publicText.isNotEmpty,
);

/// 助手列表；空库时先写入内置助手再发出，保证始终至少有一个助手。
@Riverpod(keepAlive: true)
Stream<List<Assistant>> assistants(Ref ref) async* {
  final repository = await ref.watch(assistantRepositoryProvider.future);
  await repository.ensureDefault();
  yield* repository.watchAssistants();
}

/// 当前生效的助手。
///
/// 已打开的会话用会话绑定的助手；新会话用草稿助手；两者都没有、
/// 或绑定的助手已被删除时回退到列表第一个（首次建库时为内置普通助手）。
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
