import '../../data/models/chat_message.dart';
import '../../data/models/message_part.dart';
import 'model_retry.dart';

/// 消息列表中的当前重试项，由运行状态投影生成。
class ChatRetryMessage extends ChatMessage {
  ChatRetryMessage({
    required super.conversationId,
    required super.createdAt,
    required this.retry,
    super.parentId,
    super.runId,
  }) : super(
         id: 'model-retry:$conversationId',
         role: ChatRole.system,
         status: MessageStatus.streaming,
         parts: [if (retry.message.isNotEmpty) TextPart(text: retry.message)],
       );

  final ModelRetryState retry;

  @override
  bool get hasVisibleContent => true;
}
