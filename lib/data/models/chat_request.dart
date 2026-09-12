import 'attachment.dart';
import 'chat_message.dart';
import 'reasoning_effort.dart';
import 'tool_policy.dart';

/// 一次请求中使用的一条消息；由 ContextBuilder 从消息与工具记录解析得到。
///
/// 这不是第二套持久化格式：它只描述"这一次请求要发什么"。
class ResolvedMessage {
  const ResolvedMessage({required this.role, required this.parts});

  final ChatRole role;
  final List<ResolvedPart> parts;
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
  });

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
  });

  final String callId;
  final String content;
  final bool isError;
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
  });

  final String modelId;
  final List<ResolvedMessage> messages;
  final String systemPrompt;

  /// 本次运行开放给模型的工具；为空表示本次不发送工具定义。
  final List<ToolDefinition> tools;

  final ReasoningEffort reasoningEffort;
  final double? temperature;
  final int? maxOutputTokens;
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
