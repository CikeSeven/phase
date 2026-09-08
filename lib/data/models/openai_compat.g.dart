// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'openai_compat.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OpenAiCompat _$OpenAiCompatFromJson(Map<String, dynamic> json) => OpenAiCompat(
  maxTokensField: json['maxTokensField'] as String? ?? 'max_completion_tokens',
  supportsDeveloperRole: json['supportsDeveloperRole'] as bool? ?? true,
  thinkingFormat:
      $enumDecodeNullable(_$ThinkingFormatEnumMap, json['thinkingFormat']) ??
      ThinkingFormat.openai,
);

Map<String, dynamic> _$OpenAiCompatToJson(OpenAiCompat instance) =>
    <String, dynamic>{
      'maxTokensField': instance.maxTokensField,
      'supportsDeveloperRole': instance.supportsDeveloperRole,
      'thinkingFormat': _$ThinkingFormatEnumMap[instance.thinkingFormat]!,
    };

const _$ThinkingFormatEnumMap = {
  ThinkingFormat.openai: 'openai',
  ThinkingFormat.openrouter: 'openrouter',
  ThinkingFormat.deepseek: 'deepseek',
  ThinkingFormat.qwen: 'qwen',
};
