import 'dart:async';
import 'dart:convert';

import '../../../core/error/failure.dart';
import '../../../core/error/provider_error.dart';
import '../../../core/utils/id.dart';
import '../../../core/utils/logger.dart';
import '../../../data/datasources/local/secure_key_storage.dart';
import '../../../data/models/agent_run.dart';
import '../../../data/models/attachment.dart';
import '../../../data/models/chat_chunk.dart';
import '../../../data/models/chat_message.dart';
import '../../../data/models/chat_request.dart';
import '../../../data/models/message_part.dart';
import '../../../data/models/model_request_record.dart';
import '../../../data/models/provider_profile.dart';
import '../../../data/models/reasoning_effort.dart';
import '../../../data/models/token_usage.dart';
import '../../../data/models/tool_call_record.dart';
import '../../../data/models/tool_policy.dart';
import '../../../data/repositories/agent_run_repository.dart';
import '../../../data/repositories/conversation_repository.dart';
import '../../../data/repositories/model_request_repository.dart';
import '../../../providers/ai_provider.dart';
import '../../../providers/dio_failure_mapper.dart';
import '../../execution/execution_controller.dart';
import '../../execution/execution_api.g.dart';
import '../../execution/task_activity.dart';
import '../../tools/agent_loop.dart';
import '../../tools/tool.dart';
import '../chat_model_selection.dart';
import '../chat_operation.dart';
import '../context/chat_context_coordinator.dart';
import '../context/context_builder.dart';
import '../context/context_configuration.dart';
import '../context/context_meter.dart';
import '../model_retry.dart';
import 'chat_run_update.dart';
import 'chat_tool_runtime.dart';

class ModelTurnResult {
  const ModelTurnResult(this.turn, this.failure, this.tailId);
  final StreamedTurn turn;
  final RunFinishReason? failure;
  final String? tailId;
}

class ModelTurnRunnerFactory {
  const ModelTurnRunnerFactory({
    required this.conversations,
    required this.runs,
    required this.requests,
    required this.keys,
    required this.buildProvider,
    required this.retryPolicy,
    required this.contexts,
  });
  final ConversationRepository conversations;
  final AgentRunRepository runs;
  final ModelRequestRepository requests;
  final SecureKeyStorage keys;
  final AiProvider Function(ProviderProfile, String) buildProvider;
  final ModelRetryPolicy retryPolicy;
  final ChatContextCoordinator contexts;

  ModelTurnRunner create({
    required AgentRun run,
    required ChatModelSelection selection,
    required ChatToolRuntime tools,
    required RunCancellation cancellation,
    required ChatRunObserver observe,
    required ExecutionController execution,
  }) => ModelTurnRunner(
    run: run,
    selection: selection,
    tools: tools,
    cancellation: cancellation,
    observe: observe,
    execution: execution,
    conversations: conversations,
    runs: runs,
    requests: requests,
    keys: keys,
    buildProvider: buildProvider,
    retryPolicy: retryPolicy,
    contexts: contexts,
  );
}

/// 模型 IO 与流缓冲只属于当前驱动；每次失败尝试独立收口，不持有页面或 Ref。
class ModelTurnRunner {
  ModelTurnRunner({
    required this._run,
    required this._selection,
    required this._tools,
    required this._cancellation,
    required this._observe,
    required this._execution,
    required ConversationRepository conversations,
    required this._runs,
    required this._requests,
    required this._keys,
    required this._buildProvider,
    required this._retryPolicy,
    required this._contexts,
  }) : _repository = conversations;

  final AgentRun _run;
  final ChatModelSelection _selection;
  final ChatToolRuntime _tools;
  final RunCancellation _cancellation;
  final ChatRunObserver _observe;
  final ExecutionController _execution;
  final ConversationRepository _repository;
  final AgentRunRepository _runs;
  final ModelRequestRepository _requests;
  final SecureKeyStorage _keys;
  final AiProvider Function(ProviderProfile, String) _buildProvider;
  final ModelRetryPolicy _retryPolicy;
  final ChatContextCoordinator _contexts;
  static const _flushInterval = Duration(milliseconds: 100);
  static const _publishInterval = Duration(milliseconds: 50);
  StreamSubscription<ChatChunk>? _subscription;
  Completer<void>? _doneCompleter;
  Timer? _flushTimer;
  Timer? _publishTimer;
  String? _streamingMessageId;
  ProviderError? _streamError;
  bool _acceptingChunks = false;
  final List<_LivePart> _liveParts = [];
  bool _stoppedManually = false;
  List<MessagePart> _turnParts = const [];
  TokenUsage? _turnUsage;
  String? _requestId;
  int _usageRevision = 0;
  String? _responseModelId;
  int? _turnThinkingDurationMs;
  String? _turnTailId;
  RunFinishReason? _turnFailure;
  bool _responseComplete = false;
  Future<void> _pendingFlush = Future.value();
  Failure? _flushFailure;
  int _logicalTurn = 0;
  Map<String, Attachment> _attachments = const {};
  bool get isCancelled => _cancellation.isCancelled;
  String? get tailId => _turnTailId;

  Future<ModelTurnResult> runTurn({
    required int logicalTurn,
    required List<ResolvedMessage> messages,
    required String? parentId,
    required Map<String, Attachment> attachments,
  }) async {
    _logicalTurn = logicalTurn;
    _attachments = attachments;
    _turnFailure = null;
    _turnTailId = null;
    final turn = await _requestWithRetry(
      _selection,
      messages,
      parentId: parentId,
    );
    return ModelTurnResult(turn, _turnFailure, _turnTailId);
  }

  void stop() {
    _finishThinking();
    _stoppedManually = true;
    _cancellation.cancel();
    _acceptingChunks = false;
    _completeRequest();
  }

  void _completeRequest() {
    final done = _doneCompleter;
    if (done != null && !done.isCompleted) done.complete();
  }

  Future<ContextBuild> _buildContext(
    AiProvider provider,
    List<ResolvedMessage> messages,
    List<ToolDefinition> tools, {
    bool force = false,
  }) => _contexts.buildForRun(
    run: _run,
    selection: _selection,
    registry: _tools.registry,
    tools: tools,
    provider: provider,
    messages: messages,
    attachments: _attachments,
    cancellation: _cancellation,
    force: force,
    onSummarizing: (value) =>
        _observe(ChatSummarizingChanged(_run.id, _run.conversationId, value)),
  );

  Future<void> close(ChatOperation operation) async {
    _acceptingChunks = false;
    _flushTimer?.cancel();
    _publishTimer?.cancel();
    _streamingMessageId = null;
    await operation.cleanup(
      () async => _subscription?.cancel(),
      failureMessage: '模型流未能完整关闭',
    );
    await operation.cleanup(() => _pendingFlush, failureMessage: '流式内容写入未能收口');
    _subscription = null;
    _doneCompleter = null;
    _pendingFlush = Future.value();
    _requestId = null;
    _turnParts = const [];
    _attachments = const {};
    _liveParts.clear();
  }

  /// 一次模型尝试保存为独立消息；失败尝试保留在同一父节点的历史分支。
  Future<StreamedTurn> _streamAttempt(
    AiProvider provider,
    ChatRequest request, {
    required String? parentId,
    required ContextMeasurement? inputMeasurement,
  }) async {
    final run = _run;
    final repository = _repository;
    final selection = _selection;
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
    await _requests.prepare(
      ModelRequestRecord(
        id: _requestId!,
        conversationId: run.conversationId,
        runId: run.id,
        logicalTurn: _logicalTurn,
        attemptIndex: _attemptIndex,
        profileId: run.configuration.connection.profileId,
        protocol: run.configuration.connection.protocol,
        requestedModelId: selection.model,
        assistantMessageId: assistantMessage.id,
        contextSnapshot: inputMeasurement?.toSnapshot() ?? const {},
        createdAt: DateTime.now(),
      ),
    );
    await repository.appendMessage(assistantMessage);

    _liveParts.clear();
    _execution.updateActivity(
      run.id,
      _execution.activityFor(run.id).waitForResponse(),
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
    _observe(
      ChatStreamingStarted(_run.id, _run.conversationId, assistantMessage.id),
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
      _observe(ChatStreamingFinished(_run.id, _run.conversationId));
      _streamingMessageId = null;
    }
    if (_flushFailure case final error?) {
      await _requests.interruptPending(
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
          source: _tools.registry.byName(call.toolName)?.source,
          arguments: call.arguments,
          providerData: call.providerData,
          target: _tools.registry
              .byName(call.toolName)
              ?.describeAction(call.arguments),
          channel: _tools.channelFor(call.toolName, call.arguments),
          defaultPolicy:
              _tools.registry.byName(call.toolName)?.defaultPolicy ??
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
  ) async {
    await _requests.settle(
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
    await _contexts.refreshForRun(
      run: _run,
      selection: _selection,
      registry: _tools.registry,
      tools: _tools.definitions,
      attachments: _attachments,
      cancellation: _cancellation,
      observe: _observe,
    );
  }

  /// 重试当前模型轮：请求上下文固定，先保存失败尝试再退避，不重放工具。
  Future<StreamedTurn> _requestWithRetry(
    ChatModelSelection selection,
    List<ResolvedMessage> messages, {
    required String? parentId,
  }) async {
    final apiKey = selection.profile.requiresKey
        ? await _keys.read(selection.profile.id) ?? ''
        : '';
    final provider = _buildProvider(selection.profile, apiKey);
    // 模型参数来自该模型的配置；未设置时不下发，由服务端默认决定。
    final modelConfig = selection.profile.models
        .where((model) => model.id == selection.model)
        .firstOrNull;
    final systemPrompt = contextSystemPrompt(_run.configuration);
    final tools = _tools.definitions;
    ContextBuild context;
    try {
      context = await _buildContext(provider, messages, tools);
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
        conversationId: _run.conversationId,
        parentId: parentId,
        runId: _run.id,
        role: ChatRole.assistant,
        status: MessageStatus.failed,
        parts: [TextPart(text: failure.userMessage)],
        createdAt: DateTime.now(),
      );
      await _repository.appendMessage(message);
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

    final policy = _retryPolicy;
    var recoveredContext = false;
    for (var attempt = 0; ; attempt++) {
      _attemptIndex = attempt + 1;
      {
        // 重试仍显示并保存原请求输入，不把失败后的显示预览作为请求基准。
        _observe(ChatContextMeasured(_run.id, _run.conversationId, context));
      }
      final turn = await _streamAttempt(
        provider,
        request,
        parentId: parentId,
        inputMeasurement: context.measurement,
      );
      if (isCancelled || turn.cancelled) return turn;
      final error = _streamError;
      if (error == null) return turn;
      if (error.category == ProviderErrorCategory.contextLimit &&
          !recoveredContext) {
        recoveredContext = true;
        final previousGeneration = context.measurement?.generation;
        try {
          context = await _buildContext(provider, messages, tools, force: true);
        } on OperationFailure {
          return turn;
        }
        if (isCancelled ||
            context.measurement?.generation == previousGeneration) {
          return turn;
        }
        request = context.preparedRequest!;
        continue;
      }
      final delay = policy.delayFor(error, attempt + 1);
      if (delay == null) return turn;
      {
        _observe(
          ChatRetryChanged(
            _run.id,
            _run.conversationId,
            ModelRetryState(
              attempt: attempt + 1,
              maxRetries: policy.maxRetries,
              delay: delay,
            ),
          ),
        );
        _execution.updateActivity(
          _run.id,
          _execution
              .activityFor(_run.id)
              .copyWith(
                phase: TaskPanelPhase.waitingModel,
                status: '等待自动重试 ${attempt + 1}/${policy.maxRetries}',
              ),
        );
      }
      await waitForModelRetry(delay, _cancellation);
      _observe(ChatRetryChanged(_run.id, _run.conversationId, null));
      if (isCancelled) return turn;
    }
  }

  /// 订阅一次请求的事件流，直到结束、出错或被停止。
  Future<void> _consume(AiProvider provider, ChatRequest request) async {
    if (isCancelled) return;
    await _requests.start(
      _requestId!,
      onStart: () async {
        await _runs.countModelAttempt(_run.id);
      },
    );
    if (isCancelled) {
      await _requests.cancelBeforeStart(_requestId!, undoAttempt: true);
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

  void _onChunk(ChatChunk chunk) {
    if (!_acceptingChunks || isCancelled) return;
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
    if (_liveParts.isEmpty) return;
    _observe(
      ChatStreamingChanged(
        _run.id,
        _run.conversationId,
        _partsFromLive(_liveParts),
      ),
    );
    final runId = _run.id;
    if (isCancelled) return;
    final visible = _liveParts.where((part) => part.buffer.isNotEmpty);
    final last = visible.lastOrNull;
    final phase = switch (last?.kind) {
      PartKind.reasoning => TaskPanelPhase.thinking,
      PartKind.text => TaskPanelPhase.responding,
      PartKind.toolCall => TaskPanelPhase.preparingTool,
      _ => TaskPanelPhase.waitingModel,
    };
    final activity = _execution.activityFor(runId);
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
    _execution.updateActivity(
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
          await _requests.sample(
            requestId,
            usage,
            revision,
            responseModelId: responseModel,
          );
        }
        await _repository.updateMessage(
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
