import 'package:json_annotation/json_annotation.dart';

import 'chat_message.dart';

part 'chat_request.g.dart';

/// 发起一次对话的请求，交给 [AiProvider.streamChat]。
///
/// 各厂商实现自行决定如何把 messages 映射为各自的协议格式；
/// 流式与否由实现内部决定（OpenAI 兼容实现固定 stream: true）。
@JsonSerializable(explicitToJson: true)
class ChatRequest {
  const ChatRequest({required this.model, required this.messages, this.temperature});

  /// 模型名（如 `gpt-4o-mini`、`deepseek-chat`）。
  final String model;

  final List<ChatMessage> messages;

  final double? temperature;

  factory ChatRequest.fromJson(Map<String, dynamic> json) =>
      _$ChatRequestFromJson(json);

  Map<String, dynamic> toJson() => _$ChatRequestToJson(this);
}
