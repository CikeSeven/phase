// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProfileModel _$ProfileModelFromJson(Map<String, dynamic> json) => ProfileModel(
  id: json['id'] as String,
  displayName: json['displayName'] as String?,
  enabled: json['enabled'] as bool? ?? true,
  supportsReasoning: json['supportsReasoning'] as bool? ?? false,
  supportsTools: json['supportsTools'] as bool? ?? true,
  supportsImages: json['supportsImages'] as bool? ?? true,
  contextWindow: (json['contextWindow'] as num?)?.toInt(),
  maxOutputTokens: (json['maxOutputTokens'] as num?)?.toInt(),
);

Map<String, dynamic> _$ProfileModelToJson(ProfileModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'displayName': instance.displayName,
      'enabled': instance.enabled,
      'supportsReasoning': instance.supportsReasoning,
      'supportsTools': instance.supportsTools,
      'supportsImages': instance.supportsImages,
      'contextWindow': instance.contextWindow,
      'maxOutputTokens': instance.maxOutputTokens,
    };
