// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'provider_profile.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProviderProfile _$ProviderProfileFromJson(Map<String, dynamic> json) =>
    ProviderProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      baseUrl: json['baseUrl'] as String,
      type:
          $enumDecodeNullable(_$ProviderTypeEnumMap, json['type']) ??
          ProviderType.openaiCompatible,
      models:
          (json['models'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      defaultModel: json['defaultModel'] as String?,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$ProviderProfileToJson(ProviderProfile instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'baseUrl': instance.baseUrl,
      'type': _$ProviderTypeEnumMap[instance.type]!,
      'models': instance.models,
      'defaultModel': instance.defaultModel,
      'createdAt': instance.createdAt?.toIso8601String(),
    };

const _$ProviderTypeEnumMap = {
  ProviderType.openaiCompatible: 'openaiCompatible',
};
