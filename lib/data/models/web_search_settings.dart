import '../../core/error/failure.dart';

enum WebSearchProviderKind {
  duckDuckGo,
  bing,
  deepseek,
  exa,
  brave,
  tavily,
  perplexity,
  searxng,
  bocha,
  serper,
  jina;

  String get label => switch (this) {
    duckDuckGo => 'DuckDuckGo',
    bing => 'Bing',
    deepseek => 'DeepSeek',
    exa => 'Exa',
    brave => 'Brave Search',
    tavily => 'Tavily',
    perplexity => 'Perplexity',
    searxng => 'SearXNG',
    bocha => '博查 (Bocha)',
    serper => 'Serper (Google)',
    jina => 'Jina Search',
  };

  String get defaultBaseUrl => switch (this) {
    duckDuckGo => 'https://html.duckduckgo.com',
    bing => 'https://www.bing.com',
    deepseek => 'https://api.deepseek.com/anthropic/v1',
    exa => 'https://api.exa.ai',
    brave => 'https://api.search.brave.com/res/v1',
    tavily => 'https://api.tavily.com',
    perplexity => 'https://api.perplexity.ai',
    searxng => '',
    bocha => 'https://api.bochaai.com/v1',
    serper => 'https://google.serper.dev',
    jina => 'https://s.jina.ai',
  };

  bool get requiresKey =>
      this != duckDuckGo && this != bing && this != searxng && this != jina;
  bool get usesModel => this == deepseek || this == perplexity;
  String get defaultModel => switch (this) {
    deepseek => 'deepseek-v4-flash',
    perplexity => 'sonar',
    _ => '',
  };
}

/// 仅保存连接信息与安全存储引用；历史运行绑定旧引用，编辑密钥不覆盖它。
class WebSearchProfile {
  const WebSearchProfile({
    required this.id,
    required this.name,
    required this.kind,
    required this.baseUrl,
    this.enabled = true,
    this.deleting = false,
    this.model = '',
    this.searchDepth = 'basic',
    this.searchType = 'auto',
    this.region = '',
    this.language = '',
    this.engines = '',
    this.maxTokens = 4096,
    this.maxUses = 5,
    this.credentialRef,
    this.credentialRefs = const [],
    this.revision = '',
  });

  final String id;
  final String name;
  final WebSearchProviderKind kind;
  final String baseUrl;
  final bool enabled;
  final bool deleting;
  final String model;
  final String searchDepth;
  final String searchType;
  final String region;
  final String language;
  final String engines;
  final int maxTokens;
  final int maxUses;
  final String? credentialRef;
  final List<String> credentialRefs;
  final String revision;

  String get resolvedModel => model.isEmpty ? kind.defaultModel : model;

  void validate() {
    if (id.isEmpty || name.trim().isEmpty || name.length > 100) {
      throw const OperationFailure('请填写有效的搜索服务名称');
    }
    final uri = Uri.tryParse(baseUrl);
    if (uri == null ||
        !const {'http', 'https'}.contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        baseUrl.length > 2048) {
      throw const OperationFailure('接口地址须为不含凭据、参数或片段的 HTTP(S) 地址');
    }
    // 搜索密钥不经明文公网连接发送；本机代理可使用 HTTP。
    if ((kind.requiresKey || credentialRef != null) &&
        uri.scheme != 'https' &&
        !const {'localhost', '127.0.0.1', '::1'}.contains(uri.host)) {
      throw const OperationFailure('需要密钥的搜索接口须使用 HTTPS');
    }
    if (kind.usesModel &&
        (resolvedModel.trim().isEmpty || resolvedModel.length > 200)) {
      throw const OperationFailure('请填写有效的搜索模型');
    }
    if (!const {'basic', 'advanced'}.contains(searchDepth) ||
        !const {'auto', 'keyword', 'neural'}.contains(searchType) ||
        maxTokens < 256 ||
        maxTokens > 32768 ||
        maxUses < 1 ||
        maxUses > 20) {
      throw const OperationFailure('搜索服务参数超出有效范围');
    }
    for (final value in [model, region, language, engines]) {
      if (value.length > 500 || value.contains(RegExp(r'[\x00-\x1f]'))) {
        throw const OperationFailure('搜索服务参数不能包含控制字符');
      }
    }
    if (kind == WebSearchProviderKind.brave &&
        region.isNotEmpty &&
        !RegExp(r'^[a-zA-Z]{2}$').hasMatch(region)) {
      throw const OperationFailure('Brave 国家代码须为两个英文字母');
    }
  }

  WebSearchProfile copyWith({
    String? name,
    String? baseUrl,
    bool? enabled,
    bool? deleting,
    String? model,
    String? searchDepth,
    String? searchType,
    String? region,
    String? language,
    String? engines,
    int? maxTokens,
    int? maxUses,
    String? credentialRef,
    bool clearCredential = false,
    List<String>? credentialRefs,
    String? revision,
  }) => WebSearchProfile(
    id: id,
    name: name ?? this.name,
    kind: kind,
    baseUrl: baseUrl ?? this.baseUrl,
    enabled: enabled ?? this.enabled,
    deleting: deleting ?? this.deleting,
    model: model ?? this.model,
    searchDepth: searchDepth ?? this.searchDepth,
    searchType: searchType ?? this.searchType,
    region: region ?? this.region,
    language: language ?? this.language,
    engines: engines ?? this.engines,
    maxTokens: maxTokens ?? this.maxTokens,
    maxUses: maxUses ?? this.maxUses,
    credentialRef: clearCredential ? null : credentialRef ?? this.credentialRef,
    credentialRefs: List.unmodifiable(credentialRefs ?? this.credentialRefs),
    revision: revision ?? this.revision,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'kind': kind.name,
    'baseUrl': baseUrl,
    'enabled': enabled,
    'deleting': deleting,
    'model': model,
    'searchDepth': searchDepth,
    'searchType': searchType,
    'region': region,
    'language': language,
    'engines': engines,
    'maxTokens': maxTokens,
    'maxUses': maxUses,
    'credentialRef': credentialRef,
    'credentialRefs': credentialRefs,
    'revision': revision,
  };

  factory WebSearchProfile.fromJson(Map<String, dynamic> json) =>
      WebSearchProfile(
        id: json['id'] as String,
        name: json['name'] as String,
        kind: WebSearchProviderKind.values.byName(json['kind'] as String),
        baseUrl: json['baseUrl'] as String,
        enabled: json['enabled'] as bool? ?? true,
        deleting: json['deleting'] as bool? ?? false,
        model: json['model'] as String? ?? '',
        searchDepth: json['searchDepth'] as String? ?? 'basic',
        searchType: json['searchType'] as String? ?? 'auto',
        region: json['region'] as String? ?? '',
        language: json['language'] as String? ?? '',
        engines: json['engines'] as String? ?? '',
        maxTokens: json['maxTokens'] as int? ?? 4096,
        maxUses: json['maxUses'] as int? ?? 5,
        credentialRef: json['credentialRef'] as String?,
        credentialRefs: List.unmodifiable(
          (json['credentialRefs'] as List? ?? const []).cast<String>(),
        ),
        revision: json['revision'] as String? ?? '',
      );
}

class WebSearchSettings {
  const WebSearchSettings({
    this.searchEnabled = true,
    this.fetchEnabled = true,
    this.selectedProfileId = 'duckduckgo',
    this.profiles = const [
      WebSearchProfile(
        id: 'duckduckgo',
        name: 'DuckDuckGo',
        kind: WebSearchProviderKind.duckDuckGo,
        baseUrl: 'https://html.duckduckgo.com',
      ),
    ],
    this.maxQueries = 4,
    this.maxResults = 8,
    this.searchTimeoutSeconds = 60,
    this.fetchTimeoutSeconds = 30,
    this.maxPageCharacters = 40000,
  });

  final bool searchEnabled;
  final bool fetchEnabled;
  final String? selectedProfileId;
  final List<WebSearchProfile> profiles;
  final int maxQueries;
  final int maxResults;
  final int searchTimeoutSeconds;
  final int fetchTimeoutSeconds;
  final int maxPageCharacters;

  WebSearchProfile? get selected =>
      profiles.where((profile) => profile.id == selectedProfileId).firstOrNull;

  void validate() {
    if (maxQueries < 1 ||
        maxQueries > 8 ||
        maxResults < 1 ||
        maxResults > 20 ||
        searchTimeoutSeconds < 5 ||
        searchTimeoutSeconds > 180 ||
        fetchTimeoutSeconds < 5 ||
        fetchTimeoutSeconds > 180 ||
        maxPageCharacters < 1024 ||
        maxPageCharacters > 100000) {
      throw const OperationFailure('搜索或网页读取上限超出有效范围');
    }
    final ids = <String>{};
    for (final profile in profiles) {
      profile.validate();
      if (!ids.add(profile.id)) {
        throw const OperationFailure('搜索服务标识重复');
      }
    }
    if (selectedProfileId != null && selected == null) {
      throw const OperationFailure('选中的搜索服务已不存在');
    }
  }

  WebSearchSettings copyWith({
    bool? searchEnabled,
    bool? fetchEnabled,
    String? selectedProfileId,
    bool clearSelection = false,
    List<WebSearchProfile>? profiles,
    int? maxQueries,
    int? maxResults,
    int? searchTimeoutSeconds,
    int? fetchTimeoutSeconds,
    int? maxPageCharacters,
  }) => WebSearchSettings(
    searchEnabled: searchEnabled ?? this.searchEnabled,
    fetchEnabled: fetchEnabled ?? this.fetchEnabled,
    selectedProfileId: clearSelection
        ? null
        : selectedProfileId ?? this.selectedProfileId,
    profiles: List.unmodifiable(profiles ?? this.profiles),
    maxQueries: maxQueries ?? this.maxQueries,
    maxResults: maxResults ?? this.maxResults,
    searchTimeoutSeconds: searchTimeoutSeconds ?? this.searchTimeoutSeconds,
    fetchTimeoutSeconds: fetchTimeoutSeconds ?? this.fetchTimeoutSeconds,
    maxPageCharacters: maxPageCharacters ?? this.maxPageCharacters,
  );

  Map<String, dynamic> toJson() => {
    'searchEnabled': true,
    'fetchEnabled': true,
    'selectedProfileId': selectedProfileId,
    'profiles': [for (final profile in profiles) profile.toJson()],
    'maxQueries': maxQueries,
    'maxResults': maxResults,
    'searchTimeoutSeconds': searchTimeoutSeconds,
    'fetchTimeoutSeconds': fetchTimeoutSeconds,
    'maxPageCharacters': maxPageCharacters,
  };

  factory WebSearchSettings.fromJson(Map<String, dynamic> json) {
    final value = WebSearchSettings(
      searchEnabled: true,
      fetchEnabled: true,
      selectedProfileId: json['selectedProfileId'] as String?,
      profiles: List.unmodifiable([
        for (final value in json['profiles'] as List)
          WebSearchProfile.fromJson(value as Map<String, dynamic>),
      ]),
      maxQueries: json['maxQueries'] as int? ?? 4,
      maxResults: json['maxResults'] as int? ?? 8,
      searchTimeoutSeconds: json['searchTimeoutSeconds'] as int? ?? 60,
      fetchTimeoutSeconds: json['fetchTimeoutSeconds'] as int? ?? 30,
      maxPageCharacters: json['maxPageCharacters'] as int? ?? 40000,
    );
    value.validate();
    return value;
  }
}
