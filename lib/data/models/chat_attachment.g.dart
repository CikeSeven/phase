// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_attachment.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ChatAttachment _$ChatAttachmentFromJson(Map<String, dynamic> json) =>
    ChatAttachment(
      id: json['id'] as String,
      type: $enumDecode(_$ChatAttachmentTypeEnumMap, json['type']),
      name: json['name'] as String,
      mimeType: json['mimeType'] as String,
      path: json['path'] as String,
      size: (json['size'] as num).toInt(),
    );

Map<String, dynamic> _$ChatAttachmentToJson(ChatAttachment instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': _$ChatAttachmentTypeEnumMap[instance.type]!,
      'name': instance.name,
      'mimeType': instance.mimeType,
      'path': instance.path,
      'size': instance.size,
    };

const _$ChatAttachmentTypeEnumMap = {
  ChatAttachmentType.image: 'image',
  ChatAttachmentType.file: 'file',
};
