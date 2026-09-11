// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ChatMessage _$ChatMessageFromJson(Map<String, dynamic> json) => ChatMessage(
  id: json['id'] as String?,
  role: $enumDecode(_$ChatRoleEnumMap, json['role']),
  content: json['content'] as String,
  status:
      $enumDecodeNullable(_$ChatMessageStatusEnumMap, json['status']) ??
      ChatMessageStatus.done,
  modelName: json['modelName'] as String?,
  reasoning: json['reasoning'] as String?,
  attachments:
      (json['attachments'] as List<dynamic>?)
          ?.map((e) => ChatAttachment.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  thinkingDuration: json['thinkingDuration'] == null
      ? null
      : Duration(microseconds: (json['thinkingDuration'] as num).toInt()),
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$ChatMessageToJson(ChatMessage instance) =>
    <String, dynamic>{
      'id': instance.id,
      'role': _$ChatRoleEnumMap[instance.role]!,
      'content': instance.content,
      'status': _$ChatMessageStatusEnumMap[instance.status]!,
      'modelName': instance.modelName,
      'reasoning': instance.reasoning,
      'attachments': instance.attachments.map((e) => e.toJson()).toList(),
      'thinkingDuration': instance.thinkingDuration?.inMicroseconds,
      'createdAt': instance.createdAt?.toIso8601String(),
    };

const _$ChatRoleEnumMap = {
  ChatRole.user: 'user',
  ChatRole.assistant: 'assistant',
  ChatRole.system: 'system',
};

const _$ChatMessageStatusEnumMap = {
  ChatMessageStatus.streaming: 'streaming',
  ChatMessageStatus.done: 'done',
  ChatMessageStatus.error: 'error',
};
