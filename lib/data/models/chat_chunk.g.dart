// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_chunk.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ChatChunk _$ChatChunkFromJson(Map<String, dynamic> json) => ChatChunk(
  delta: json['delta'] as String,
  reasoningDelta: json['reasoningDelta'] as String?,
  done: json['done'] as bool? ?? false,
  usage: json['usage'] == null
      ? null
      : TokenUsage.fromJson(json['usage'] as Map<String, dynamic>),
  errorMessage: json['errorMessage'] as String?,
);

Map<String, dynamic> _$ChatChunkToJson(ChatChunk instance) => <String, dynamic>{
  'delta': instance.delta,
  'reasoningDelta': instance.reasoningDelta,
  'done': instance.done,
  'usage': instance.usage,
  'errorMessage': instance.errorMessage,
};

TokenUsage _$TokenUsageFromJson(Map<String, dynamic> json) => TokenUsage(
  promptTokens: (json['promptTokens'] as num?)?.toInt(),
  completionTokens: (json['completionTokens'] as num?)?.toInt(),
  totalTokens: (json['totalTokens'] as num?)?.toInt(),
);

Map<String, dynamic> _$TokenUsageToJson(TokenUsage instance) =>
    <String, dynamic>{
      'promptTokens': instance.promptTokens,
      'completionTokens': instance.completionTokens,
      'totalTokens': instance.totalTokens,
    };
