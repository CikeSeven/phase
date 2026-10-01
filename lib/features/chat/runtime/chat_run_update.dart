import '../../../data/models/attachment.dart';
import '../../../data/models/message_part.dart';
import '../context/context_builder.dart';
import '../model_retry.dart';

/// 运行只发布展示快照；业务记录由运行组件直接等待仓储提交。
typedef ChatRunObserver = void Function(ChatRunUpdate update);

sealed class ChatRunUpdate {
  const ChatRunUpdate(this.runId, this.conversationId);
  final String runId;
  final String conversationId;
}

final class ChatRunStarted extends ChatRunUpdate {
  const ChatRunStarted(super.runId, super.conversationId, this.attachments);
  final Map<String, Attachment> attachments;
}

final class ChatStreamingStarted extends ChatRunUpdate {
  const ChatStreamingStarted(super.runId, super.conversationId, this.messageId);
  final String messageId;
}

final class ChatStreamingChanged extends ChatRunUpdate {
  const ChatStreamingChanged(super.runId, super.conversationId, this.parts);
  final List<MessagePart> parts;
}

final class ChatStreamingFinished extends ChatRunUpdate {
  const ChatStreamingFinished(super.runId, super.conversationId);
}

final class ChatRetryChanged extends ChatRunUpdate {
  const ChatRetryChanged(super.runId, super.conversationId, this.retry);
  final ModelRetryState? retry;
}

final class ChatContextMeasured extends ChatRunUpdate {
  const ChatContextMeasured(super.runId, super.conversationId, this.context);
  final ContextBuild context;
}

final class ChatSummarizingChanged extends ChatRunUpdate {
  const ChatSummarizingChanged(super.runId, super.conversationId, this.value);
  final bool value;
}

final class ChatAttachmentsChanged extends ChatRunUpdate {
  const ChatAttachmentsChanged(
    super.runId,
    super.conversationId,
    this.attachments,
  );
  final Map<String, Attachment> attachments;
}
