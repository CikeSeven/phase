import '../data/models/api_protocol.dart';
import '../data/models/token_usage.dart';

/// 协议累计快照：仅替换本事件出现的字段（包括修订和无效值）。
/// 原始计数只存于本请求内；持久化的只有归一化字段及诊断字段名。
class UsageDecoder {
  UsageDecoder(this.protocol);
  final ApiProtocol protocol;
  final _raw = <String, dynamic>{};

  TokenUsage? add(Object? event) {
    if (event is! Map<String, dynamic>) return null;
    _merge(_raw, event);
    final counts = <UsageField, int>{};
    final sources = <UsageField, UsageSource>{};
    final invalid = <UsageField>{};
    // 在所有平台上都能精确表示、且在 SQLite 有符号整数范围内。
    const maxCount = 9007199254740991;
    void put(UsageField field, Object? value, {bool derived = false}) {
      if (value == null) return;
      if (value is! int || value < 0 || value > maxCount) {
        invalid.add(field);
        return;
      }
      counts[field] = value;
      sources[field] = derived ? UsageSource.derived : UsageSource.reported;
    }

    Object? detail(String key, String field) =>
        _raw[key] is Map ? (_raw[key] as Map)[field] : null;
    const p = UsageField.promptTokens;
    const u = UsageField.uncachedInputTokens;
    const r = UsageField.cacheReadTokens;
    const w = UsageField.cacheWriteTokens;
    const o = UsageField.outputTokens;
    const q = UsageField.reasoningTokens;
    const t = UsageField.totalTokens;
    var exactTotal = true;
    switch (protocol) {
      case ApiProtocol.openaiCompletions:
        put(p, _raw['prompt_tokens']);
        put(o, _raw['completion_tokens']);
        put(
          r,
          detail('prompt_tokens_details', 'cached_tokens') ??
              _raw['prompt_cache_hit_tokens'],
        );
        put(u, _raw['prompt_cache_miss_tokens']);
        put(q, detail('completion_tokens_details', 'reasoning_tokens'));
        put(t, _raw['total_tokens']);
      case ApiProtocol.openaiResponses:
        put(p, _raw['input_tokens']);
        put(o, _raw['output_tokens']);
        put(r, detail('input_tokens_details', 'cached_tokens'));
        put(q, detail('output_tokens_details', 'reasoning_tokens'));
        put(t, _raw['total_tokens']);
      case ApiProtocol.anthropicMessages:
        put(u, _raw['input_tokens']);
        put(r, _raw['cache_read_input_tokens']);
        put(w, _raw['cache_creation_input_tokens']);
        put(o, _raw['output_tokens']);
        // 不把网关省略的缓存桶假定为 0。
        if ([u, r, w].every(counts.containsKey)) {
          put(p, counts[u]! + counts[r]! + counts[w]!, derived: true);
        }
      case ApiProtocol.googleGenerativeAi:
        put(p, _raw['promptTokenCount']);
        put(r, _raw['cachedContentTokenCount']);
        put(q, _raw['thoughtsTokenCount']);
        put(t, _raw['totalTokenCount']);
        final candidate = _raw['candidatesTokenCount'];
        if (candidate != null &&
            (candidate is! int || candidate < 0 || candidate > maxCount)) {
          invalid.add(o);
        } else if (candidate is int) {
          if (counts[q] != null) {
            put(o, candidate + counts[q]!, derived: true);
          } else if (!invalid.contains(q) &&
              counts[t] != null &&
              counts[p] != null &&
              counts[t]! - counts[p]! == candidate) {
            put(o, candidate, derived: true);
          }
        }
        // Google 还可包含工具提示等明细；不把差额猜成推理或否定有效总数。
        exactTotal = false;
    }
    void reject(UsageField field) {
      counts.remove(field);
      sources.remove(field);
      invalid.add(field);
    }

    if (counts[p] != null && counts[r] != null && counts[r]! > counts[p]!) {
      reject(r);
    }
    if (counts[o] != null && counts[q] != null && counts[q]! > counts[o]!) {
      reject(q);
    }
    if (protocol != ApiProtocol.anthropicMessages &&
        counts[p] != null &&
        counts[r] != null) {
      if (counts[u] != null && counts[u]! + counts[r]! != counts[p]) {
        reject(u);
        reject(r);
      } else if (!invalid.contains(u)) {
        put(u, counts[p]! - counts[r]!, derived: !counts.containsKey(u));
      }
    }
    if (counts[p] != null && counts[o] != null) {
      final sum = counts[p]! + counts[o]!;
      if (counts[t] != null &&
          (exactTotal ? counts[t] != sum : counts[t]! < sum)) {
        reject(t);
      } else if (!counts.containsKey(t) && !invalid.contains(t)) {
        put(t, sum, derived: true);
      }
    }
    if (counts[t] != null &&
        ((counts[p] != null && counts[t]! < counts[p]!) ||
            (counts[o] != null && counts[t]! < counts[o]!))) {
      reject(t);
    }
    return TokenUsage(
      promptTokens: counts[p],
      uncachedInputTokens: counts[u],
      cacheReadTokens: counts[r],
      cacheWriteTokens: counts[w],
      outputTokens: counts[o],
      reasoningTokens: counts[q],
      totalTokens: counts[t],
      sources: Map.unmodifiable(sources),
      invalidFields: Set.unmodifiable(invalid),
    );
  }

  void _merge(Map<String, dynamic> target, Map<String, dynamic> patch) {
    for (final entry in patch.entries) {
      final value = entry.value;
      if (value is Map<String, dynamic> &&
          target[entry.key] is Map<String, dynamic>) {
        _merge(target[entry.key] as Map<String, dynamic>, value);
      } else {
        target[entry.key] = value is Map<String, dynamic>
            ? Map<String, dynamic>.from(value)
            : value;
      }
    }
  }
}
