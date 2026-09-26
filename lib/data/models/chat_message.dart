import 'token_usage.dart';
import 'message_part.dart';

/// 消息角色（AGENTS.md §3 约定取值）。
enum ChatRole { user, assistant, system, tool }

/// 消息状态；流式中的消息在正常结束或停止后落到终态。
enum MessageStatus { streaming, completed, failed, cancelled }

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
    this.requestId,
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

  final String? requestId;

  /// 从请求记录联表取得的只读投影，不写回消息表。
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
      ProviderPart() || RuntimeContextPart() => false,
    },
  );

  /// 复制到另一个会话（会话内复制时同时换新 id）。
  ChatMessage copyTo({
    required String conversationId,
    String? id,
    String? parentId,
    List<MessagePart>? parts,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      conversationId: conversationId,
      parentId: parentId,
      runId: runId,
      role: role,
      status: status,
      parts: parts ?? this.parts,
      modelLabel: modelLabel,
      requestId: requestId,
      usage: usage,
      thinkingDurationMs: thinkingDurationMs,
      createdAt: createdAt,
    );
  }

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
      requestId: requestId,
      usage: usage ?? this.usage,
      thinkingDurationMs: thinkingDurationMs ?? this.thinkingDurationMs,
      createdAt: createdAt,
    );
  }
}
