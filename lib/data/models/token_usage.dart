/// 仅承载服务端用量；本地上下文估算不进入此模型。
enum UsageField {
  promptTokens,
  uncachedInputTokens,
  cacheReadTokens,
  cacheWriteTokens,
  outputTokens,
  reasoningTokens,
  totalTokens,
}

enum UsageSource { reported, derived }

class TokenUsage {
  const TokenUsage({
    this.promptTokens,
    this.uncachedInputTokens,
    this.cacheReadTokens,
    this.cacheWriteTokens,
    this.outputTokens,
    this.reasoningTokens,
    this.totalTokens,
    this.sources = const {},
    this.invalidFields = const {},
  });

  final int? promptTokens;
  final int? uncachedInputTokens;
  final int? cacheReadTokens;
  final int? cacheWriteTokens;

  /// 包含 reasoningTokens，不可再与推理相加。
  final int? outputTokens;
  final int? reasoningTokens;
  final int? totalTokens;
  final Map<UsageField, UsageSource> sources;
  final Set<UsageField> invalidFields;

  int? value(UsageField field) => invalidFields.contains(field)
      ? null
      : switch (field) {
          UsageField.promptTokens => promptTokens,
          UsageField.uncachedInputTokens => uncachedInputTokens,
          UsageField.cacheReadTokens => cacheReadTokens,
          UsageField.cacheWriteTokens => cacheWriteTokens,
          UsageField.outputTokens => outputTokens,
          UsageField.reasoningTokens => reasoningTokens,
          UsageField.totalTokens => totalTokens,
        };

  UsageSource? source(UsageField field) =>
      value(field) == null ? null : sources[field] ?? UsageSource.reported;

  double? get cacheHitRate =>
      (value(UsageField.promptTokens) ?? 0) > 0 &&
          value(UsageField.cacheReadTokens) != null
      ? cacheReadTokens! / promptTokens!
      : null;

  /// 总数可能还有协议未提供的分项，不把差额猜成缓存或推理。
  bool get hasUnexplainedTotal =>
      value(UsageField.totalTokens) != null &&
      (value(UsageField.promptTokens) == null ||
          value(UsageField.outputTokens) == null ||
          totalTokens != promptTokens! + outputTokens!);

  Map<String, dynamic> toJson() => {
    for (final field in UsageField.values) field.name: ?value(field),
    'sources': {
      for (final field in UsageField.values)
        if (source(field) case final origin?) field.name: origin.name,
    },
    'invalidFields': invalidFields.map((f) => f.name).toList(),
  };

  factory TokenUsage.fromJson(Map<String, dynamic> json) => TokenUsage(
    promptTokens: json['promptTokens'] as int?,
    uncachedInputTokens: json['uncachedInputTokens'] as int?,
    cacheReadTokens: json['cacheReadTokens'] as int?,
    cacheWriteTokens: json['cacheWriteTokens'] as int?,
    outputTokens: json['outputTokens'] as int?,
    reasoningTokens: json['reasoningTokens'] as int?,
    totalTokens: json['totalTokens'] as int?,
    sources: {
      for (final entry
          in (json['sources'] as Map<String, dynamic>? ?? {}).entries)
        UsageField.values.byName(entry.key): UsageSource.values.byName(
          entry.value as String,
        ),
    },
    invalidFields: {
      for (final field in json['invalidFields'] as List? ?? [])
        UsageField.values.byName(field as String),
    },
  );
}
