import '../../core/error/provider_error.dart';
import 'chat_message.dart';
import 'message_part.dart';

/// 一次响应中内容块的种类；增量事件按 [ChatChunk.partId] 归并。
enum PartKind { text, reasoning, toolCall, provider }

/// 流式响应事件（design 第五部分 §4.3）。
///
/// 适配器只产生这里定义的事件；增量与完成快照归并在同一 partId 上，
/// 完整快照不会作为增量重复追加。
sealed class ChatChunk {
  const ChatChunk();
}

/// 开始一个内容块；[partId] 在本次响应内稳定。
class PartStart extends ChatChunk {
  const PartStart({
    required this.partId,
    required this.kind,
    this.initialContent,
  });

  final String partId;
  final PartKind kind;

  /// 块的首段内容；没有时为 null。
  final String? initialContent;
}

/// 正文增量。
class TextDelta extends ChatChunk {
  const TextDelta({required this.partId, required this.text});

  final String partId;
  final String text;
}

/// 公开思考增量。
class ReasoningDelta extends ChatChunk {
  const ReasoningDelta({required this.partId, required this.text});

  final String partId;
  final String text;
}

/// 工具调用增量：只组装，不执行。
class ToolCallDelta extends ChatChunk {
  const ToolCallDelta({
    required this.partId,
    this.callId,
    this.toolName,
    this.argumentsFragment,
    this.providerData,
  });

  final String partId;

  /// Provider 侧调用 id；跨分片可能重复出现，以最后一次非空值为准。
  final String? callId;
  final String? toolName;

  /// 参数 JSON 的片段；只追加到当前调用缓冲，不逐段重新解析。
  final String? argumentsFragment;

  /// 该调用需要随后续请求回传的协议状态（如 Google 的 thoughtSignature）。
  final Map<String, dynamic>? providerData;
}

/// 结束一个内容块；[part] 为完整块，协议状态一并带上。
class PartEnd extends ChatChunk {
  const PartEnd({required this.partId, required this.part});

  final String partId;
  final MessagePart part;
}

/// 本次调用的用量。
class UsageChunk extends ChatChunk {
  const UsageChunk({required this.usage});

  final TokenUsage usage;
}

/// 响应收口；传输结束不一定代表协议正常完成。
class ResponseEnd extends ChatChunk {
  const ResponseEnd({this.hasVisibleContent = true, this.complete = true});

  /// 仅正常协议终态可以调度工具；EOF、输出截断等不能授予执行资格。
  final bool complete;

  /// 是否产生了可见内容；全空响应由运行层记为失败。
  final bool hasVisibleContent;
}

/// 流内错误（如 HTTP 200 的 SSE 中夹带的错误事件）。
class ResponseError extends ChatChunk {
  const ResponseError({required this.error});

  final ProviderError error;
}
