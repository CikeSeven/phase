import 'package:json_annotation/json_annotation.dart';

part 'chat_message.g.dart';

/// 消息角色（AGENTS.md §3 约定取值）。
enum ChatRole { user, assistant, system }

/// 消息状态：流式中 / 完成 / 出错。
enum ChatMessageStatus { streaming, done, error }

/// 一条聊天消息。
///
/// 本地持久化时由 drift 表映射（见 app_database.dart）；
/// 发起请求时 role/content 会被映射为服务商协议的消息格式。
@JsonSerializable()
class ChatMessage {
  const ChatMessage({
    this.id,
    required this.role,
    required this.content,
    this.status = ChatMessageStatus.done,
    this.modelName,
    this.createdAt,
  });

  final String? id;
  final ChatRole role;
  final String content;
  final ChatMessageStatus status;

  /// AI 消息对应的模型名（气泡上方小字标注）。
  final String? modelName;

  final DateTime? createdAt;

  ChatMessage copyWith({
    String? id,
    ChatRole? role,
    String? content,
    ChatMessageStatus? status,
    String? modelName,
    DateTime? createdAt,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      status: status ?? this.status,
      modelName: modelName ?? this.modelName,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) =>
      _$ChatMessageFromJson(json);

  Map<String, dynamic> toJson() => _$ChatMessageToJson(this);
}
