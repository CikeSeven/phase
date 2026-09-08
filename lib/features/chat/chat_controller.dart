import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/models/chat_message.dart';
import '../../../data/models/conversation.dart';
import '../../../data/repositories/conversation_repository.dart';

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

@riverpod
class ChatController extends _$ChatController {
  @override
  ChatState build() => const ChatState();

  void startNewConversation() {
    state = const ChatState();
  }

  void openConversation(String conversationId) {
    state = ChatState(conversationId: conversationId);
  }

  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.isGenerating) {
      return;
    }
    // TODO(chat): 接通发送链路——
    // 1. 无当前会话时先经 conversationRepository.createConversation 建会话；
    // 2. 持久化用户消息（appendMessage），state 置 isGenerating = true；
    // 3. 由选中的 ProviderProfile + SecureKeyStorage 读出的 Key
    //    经 buildAiProvider 构造 AiProvider；
    // 4. 订阅 streamChat：先插入一条 streaming 状态的 assistant 消息，
    //    按 ChatChunk 增量更新内容，done / 出错（Failure）时更新状态并落库。
  }

  void stop() {
    // TODO(chat): 取消 streamChat 订阅（AiProvider 已保证取消即时生效），
    // 并把 streaming 中的消息状态更新为 done / error。
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
  return ref.watch(conversationRepositoryProvider).watchMessages(conversationId);
}
