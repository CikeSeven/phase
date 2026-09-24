import 'dart:convert';

/// models.dev 目录的本地瘦身表示：只承载 `limit.context` / `limit.output`，
/// 用于上下文窗口与输出预留的自动解析。数据来自社区维护的 models.dev，
/// 准确性以服务商实际行为为准；用户手填值始终优先。
int? _positiveInt(Object? value) {
  if (value is! num || !value.isFinite || value <= 0) return null;
  final parsed = value.toInt();
  return parsed > 0 ? parsed : null;
}

/// 单个模型的目录上限；字段为空表示 models.dev 未提供该项。
class ModelCatalogEntry {
  const ModelCatalogEntry({this.contextWindow, this.maxOutputTokens});

  final int? contextWindow;
  final int? maxOutputTokens;

  bool get isEmpty => contextWindow == null && maxOutputTokens == null;

  Map<String, dynamic> toJson() => {
    if (contextWindow != null) 'c': contextWindow,
    if (maxOutputTokens != null) 'o': maxOutputTokens,
  };

  factory ModelCatalogEntry.fromJson(Map<String, dynamic> json) =>
      ModelCatalogEntry(
        contextWindow: _positiveInt(json['c']),
        maxOutputTokens: _positiveInt(json['o']),
      );
}

/// 生效上下文窗口的来源。
enum ContextWindowSource { user, catalog, localDefault }

/// 输出预留的来源：协议请求实际参数 / 目录上限 / 本地保守预留。
enum OutputReserveSource { protocol, catalog, localDefault }

/// 按 models.dev providerId 组织的瘦身目录。
class ModelCatalog {
  const ModelCatalog({required this.providers, this.fetchedAt});

  /// models.dev providerId → modelId → 上限。
  final Map<String, Map<String, ModelCatalogEntry>> providers;

  /// 拉取时间；null 表示打包进来的内置快照。
  final DateTime? fetchedAt;

  static const empty = ModelCatalog(providers: {});

  /// 未编目模型的本地默认窗口；偏乐观，用户可通过手填修正。
  static const localDefaultWindow = 128000;

  /// 输出上限未知时的本地保守预留。
  static const localDefaultOutputReserve = 4096;

  /// 同名候选并列时优先已选预设的目录；不限制模型的全局匹配范围。
  static const presetToModelsDev = <String, String>{
    'openai': 'openai',
    'anthropic': 'anthropic',
    'google': 'google',
    'deepseek': 'deepseek',
    'moonshot': 'moonshotai',
    'moonshot-intl': 'moonshotai',
    'zhipu': 'zhipuai',
    'zai': 'zai',
    'qwen': 'alibaba',
    'siliconflow': 'siliconflow',
    'minimax': 'minimax',
    'minimax-cn': 'minimax-cn',
    'openrouter': 'openrouter',
    'groq': 'groq',
    'xai': 'xai',
    'mistral': 'mistral',
    'cerebras': 'cerebras',
    'together': 'togetherai',
    'fireworks': 'fireworks-ai',
    'nvidia': 'nvidia',
    'huggingface': 'huggingface',
    'baseten': 'baseten',
    'vercel-ai-gateway': 'vercel',
  };

  // 全量目录不复用旧白名单目录的 ETag，避免 304 永久保留缺失条目。
  static const _envelopeVersion = 2;

  int get modelCount =>
      providers.values.fold(0, (sum, models) => sum + models.length);

  /// 按模型名跨服务商查找，包括 custom / ollama 配置。
  /// 精确 id 优先于命名空间末段互配；同级优先已选预设，再按模型 id、
  /// 服务商 id 排序，避免目录返回顺序影响预算。不改写请求中的模型 id。
  ModelCatalogEntry? lookup(String presetId, String modelId) {
    final id = modelId.trim();
    final segment = id.split('/').last;
    if (segment.isEmpty) return null;
    final preferredProvider = presetToModelsDev[presetId];
    ModelCatalogEntry? matched;
    var matchedRank = 4;
    String? matchedKey;
    String? matchedProvider;
    for (final MapEntry(key: providerId, value: models) in providers.entries) {
      for (final MapEntry(:key, :value) in models.entries) {
        if (key != id && key.split('/').last != segment) continue;
        final rank =
            (key == id ? 0 : 2) + (providerId == preferredProvider ? 0 : 1);
        final keyOrder = matchedKey == null ? -1 : key.compareTo(matchedKey);
        if (rank < matchedRank ||
            (rank == matchedRank &&
                (keyOrder < 0 ||
                    (keyOrder == 0 &&
                        providerId.compareTo(matchedProvider!) < 0)))) {
          matched = value;
          matchedRank = rank;
          matchedKey = key;
          matchedProvider = providerId;
        }
      }
    }
    return matched;
  }

  /// 完整的 models.dev api.json → 瘦身目录；保留所有服务商的有效模型上限。
  /// 生成脚本与运行期刷新共用，避免两套精简逻辑。
  static ModelCatalog slimFromModelsDevJson(
    Map<String, dynamic> apiJson, {
    DateTime? fetchedAt,
  }) {
    final providers = <String, Map<String, ModelCatalogEntry>>{};
    for (final MapEntry(key: providerId, value: raw) in apiJson.entries) {
      if (raw is! Map) continue;
      final models = raw['models'];
      if (models is! Map) continue;
      final slimmed = <String, ModelCatalogEntry>{};
      for (final MapEntry(:key, :value) in models.entries) {
        if (key is! String || value is! Map) continue;
        final limit = value['limit'];
        final entry = ModelCatalogEntry(
          contextWindow: limit is Map ? _positiveInt(limit['context']) : null,
          maxOutputTokens: limit is Map ? _positiveInt(limit['output']) : null,
        );
        if (!entry.isEmpty) slimmed[key] = entry;
      }
      if (slimmed.isNotEmpty) providers[providerId] = slimmed;
    }
    return ModelCatalog(providers: providers, fetchedAt: fetchedAt);
  }

  Map<String, dynamic> toJson() => {
    'v': _envelopeVersion,
    if (fetchedAt != null) 'fetchedAt': fetchedAt!.toIso8601String(),
    'providers': {
      for (final MapEntry(:key, :value) in providers.entries)
        key: {
          for (final MapEntry(key: modelId, value: entry) in value.entries)
            modelId: entry.toJson(),
        },
    },
  };

  /// 解析内置快照或缓存文件；任何损坏都返回 null，由调用方决定回退。
  static ModelCatalog? tryParse(String jsonText) {
    try {
      final decoded = jsonDecode(jsonText);
      if (decoded is! Map<String, dynamic>) return null;
      if (decoded['v'] != _envelopeVersion) return null;
      final rawProviders = decoded['providers'];
      if (rawProviders is! Map) return null;
      final providers = <String, Map<String, ModelCatalogEntry>>{};
      for (final MapEntry(:key, :value) in rawProviders.entries) {
        if (key is! String || value is! Map) return null;
        final models = <String, ModelCatalogEntry>{};
        for (final MapEntry(key: modelId, value: entry) in value.entries) {
          if (modelId is! String || entry is! Map<String, dynamic>) {
            return null;
          }
          final limits = ModelCatalogEntry.fromJson(entry);
          if (!limits.isEmpty) models[modelId] = limits;
        }
        if (models.isNotEmpty) providers[key] = models;
      }
      if (providers.isEmpty) return null;
      final fetchedAtText = decoded['fetchedAt'];
      final fetchedAt = fetchedAtText is String
          ? DateTime.tryParse(fetchedAtText)
          : null;
      if (fetchedAtText != null && fetchedAt == null) return null;
      return ModelCatalog(providers: providers, fetchedAt: fetchedAt);
    } on Object {
      // 快照/缓存损坏时静默回退，不阻塞启动。
      return null;
    }
  }
}

/// 解析 RunConfiguration 快照里可空的来源名；老快照无来源字段时
/// 按窗口是否手填推断（非空→user，空→localDefault）。
ContextWindowSource windowSourceFromSnapshot(
  String? name, {
  required int? contextWindow,
}) {
  if (name != null) {
    final parsed = ContextWindowSource.values.asNameMap()[name];
    if (parsed != null) return parsed;
  }
  return contextWindow != null
      ? ContextWindowSource.user
      : ContextWindowSource.localDefault;
}

/// 一次解析的结果：窗口永不为 null；目录输出上限仅在用户未设置时出现。
class ResolvedContextLimits {
  const ResolvedContextLimits({
    required this.contextWindow,
    required this.source,
    this.catalogMaxOutputTokens,
  });

  final int contextWindow;
  final ContextWindowSource source;

  /// 只用于本地输出预留，绝不下发为请求参数。
  final int? catalogMaxOutputTokens;
}

/// 解析优先级：用户手填 > models.dev 目录 > 本地默认 128000。
ResolvedContextLimits resolveContextLimits({
  required String presetId,
  required String modelId,
  required int? userContextWindow,
  required int? userMaxOutputTokens,
  required ModelCatalog catalog,
}) {
  if (userContextWindow != null) {
    return ResolvedContextLimits(
      contextWindow: userContextWindow,
      source: ContextWindowSource.user,
      catalogMaxOutputTokens: userMaxOutputTokens == null
          ? catalog.lookup(presetId, modelId)?.maxOutputTokens
          : null,
    );
  }
  final entry = catalog.lookup(presetId, modelId);
  if (entry?.contextWindow != null) {
    return ResolvedContextLimits(
      contextWindow: entry!.contextWindow!,
      source: ContextWindowSource.catalog,
      catalogMaxOutputTokens: userMaxOutputTokens == null
          ? entry.maxOutputTokens
          : null,
    );
  }
  return ResolvedContextLimits(
    contextWindow: ModelCatalog.localDefaultWindow,
    source: ContextWindowSource.localDefault,
    catalogMaxOutputTokens: userMaxOutputTokens == null
        ? entry?.maxOutputTokens
        : null,
  );
}
