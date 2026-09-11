// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProfileModel _$ProfileModelFromJson(Map<String, dynamic> json) => ProfileModel(
  id: json['id'] as String,
  enabled: json['enabled'] as bool? ?? true,
  supportsReasoning: json['supportsReasoning'] as bool? ?? true,
  supportsTools: json['supportsTools'] as bool? ?? true,
  supportsImages: json['supportsImages'] as bool? ?? true,
);

Map<String, dynamic> _$ProfileModelToJson(ProfileModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'enabled': instance.enabled,
      'supportsReasoning': instance.supportsReasoning,
      'supportsTools': instance.supportsTools,
      'supportsImages': instance.supportsImages,
    };
