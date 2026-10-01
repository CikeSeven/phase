import '../../data/models/attachment.dart';
import '../../data/models/message_part.dart';
import 'context/context_builder.dart';
import 'model_retry.dart';

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
    this.savingPermissionMode = false,
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
  final bool savingPermissionMode;
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
    bool? savingPermissionMode,
    ContextBuild? contextBuild,
    String? contextConversationId,
    bool? summarizing,
    bool clearContext = false,
  }) {
    return ChatState(
      savingPermissionMode: savingPermissionMode ?? this.savingPermissionMode,
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
