import 'message_part.dart';

/// 消息角色（AGENTS.md §3 约定取值）。
enum ChatRole { user, assistant, system, tool }

/// 消息状态；流式中的消息在正常结束或停止后落到终态。
enum MessageStatus { streaming, completed, failed, cancelled }

/// 一次模型调用的用量；接口未提供时字段为 null，不把缺失值当成真实的零。
///
/// 同时承载数据库 usage_json 列与请求响应中的用量。
class TokenUsage {
  const TokenUsage({
    this.inputTokens,
    this.outputTokens,
    this.reasoningTokens,
    this.cachedInputTokens,
    this.estimated = false,
  });

  final int? inputTokens;
  final int? outputTokens;
  final int? reasoningTokens;
  final int? cachedInputTokens;

  /// 是否为本地估算值；来自接口 usage 时为 false。
  final bool estimated;

  Map<String, dynamic> toJson() => {
    if (inputTokens != null) 'inputTokens': inputTokens,
    if (outputTokens != null) 'outputTokens': outputTokens,
    if (reasoningTokens != null) 'reasoningTokens': reasoningTokens,
    if (cachedInputTokens != null) 'cachedInputTokens': cachedInputTokens,
    if (estimated) 'estimated': true,
  };

  factory TokenUsage.fromJson(Map<String, dynamic> json) => TokenUsage(
    inputTokens: json['inputTokens'] as int?,
    outputTokens: json['outputTokens'] as int?,
    reasoningTokens: json['reasoningTokens'] as int?,
    cachedInputTokens: json['cachedInputTokens'] as int?,
    estimated: json['estimated'] as bool? ?? false,
  );
}

/// 一条聊天消息。
///
/// 内容按 [parts] 顺序承载，工具调用与结果只引用 ToolCallRecord 的 id；
/// 会话结构由 [parentId] 组成消息树，[conversationId] + 分支指针定位当前分支。
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.role,
    this.parentId,
    this.runId,
    this.status = MessageStatus.completed,
    this.parts = const [],
    this.modelLabel,
    this.usage,
    this.thinkingDurationMs,
    required this.createdAt,
  });

  final String id;
  final String conversationId;

  /// 消息树父指针；null 表示当前会话的第一条消息。
  final String? parentId;

  /// 产生该消息的运行；用户输入消息与助手回答同属一次运行。
  final String? runId;

  final ChatRole role;
  final MessageStatus status;
  final List<MessagePart> parts;

  /// 产生该消息的模型展示名；用户消息为 null。
  final String? modelLabel;

  final TokenUsage? usage;
  final int? thinkingDurationMs;
  final DateTime createdAt;

  /// 拼接正文 TextPart；工具消息的正文由工具记录承载。
  String get text =>
      parts.whereType<TextPart>().map((part) => part.text).join();

  bool get hasVisibleContent => parts.any(
    (part) => switch (part) {
      TextPart() => part.text.isNotEmpty,
      ReasoningPart() => part.publicText.isNotEmpty,
      ImagePart() || DocumentPart() => true,
      ToolCallPart() || ToolResultPart() => true,
      ProviderPart() => false,
    },
  );

  ChatMessage copyWith({
    String? parentId,
    String? runId,
    MessageStatus? status,
    List<MessagePart>? parts,
    String? modelLabel,
    TokenUsage? usage,
    int? thinkingDurationMs,
  }) {
    return ChatMessage(
      id: id,
      conversationId: conversationId,
      role: role,
      parentId: parentId ?? this.parentId,
      runId: runId ?? this.runId,
      status: status ?? this.status,
      parts: parts ?? this.parts,
      modelLabel: modelLabel ?? this.modelLabel,
      usage: usage ?? this.usage,
      thinkingDurationMs: thinkingDurationMs ?? this.thinkingDurationMs,
      createdAt: createdAt,
    );
  }
}
