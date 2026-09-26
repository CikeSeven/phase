import 'attachment.dart';
import 'chat_message.dart';
import 'reasoning_effort.dart';
import 'tool_policy.dart';

/// 一次请求中使用的一条消息；由 ContextBuilder 从消息与工具记录解析得到。
///
/// 这不是第二套持久化格式：它只描述"这一次请求要发什么"。
class ResolvedMessage {
  const ResolvedMessage({
    required this.role,
    required this.parts,
    this.sameModel = true,
    this.sourceMessageId,
    this.runtimeContextSections = const {},
  });

  final String? sourceMessageId;
  final ChatRole role;
  final List<ResolvedPart> parts;

  /// 已落库的宿主状态分区；只有宿主消息可设置，普通 system 消息保持原协议语义。
  final Set<String> runtimeContextSections;
  bool get isRuntimeContext => runtimeContextSections.isNotEmpty;

  /// 这条消息是否由当前模型产生。
  ///
  /// 跨模型时协议状态（思考签名、加密推理）不再回传：签名只对生成它的模型
  /// 有效，送回去会被判为非法（pi 的 transform-messages 同样按此分档）。
  final bool sameModel;
}

/// 请求中的内容块：正文、思考、图片、工具调用与工具结果。
sealed class ResolvedPart {
  const ResolvedPart();
}

class ResolvedText extends ResolvedPart {
  const ResolvedText(this.text);

  final String text;
}

/// 公开思考文本；仅在所选协议要求把思考带回上下文时使用。
class ResolvedReasoning extends ResolvedPart {
  const ResolvedReasoning(this.text, {this.providerData});

  final String text;

  /// 回传该块所需的协议状态（如 Anthropic 的 signature）。
  final Map<String, dynamic>? providerData;
}

class ResolvedImage extends ResolvedPart {
  const ResolvedImage(this.attachment);

  final Attachment attachment;
}

/// 模型提出的工具调用，按协议要求回填。
class ResolvedToolCall extends ResolvedPart {
  const ResolvedToolCall({
    required this.callId,
    required this.toolName,
    required this.arguments,
    this.providerData,
    this.recordId,
    this.historyReadOnly = false,
  });

  final String? recordId;
  final bool historyReadOnly;

  /// Provider 侧的调用 id。
  final String callId;
  final String toolName;
  final Map<String, dynamic> arguments;
  final Map<String, dynamic>? providerData;
}

/// 工具结果；是否成功由 [isError] 表达，而不是靠文案。
class ResolvedToolResult extends ResolvedPart {
  const ResolvedToolResult({
    required this.callId,
    required this.content,
    this.isError = false,
    this.images = const [],
    this.visualImageTurnId,
    this.omittedImages = const [],
    this.artifactIds = const [],
    this.recordId,
    this.status,
    this.closed = true,
  });

  final String callId;
  final String content;
  final bool isError;
  final String? recordId;
  final String? status;
  final bool closed;

  /// Tool-produced images; persisted attachments remain the source of truth.
  final List<Attachment> images;

  /// 宿主设备观察所属的助手轮次；同轮图片一起保留，MCP 图片不参与淘汰。
  final String? visualImageTurnId;

  /// 被更新观察替换的图片引用，只用于还原历史计量前缀，不发送给模型。
  final List<Attachment> omittedImages;

  /// 摘要保留的产物引用；不改变协议的原始结果内容。
  final List<String> artifactIds;
}

/// 交给 [AiProvider.streamChat] 的请求。
///
/// 未启用的工具不进入 [tools]；不支持推理的模型不带推理字段。
class ChatRequest {
  const ChatRequest({
    required this.modelId,
    required this.messages,
    this.systemPrompt = '',
    this.tools = const [],
    this.reasoningEffort = ReasoningEffort.off,
    this.temperature,
    this.maxOutputTokens,
    this.preparedPayload,
  });

  final String modelId;
  final List<ResolvedMessage> messages;
  final String systemPrompt;

  /// 本次运行开放给模型的工具；为空表示本次不发送工具定义。
  final List<ToolDefinition> tools;

  final ReasoningEffort reasoningEffort;
  final double? temperature;
  final int? maxOutputTokens;

  /// 适配器规划得到的本次网络体，仅驻留内存，不持久化或记录日志。
  final Map<String, dynamic>? preparedPayload;

  ChatRequest copyWith({
    List<ResolvedMessage>? messages,
    Map<String, dynamic>? preparedPayload,
  }) => ChatRequest(
    modelId: modelId,
    messages: messages ?? this.messages,
    systemPrompt: systemPrompt,
    tools: tools,
    reasoningEffort: reasoningEffort,
    temperature: temperature,
    maxOutputTokens: maxOutputTokens,
    preparedPayload: preparedPayload,
  );
}

/// 工具定义：名称、描述、参数 schema、所需能力与默认策略。
abstract interface class ToolDefinition {
  String get name;
  String get description;

  /// JSON Schema 形式的参数定义。
  Map<String, dynamic> get inputSchema;

  /// 执行该工具需要的通道能力（文件、无障碍等）。
  Set<String> get requiredCapabilities;

  ToolPolicy get defaultPolicy;

  /// 展示给用户确认页的动作摘要。
  String describeAction(Map<String, dynamic> arguments);
}
