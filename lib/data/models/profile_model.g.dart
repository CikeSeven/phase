// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProfileModel _$ProfileModelFromJson(Map<String, dynamic> json) => ProfileModel(
  id: json['id'] as String,
  supportsReasoning: json['supportsReasoning'] as bool? ?? false,
  reasoningEfforts:
      (json['reasoningEfforts'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
);

Map<String, dynamic> _$ProfileModelToJson(ProfileModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'supportsReasoning': instance.supportsReasoning,
      'reasoningEfforts': instance.reasoningEfforts,
    };
