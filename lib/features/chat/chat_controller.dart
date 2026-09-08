import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/error/failure.dart';
import '../../../data/datasources/local/secure_key_storage.dart';
import '../../../data/models/chat_chunk.dart';
import '../../../data/models/chat_message.dart';
import '../../../data/models/chat_request.dart';
import '../../../data/models/conversation.dart';
import '../../../data/repositories/conversation_repository.dart';
import '../../../providers/provider_factory.dart';
import 'model_selection.dart';

part 'chat_controller.g.dart';

/// 聊天页状态：当前会话 + 生成中标记。
///
/// messages 仅作发送前的本地缓冲 / 流式期间的增量视图，
/// 持久化消息以 repository 的 watch 流为准。
class ChatState {
  const ChatState({
    this.conversationId,
    this.messages = const [],
    this.isGenerating = false,
  });

  final String? conversationId;
  final List<ChatMessage> messages;
  final bool isGenerating;

  ChatState copyWith({
    String? conversationId,
    List<ChatMessage>? messages,
    bool? isGenerating,
  }) {
    return ChatState(
      conversationId: conversationId ?? this.conversationId,
      messages: messages ?? this.messages,
      isGenerating: isGenerating ?? this.isGenerating,
    );
  }
}

@Riverpod(dependencies: [ModelSelection])
class ChatController extends _$ChatController {
  /// 流式增量写库的节流间隔：SSE chunk 可能远密于屏幕刷新，
  /// 每个 chunk 都打一次数据库没有必要。
  static const _flushInterval = Duration(milliseconds: 100);

  StreamSubscription<ChatChunk>? _subscription;
  Completer<void>? _doneCompleter;
  Timer? _flushTimer;
  final StringBuffer _buffer = StringBuffer();
  String? _streamingMessageId;
  Failure? _streamError;

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

  void openConversation(String conversationId) {
    state = ChatState(conversationId: conversationId);
  }

  /// 发送一条消息并流式接收回复。
  ///
  /// 前置失败（未配置模型、落库失败）向上抛 [Failure]，由 UI 转 SnackBar；
  /// 流式期间的 [Failure] 不抛出，而是写入 AI 消息（status error）。
  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.isGenerating) {
      return;
    }

    final selection = await ref.read(modelSelectionProvider.future);
    if (selection == null) {
      throw const UnknownFailure('尚未选择服务商与模型');
    }

    final repository = ref.read(conversationRepositoryProvider);

    var conversationId = state.conversationId;
    if (conversationId == null) {
      final title = trimmed.length <= 20
          ? trimmed
          : '${trimmed.substring(0, 20)}…';
      final conversation = await repository.createConversation(title: title);
      conversationId = conversation.id;
      state = state.copyWith(conversationId: conversationId);
    }

    await repository.appendMessage(
      conversationId: conversationId,
      role: ChatRole.user,
      content: trimmed,
    );

    final aiMessage = await repository.appendMessage(
      conversationId: conversationId,
      role: ChatRole.assistant,
      content: '',
      status: ChatMessageStatus.streaming,
      modelName: selection.model,
    );

    // 上下文只带已完成的消息：排除刚插入的 streaming 占位与历史 error 消息。
    final history = [
      for (final message in await repository.getMessages(conversationId))
        if (message.status == ChatMessageStatus.done) message,
    ];

    state = state.copyWith(isGenerating: true);

    final apiKey = await ref
            .read(secureKeyStorageProvider)
            .readApiKey(selection.profile.id) ??
        '';
    final provider = ref
        .read(aiProviderFactoryProvider)(selection.profile, apiKey);

    _buffer.clear();
    _streamingMessageId = aiMessage.id;
    _streamError = null;

    // 不能用 StreamSubscription.asFuture 等待流结束：它会覆盖已注册的
    // onError，且取消后永不完成（stop 路径会挂死）。改用 Completer。
    final doneCompleter = Completer<void>();
    void completeOnce() {
      if (!doneCompleter.isCompleted) {
        doneCompleter.complete();
      }
    }

    final subscription = provider
        .streamChat(ChatRequest(model: selection.model, messages: history))
        .listen(
          (chunk) {
            if (chunk.delta.isNotEmpty) {
              _buffer.write(chunk.delta);
              _scheduleFlush();
            }
          },
          onError: (Object error) {
            _streamError = error is Failure
                ? error
                : UnknownFailure('$error');
            completeOnce();
          },
          onDone: completeOnce,
          cancelOnError: true,
        );
    _subscription = subscription;
    _doneCompleter = doneCompleter;

    // 挂起直到流结束 / 出错 / stop() 取消；stop 只负责取消与唤醒，
    // 落库收尾统一在这里 await，保证返回时数据库已写定。
    await doneCompleter.future;
    _doneCompleter = null;
    _subscription = null;
    _flushTimer?.cancel();
    _flushTimer = null;
    final messageId = _streamingMessageId;
    _streamingMessageId = null;
    final failure = _streamError;
    _streamError = null;
    if (messageId != null) {
      if (failure != null) {
        await repository.updateMessageContent(
          messageId,
          content: failure.userMessage,
          status: ChatMessageStatus.error,
        );
      } else {
        await repository.updateMessageContent(
          messageId,
          content: _buffer.toString(),
          status: ChatMessageStatus.done,
        );
      }
    }
    state = state.copyWith(isGenerating: false);
  }

  /// 停止生成：取消订阅（AiProvider 侧桥接 CancelToken，即时生效）。
  ///
  /// streaming 消息的落库（保留已生成内容、标记 done）由 send 的收尾完成。
  void stop() {
    final subscription = _subscription;
    if (subscription == null) {
      return;
    }
    unawaited(subscription.cancel());
    _doneCompleter?.complete();
  }

  void _scheduleFlush() {
    _flushTimer ??= Timer(_flushInterval, _flushNow);
  }

  void _flushNow() {
    _flushTimer = null;
    final messageId = _streamingMessageId;
    if (messageId == null) {
      return;
    }
    unawaited(
      ref.read(conversationRepositoryProvider).updateMessageContent(
        messageId,
        content: _buffer.toString(),
        status: ChatMessageStatus.streaming,
      ),
    );
  }
}

/// 会话列表流（置顶优先、按更新时间倒序）。
@riverpod
Stream<List<Conversation>> conversations(Ref ref) {
  return ref.watch(conversationRepositoryProvider).watchConversations();
}

/// 某会话的消息流。
@riverpod
Stream<List<ChatMessage>> chatMessages(Ref ref, String conversationId) {
  return ref
      .watch(conversationRepositoryProvider)
      .watchMessages(conversationId);
}
