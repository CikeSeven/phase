import 'package:json_annotation/json_annotation.dart';

import 'chat_message.dart';
import 'reasoning_effort.dart';

part 'chat_request.g.dart';

/// 发起一次对话的请求，交给 [AiProvider.streamChat]。
///
/// 各厂商实现自行决定如何把 messages 映射为各自的协议格式；
/// 流式与否由实现内部决定（OpenAI 兼容实现固定 stream: true）。
@JsonSerializable(explicitToJson: true)
class ChatRequest {
  const ChatRequest({
    required this.model,
    required this.messages,
    this.temperature,
    this.reasoningEffort,
    this.maxTokens,
  });

  /// 模型名（如 `gpt-4o-mini`、`deepseek-chat`）。
  final String model;

  final List<ChatMessage> messages;

  final double? temperature;

  /// 推理等级；为 null 表示模型不支持推理，协议实现不下发任何推理字段。
  final ReasoningEffort? reasoningEffort;

  /// 最大输出 token；为 null 时不下发，由服务端默认决定。
  final int? maxTokens;

  factory ChatRequest.fromJson(Map<String, dynamic> json) =>
      _$ChatRequestFromJson(json);

  Map<String, dynamic> toJson() => _$ChatRequestToJson(this);
}
