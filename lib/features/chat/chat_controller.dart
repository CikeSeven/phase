import 'dart:async';
import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/error/failure.dart';
import '../../../core/error/provider_error.dart';
import '../../../core/utils/id.dart';
import '../../../core/utils/logger.dart';
import '../../../data/datasources/local/secure_key_storage.dart';
import '../../../data/models/assistant.dart';
import '../../../data/models/attachment.dart';
import '../../../data/models/chat_chunk.dart';
import '../../../data/models/chat_message.dart';
import '../../../data/models/chat_request.dart';
import '../../../data/models/conversation.dart';
import '../../../data/models/message_part.dart';
import '../../../data/models/model_selection.dart' as model;
import '../../../data/models/reasoning_effort.dart';
import '../../../data/repositories/assistant_repository.dart';
import '../../../data/repositories/conversation_repository.dart';
import '../../../providers/provider_factory.dart';
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
class ChatController extends _$ChatController {
  /// 流式增量写库的节流间隔：SSE chunk 远密于屏幕刷新。
  static const _flushInterval = Duration(milliseconds: 100);

  StreamSubscription<ChatChunk>? _subscription;
  Completer<void>? _doneCompleter;
  Timer? _flushTimer;
  String? _streamingMessageId;
  ProviderError? _streamError;

  /// 流式期间的块缓冲：partId → 已累积内容。
  final List<_LivePart> _liveParts = [];

  DateTime? _thinkingStartedAt;
  DateTime? _firstTextAt;
  bool _stoppedManually = false;

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

    await _streamInto(
      repository: repository,
      conversationId: conversationId,
      context: [...thread.branch, userMessage],
      attachments: attachmentIndex,
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
    final context = thread.branch.sublist(0, index + 1);

    final selection = await ref.refresh(modelSelectionProvider.future);
    if (selection == null) {
      throw const UnknownFailure('尚未选择服务商与模型');
    }
    final assistant = await awaitAssistantContext(ref);

    // 分支指针回到该用户消息：新回答成为它的下一条，旧回答保留为历史分支。
    await repository.setCurrentMessage(conversationId, userMessage.id);

    await _streamInto(
      repository: repository,
      conversationId: conversationId,
      context: context,
      attachments: await _attachmentIndex(conversationId, const []),
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

  /// 一次回答的完整流式过程：写占位助手消息 → 流式累积 → 收口落库。
  ///
  /// 发送与重新生成共用它，保证两条路径的停止、错误与空回复语义一致。
  Future<void> _streamInto({
    required ConversationRepository repository,
    required String conversationId,
    required List<ChatMessage> context,
    required Map<String, Attachment> attachments,
    required ChatModelSelection selection,
    required Assistant? assistant,
  }) async {
    final assistantMessage = ChatMessage(
      id: generateId(),
      conversationId: conversationId,
      parentId: context.last.id,
      role: ChatRole.assistant,
      status: MessageStatus.streaming,
      parts: const [],
      modelLabel: selection.model,
      createdAt: DateTime.now(),
    );
    await repository.appendMessage(assistantMessage);

    state = state.copyWith(isGenerating: true, streamingParts: const []);

    final apiKey = selection.profile.requiresKey
        ? await ref.read(secureKeyStorageProvider).read(selection.profile.id) ??
              ''
        : '';
    final provider = ref.read(aiProviderFactoryProvider)(
      selection.profile,
      apiKey,
    );

    _liveParts.clear();
    _streamingMessageId = assistantMessage.id;
    _streamError = null;
    _stoppedManually = false;
    _thinkingStartedAt = null;
    _firstTextAt = null;

    final doneCompleter = Completer<void>();
    void completeOnce() {
      if (!doneCompleter.isCompleted) {
        doneCompleter.complete();
      }
    }

    // 模型参数来自该模型的配置；未设置时不下发，由服务端默认决定。
    final modelConfig = selection.profile.models
        .where((model) => model.id == selection.model)
        .firstOrNull;

    // 不能用 asFuture：它会覆盖 onError，且取消后永不完成（stop 会挂死）。
    final subscription = provider
        .streamChat(
          ChatRequest(
            modelId: selection.model,
            systemPrompt: assistant?.systemPrompt ?? '',
            messages: _resolveHistory(context, attachments),
            // 模型不支持推理时不下发任何推理字段。
            reasoningEffort: selection.supportsReasoning
                ? selection.effort
                : ReasoningEffort.off,
            temperature: modelConfig?.temperature,
            maxOutputTokens: modelConfig?.maxOutputTokens,
          ),
        )
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
    _doneCompleter = null;
    _subscription = null;
    _flushTimer?.cancel();
    _flushTimer = null;
    _streamingMessageId = null;
    final parts = _partsFromLive(_liveParts);
    final failure = _streamError;
    _streamError = null;

    if (failure != null) {
      await repository.updateMessage(
        messageId: assistantMessage.id,
        parts: [
          ...parts,
          TextPart(text: failure.userMessage),
        ],
        status: MessageStatus.failed,
        thinkingDurationMs: _currentThinkingDurationMs,
      );
    } else if (!_stoppedManually && parts.isEmpty) {
      // 网关用非 SSE 错误体（HTTP 200 + JSON）时会空跑结束，明确报错。
      await repository.updateMessage(
        messageId: assistantMessage.id,
        parts: const [TextPart(text: '服务商返回了空响应，请检查模型名称与推理等级设置')],
        status: MessageStatus.failed,
      );
    } else {
      // 正常结束与用户停止都保留已收内容；停止标记为 cancelled。
      await repository.updateMessage(
        messageId: assistantMessage.id,
        parts: parts,
        status: _stoppedManually
            ? MessageStatus.cancelled
            : MessageStatus.completed,
        thinkingDurationMs: _currentThinkingDurationMs,
      );
    }
    state = state.copyWith(isGenerating: false, streamingParts: const []);
  }

  /// 停止生成：取消订阅（Provider 侧桥接 CancelToken，即时生效）。
  void stop() {
    final subscription = _subscription;
    if (subscription == null) {
      return;
    }
    _stoppedManually = true;
    unawaited(subscription.cancel());
    _doneCompleter?.complete();
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
          default:
            break;
        }
      case UsageChunk():
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

  /// 消息历史 → 一次请求的内容（正文、公开思考、图片与工具结果）。
  List<ResolvedMessage> _resolveHistory(
    List<ChatMessage> messages,
    Map<String, Attachment> attachments,
  ) {
    final resolved = <ResolvedMessage>[];
    for (final message in messages) {
      if (message.id == _streamingMessageId) continue;
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
          case ToolCallPart() || ToolResultPart() || ProviderPart():
            // 工具往返与协议块在 S3 的工具循环里解析回填。
            break;
        }
      }
      if (parts.isEmpty) continue;
      resolved.add(ResolvedMessage(role: message.role, parts: parts));
    }
    return resolved;
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
      // 工具调用与协议块缺少执行所需的 id 映射，S3 接入工具循环后落库。
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

/// 视图展示的消息：当前分支 + 流式中的最后一条回答。
///
/// [thread] 来自 repository 的 watch 流，是持久化事实；
/// [state] 只提供尚未落库的流式内容。
List<ChatMessage> visibleMessages(ConversationThread thread, ChatState state) {
  if (!state.isGenerating || state.streamingParts.isEmpty) {
    return thread.branch;
  }
  final branch = [...thread.branch];
  if (branch.isNotEmpty && branch.last.role == ChatRole.assistant) {
    branch[branch.length - 1] = branch.last.copyWith(
      parts: state.streamingParts,
      status: MessageStatus.streaming,
    );
  }
  return branch;
}

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
