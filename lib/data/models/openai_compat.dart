import 'package:json_annotation/json_annotation.dart';

part 'openai_compat.g.dart';

/// reasoningEffort 在 OpenAI 兼容协议里的下发格式。
enum ThinkingFormat {
  /// 顶层 `reasoning_effort: minimal|low|medium|high`（off 不下发）。
  openai,

  /// `reasoning: {effort}`（off → `reasoning: {effort: none}`）。
  openrouter,

  /// `thinking: {type: enabled|disabled}`（DeepSeek，无等级之分）。
  deepseek,

  /// 顶层 `enable_thinking: bool`（off/low → false，其余 true）。
  qwen,
}

/// OpenAI 兼容协议的差异声明。
///
/// 服务商差异是数据而不是分支：默认值按 baseUrl 嗅探，profile 可覆盖。
@JsonSerializable()
class OpenAiCompat {
  const OpenAiCompat({
    this.maxTokensField = 'max_completion_tokens',
    this.supportsDeveloperRole = true,
    this.thinkingFormat = ThinkingFormat.openai,
  });

  /// 请求里 max tokens 的字段名：`max_tokens` | `max_completion_tokens`。
  final String maxTokensField;

  /// system 消息是否映射为 `developer` 角色。
  final bool supportsDeveloperRole;

  final ThinkingFormat thinkingFormat;

  /// 按 baseUrl 嗅探默认 compat（覆盖常见推理服务商）。
  static OpenAiCompat sniff(String baseUrl) {
    final url = baseUrl.toLowerCase();
    if (url.contains('api.deepseek.com')) {
      return const OpenAiCompat(
        maxTokensField: 'max_tokens',
        supportsDeveloperRole: false,
        thinkingFormat: ThinkingFormat.deepseek,
      );
    }
    if (url.contains('openrouter.ai')) {
      return const OpenAiCompat(
        supportsDeveloperRole: false,
        thinkingFormat: ThinkingFormat.openrouter,
      );
    }
    if (url.contains('api.moonshot')) {
      return const OpenAiCompat(maxTokensField: 'max_tokens');
    }
    if (url.contains('dashscope') || url.contains('aliyuncs.com')) {
      return const OpenAiCompat(thinkingFormat: ThinkingFormat.qwen);
    }
    return const OpenAiCompat();
  }

  /// 以 [sniff] 结果为底、profile 覆盖优先解析最终 compat。
  static OpenAiCompat resolve(String baseUrl, OpenAiCompat? overrides) {
    final detected = sniff(baseUrl);
    if (overrides == null) {
      return detected;
    }
    return OpenAiCompat(
      maxTokensField: overrides.maxTokensField,
      supportsDeveloperRole: overrides.supportsDeveloperRole,
      thinkingFormat: overrides.thinkingFormat,
    );
  }

  factory OpenAiCompat.fromJson(Map<String, dynamic> json) =>
      _$OpenAiCompatFromJson(json);

  Map<String, dynamic> toJson() => _$OpenAiCompatToJson(this);
}
