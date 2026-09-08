import 'package:json_annotation/json_annotation.dart';

part 'chat_chunk.g.dart';

/// 一次流式响应中的增量事件（各厂商协议适配后统一输出此类型）。
@JsonSerializable()
class ChatChunk {
  const ChatChunk({required this.delta, this.done = false, this.usage});

  /// 本次新增的文本片段（追加到气泡内容末尾）。
  final String delta;

  /// 是否为本次响应的最后一个事件。
  final bool done;

  /// token 用量，通常在最后一个事件中出现。
  final TokenUsage? usage;

  factory ChatChunk.fromJson(Map<String, dynamic> json) =>
      _$ChatChunkFromJson(json);

  Map<String, dynamic> toJson() => _$ChatChunkToJson(this);
}

@JsonSerializable()
class TokenUsage {
  const TokenUsage({this.promptTokens, this.completionTokens, this.totalTokens});

  final int? promptTokens;
  final int? completionTokens;
  final int? totalTokens;

  factory TokenUsage.fromJson(Map<String, dynamic> json) =>
      _$TokenUsageFromJson(json);

  Map<String, dynamic> toJson() => _$TokenUsageToJson(this);
}
