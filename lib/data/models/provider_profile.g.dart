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
      protocol:
          $enumDecodeNullable(_$ApiProtocolEnumMap, json['protocol']) ??
          ApiProtocol.openaiCompletions,
      presetId: json['presetId'] as String? ?? 'custom',
      models:
          (json['models'] as List<dynamic>?)
              ?.map((e) => ProfileModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      defaultModel: json['defaultModel'] as String?,
      compatOverrides: json['compatOverrides'] == null
          ? null
          : OpenAiCompat.fromJson(
              json['compatOverrides'] as Map<String, dynamic>,
            ),
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$ProviderProfileToJson(ProviderProfile instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'baseUrl': instance.baseUrl,
      'protocol': _$ApiProtocolEnumMap[instance.protocol]!,
      'presetId': instance.presetId,
      'models': instance.models.map((e) => e.toJson()).toList(),
      'defaultModel': instance.defaultModel,
      'compatOverrides': instance.compatOverrides?.toJson(),
      'createdAt': instance.createdAt?.toIso8601String(),
    };

const _$ApiProtocolEnumMap = {
  ApiProtocol.openaiCompletions: 'openaiCompletions',
  ApiProtocol.openaiResponses: 'openaiResponses',
  ApiProtocol.anthropicMessages: 'anthropicMessages',
  ApiProtocol.googleGenerativeAi: 'googleGenerativeAi',
};
