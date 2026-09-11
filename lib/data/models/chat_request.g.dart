// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ChatRequest _$ChatRequestFromJson(Map<String, dynamic> json) => ChatRequest(
  model: json['model'] as String,
  messages: (json['messages'] as List<dynamic>)
      .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
      .toList(),
  temperature: (json['temperature'] as num?)?.toDouble(),
  reasoningEffort: $enumDecodeNullable(
    _$ReasoningEffortEnumMap,
    json['reasoningEffort'],
  ),
  maxTokens: (json['maxTokens'] as num?)?.toInt(),
);

Map<String, dynamic> _$ChatRequestToJson(ChatRequest instance) =>
    <String, dynamic>{
      'model': instance.model,
      'messages': instance.messages.map((e) => e.toJson()).toList(),
      'temperature': instance.temperature,
      'reasoningEffort': _$ReasoningEffortEnumMap[instance.reasoningEffort],
      'maxTokens': instance.maxTokens,
    };

const _$ReasoningEffortEnumMap = {
  ReasoningEffort.off: 'off',
  ReasoningEffort.low: 'low',
  ReasoningEffort.medium: 'medium',
  ReasoningEffort.high: 'high',
  ReasoningEffort.xhigh: 'xhigh',
  ReasoningEffort.max: 'max',
};
