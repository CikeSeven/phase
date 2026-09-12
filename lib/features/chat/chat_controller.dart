import 'dart:async';
import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/error/failure.dart';
import '../../../core/error/provider_error.dart';
import '../../../core/utils/id.dart';
import '../../../data/datasources/local/secure_key_storage.dart';
import '../../../data/models/attachment.dart';
import '../../../data/models/chat_chunk.dart';
import '../../../data/models/chat_message.dart';
import '../../../data/models/chat_request.dart';
import '../../../data/models/conversation.dart';
import '../../../data/models/message_part.dart';
import '../../../data/models/reasoning_effort.dart';
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
    this.conversationId,
    this.streamingParts = const [],
    this.attachments = const {},
    this.isGenerating = false,
  });

  final String? conversationId;

  /// 正在生成的回答内容块（按 Part 顺序）。
  final List<MessagePart> streamingParts;

  /// 当前会话的附件索引，用于把 Part 里的附件引用还原成文件。
  final Map<String, Attachment> attachments;

  final bool isGenerating;

  ChatState copyWith({
    String? conversationId,
    List<MessagePart>? streamingParts,
    Map<String, Attachment>? attachments,
    bool? isGenerating,
  }) {
    return ChatState(
      conversationId: conversationId ?? this.conversationId,
      streamingParts: streamingParts ?? this.streamingParts,
      attachments: attachments ?? this.attachments,
      isGenerating: isGenerating ?? this.isGenerating,
    );
  }
}

/// 聊天状态在应用生命周期内保留：切到设置页再回来不应丢失当前会话与流式状态。
@Riverpod(keepAlive: true, dependencies: [ModelSelection])
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
    state = const ChatState();
  }

  /// 切换到某个会话；消息由界面订阅仓储，附件索引进入时读取。
  Future<void> openConversation(String conversationId) async {
    final repository = await ref.read(conversationRepositoryProvider.future);
    final thread = await repository.getThread(conversationId);
    if (thread == null) return;
    state = ChatState(
      conversationId: conversationId,
      attachments: await _attachmentIndex(conversationId, const []),
    );
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

    final selection = await ref.read(modelSelectionProvider.future);
    if (selection == null) {
      throw const UnknownFailure('尚未选择服务商与模型');
    }

    final repository = await ref.read(conversationRepositoryProvider.future);

    var conversationId = state.conversationId;
    if (conversationId == null) {
      final conversation = await repository.createConversation();
      conversationId = conversation.id;
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
    }
    // 附件索引带上刚落库的这批，发送后即可在气泡里看到缩略图，
    // 同时用于把历史消息里的附件引用解析成请求内容。
    final attachmentIndex = await _attachmentIndex(conversationId, claimed);
    state = state.copyWith(
      conversationId: conversationId,
      attachments: attachmentIndex,
    );

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

    final assistantMessage = ChatMessage(
      id: generateId(),
      conversationId: conversationId,
      parentId: userMessage.id,
      role: ChatRole.assistant,
      status: MessageStatus.streaming,
      parts: const [],
      modelLabel: selection.model,
      createdAt: DateTime.now(),
    );
    await repository.appendMessage(assistantMessage);

    // 使用刚读取的当前分支，不包含本轮刚落库的空回答。
    final branch = [...thread.branch, userMessage];

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

    // 不能用 asFuture：它会覆盖 onError，且取消后永不完成（stop 会挂死）。
    final subscription = provider
        .streamChat(
          ChatRequest(
            modelId: selection.model,
            // 助手系统提示词在 S2 接入（助手选择 + 提示词装配）。
            systemPrompt: '',
            messages: _resolveHistory(branch, attachmentIndex),
            // 模型不支持推理时不下发任何推理字段。
            reasoningEffort: selection.supportsReasoning
                ? selection.effort
                : ReasoningEffort.off,
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

  /// 读取附件的文本内容（S1 直接读原文件；PDF/DOCX 抽取在 S2 接入）。
  String? _readExtractedText(Attachment? attachment) {
    if (attachment == null) return null;
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
