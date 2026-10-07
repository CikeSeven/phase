import '../../data/models/attachment.dart';
import '../../data/models/message_part.dart';
import 'context/context_builder.dart';
import 'model_retry.dart';

/// 聊天页的当前会话投影，以及其他会话各自保留的运行展示状态。
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
    this.activeConversationId,
    this.sessions = const {},
    this.completedConversationIds = const {},
  });

  final List<MessagePart> streamingParts;
  final Map<String, Attachment> attachments;
  final bool isGenerating;
  final String? runningConversationId;
  final String? streamingMessageId;
  final ModelRetryState? retry;
  final bool savingPermissionMode;
  final ContextBuild? contextBuild;
  final String? contextConversationId;
  final bool summarizing;
  final String? activeConversationId;
  final Map<String, ChatSessionState> sessions;
  final Set<String> completedConversationIds;

  List<String> get runningConversationIds {
    final activeRunning = isGenerating && activeConversationId != null;
    final ids = [
      for (final entry in sessions.entries)
        if (entry.value.isGenerating) entry.key,
    ];
    if (activeRunning && !ids.contains(activeConversationId)) {
      ids.add(activeConversationId!);
    }
    return ids;
  }

  /// 某会话是否正在运行（包含当前正在生成或后台会话正在生成）。
  bool isConversationRunning(String conversationId) {
    if (activeConversationId == conversationId &&
        (isGenerating || retry != null)) {
      return true;
    }
    final session = sessions[conversationId];
    return session?.isGenerating == true || session?.retry != null;
  }

  /// 某会话是否刚刚完成任务且尚未被用户点开查看。
  bool isConversationCompleted(String conversationId) {
    if (activeConversationId == conversationId ||
        isConversationRunning(conversationId)) {
      return false;
    }
    return completedConversationIds.contains(conversationId);
  }

  ChatState markConversationCompleted(String conversationId) {
    if (completedConversationIds.contains(conversationId)) return this;
    return _copyRaw(
      completedConversationIds: {...completedConversationIds, conversationId},
    );
  }

  ChatState clearCompleted(String conversationId) {
    if (!completedConversationIds.contains(conversationId)) return this;
    return _copyRaw(
      completedConversationIds: {...completedConversationIds}
        ..remove(conversationId),
    );
  }

  ChatState forConversation(String? conversationId) {
    if (conversationId == null) {
      return ChatState(
        activeConversationId: null,
        sessions: sessions,
        completedConversationIds: completedConversationIds,
      );
    }
    final session = sessions[conversationId];
    return ChatState(
      streamingParts: session?.streamingParts ?? const [],
      attachments: session?.attachments ?? const {},
      isGenerating: session?.isGenerating ?? false,
      runningConversationId: session?.runningConversationId,
      streamingMessageId: session?.streamingMessageId,
      retry: session?.retry,
      savingPermissionMode: session?.savingPermissionMode ?? false,
      contextBuild: session?.contextBuild,
      contextConversationId: session?.contextConversationId,
      summarizing: session?.summarizing ?? false,
      activeConversationId: conversationId,
      sessions: sessions,
      completedConversationIds: completedConversationIds,
    );
  }

  ChatState selectConversation(String? conversationId) {
    final retained = {
      for (final entry in sessions.entries)
        if (entry.key == conversationId || entry.value.isGenerating)
          entry.key: entry.value,
    };
    return forConversation(conversationId)._copyRaw(sessions: retained);
  }

  ChatState removeConversation(String conversationId) {
    if (activeConversationId == conversationId) return this;
    return _copyRaw(sessions: {...sessions}..remove(conversationId));
  }

  ChatState updateConversation(
    String conversationId,
    ChatState Function(ChatState state) update,
  ) {
    final changed = update(forConversation(conversationId));
    final mergedSessions = {
      ...sessions,
      conversationId: ChatSessionState.fromState(changed),
    };
    if (activeConversationId == conversationId) {
      return changed._copyRaw(
        activeConversationId: activeConversationId,
        sessions: mergedSessions,
        completedConversationIds: changed.completedConversationIds,
      );
    }
    return _copyRaw(
      sessions: mergedSessions,
      completedConversationIds: changed.completedConversationIds,
    );
  }

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
    Map<String, ChatSessionState>? sessions,
    Set<String>? completedConversationIds,
  }) {
    final updated = _copyRaw(
      streamingParts: clearStreaming
          ? const []
          : streamingParts ?? this.streamingParts,
      attachments: attachments ?? this.attachments,
      isGenerating: isGenerating ?? this.isGenerating,
      runningConversationId:
          runningConversationId ?? this.runningConversationId,
      streamingMessageId: streamingMessageId ?? this.streamingMessageId,
      retry: retry ?? this.retry,
      savingPermissionMode: savingPermissionMode ?? this.savingPermissionMode,
      contextBuild: contextBuild ?? this.contextBuild,
      contextConversationId:
          contextConversationId ?? this.contextConversationId,
      summarizing: clearRun ? false : summarizing ?? this.summarizing,
      sessions: sessions ?? this.sessions,
      completedConversationIds:
          completedConversationIds ?? this.completedConversationIds,
      clearRun: clearRun,
      clearStreaming: clearStreaming,
      clearRetry: clearRetry || clearRun,
      clearContext: clearContext,
    );
    final conversationId = updated.activeConversationId;
    if (conversationId == null) return updated;
    return updated._copyRaw(
      sessions: {
        ...updated.sessions,
        conversationId: ChatSessionState.fromState(updated),
      },
    );
  }

  ChatState _copyRaw({
    List<MessagePart>? streamingParts,
    Map<String, Attachment>? attachments,
    bool? isGenerating,
    String? runningConversationId,
    String? streamingMessageId,
    ModelRetryState? retry,
    bool? savingPermissionMode,
    ContextBuild? contextBuild,
    String? contextConversationId,
    bool? summarizing,
    bool clearRun = false,
    bool clearStreaming = false,
    bool clearRetry = false,
    bool clearContext = false,
    String? activeConversationId,
    Map<String, ChatSessionState>? sessions,
    Set<String>? completedConversationIds,
  }) => ChatState(
    streamingParts: streamingParts ?? this.streamingParts,
    attachments: attachments ?? this.attachments,
    isGenerating: isGenerating ?? this.isGenerating,
    runningConversationId: clearRun
        ? null
        : runningConversationId ?? this.runningConversationId,
    streamingMessageId: clearStreaming
        ? null
        : streamingMessageId ?? this.streamingMessageId,
    retry: clearRetry ? null : retry ?? this.retry,
    savingPermissionMode: savingPermissionMode ?? this.savingPermissionMode,
    contextBuild: clearContext ? null : contextBuild ?? this.contextBuild,
    contextConversationId: clearContext
        ? null
        : contextConversationId ?? this.contextConversationId,
    summarizing: summarizing ?? this.summarizing,
    activeConversationId: activeConversationId ?? this.activeConversationId,
    sessions: sessions ?? this.sessions,
    completedConversationIds:
        completedConversationIds ?? this.completedConversationIds,
  );
}

/// Persistable-in-memory view for one conversation; message history stays in
/// the repository and only transient run presentation is retained here.
class ChatSessionState {
  const ChatSessionState({
    required this.streamingParts,
    required this.attachments,
    required this.isGenerating,
    required this.runningConversationId,
    required this.streamingMessageId,
    required this.retry,
    required this.savingPermissionMode,
    required this.contextBuild,
    required this.contextConversationId,
    required this.summarizing,
  });

  final List<MessagePart> streamingParts;
  final Map<String, Attachment> attachments;
  final bool isGenerating;
  final String? runningConversationId;
  final String? streamingMessageId;
  final ModelRetryState? retry;
  final bool savingPermissionMode;
  final ContextBuild? contextBuild;
  final String? contextConversationId;
  final bool summarizing;

  factory ChatSessionState.fromState(ChatState state) => ChatSessionState(
    streamingParts: state.streamingParts,
    attachments: state.attachments,
    isGenerating: state.isGenerating,
    runningConversationId: state.runningConversationId,
    streamingMessageId: state.streamingMessageId,
    retry: state.retry,
    savingPermissionMode: state.savingPermissionMode,
    contextBuild: state.contextBuild,
    contextConversationId: state.contextConversationId,
    summarizing: state.summarizing,
  );
}
