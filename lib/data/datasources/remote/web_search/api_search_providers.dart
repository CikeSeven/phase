import '../../../../core/error/failure.dart';
import '../../../models/web_search_result.dart';
import '../../../models/web_search_settings.dart';
import '../web_request_scope.dart';
import 'web_http_client.dart';
import 'web_search_provider.dart';

class ExaSearchProvider implements WebSearchProvider {
  const ExaSearchProvider(this.client);
  final WebHttpClient client;

  @override
  Future<WebSearchPage> search({
    required String query,
    required int maxResults,
    required WebSearchProfile profile,
    required String? apiKey,
    required WebRequestScope scope,
  }) async {
    final json = await client.json(
      searchEndpoint(profile, 'search'),
      scope,
      headers: {'Authorization': 'Bearer $apiKey'},
      body: {
        'query': query,
        'type': profile.searchType,
        'numResults': maxResults,
        'contents': {
          'highlights': {'highlightsPerUrl': 2},
        },
      },
    );
    final sources = <WebSearchSource>[];
    for (final item in resultObjects(json['results'])) {
      final highlights = item['highlights'];
      if (highlights != null &&
          (highlights is! List ||
              highlights.any((value) => value is! String))) {
        throw const WebFailure('invalidResponse', 'Exa 返回的摘录结构无效');
      }
      final source = resultSource(item);
      sources.add(
        WebSearchSource(
          url: source.url,
          title: source.title,
          publishedAt: source.publishedAt,
          snippet: highlights
              ?.cast<String>()
              .where((value) => value.trim().isNotEmpty)
              .join('\n'),
        ),
      );
    }
    return WebSearchPage(sources: sources);
  }
}

class BraveSearchProvider implements WebSearchProvider {
  const BraveSearchProvider(this.client);
  final WebHttpClient client;

  @override
  Future<WebSearchPage> search({
    required String query,
    required int maxResults,
    required WebSearchProfile profile,
    required String? apiKey,
    required WebRequestScope scope,
  }) async {
    final json = await client.json(
      searchEndpoint(profile, 'web/search', {
        'q': query,
        'count': '$maxResults',
        if (profile.region.isNotEmpty) 'country': profile.region.toLowerCase(),
        if (profile.language.isNotEmpty) 'search_lang': profile.language,
      }),
      scope,
      method: 'GET',
      headers: {'X-Subscription-Token': apiKey!},
    );
    final web = json['web'];
    if (web == null && json['query'] is Map) {
      return const WebSearchPage(sources: []);
    }
    if (web is! Map<String, dynamic>) {
      throw const WebFailure('invalidResponse', 'Brave 返回的搜索结构无效');
    }
    return WebSearchPage(
      sources: [
        for (final item in resultObjects(web['results']))
          resultSource(item, snippetKey: 'description', dateKey: 'page_age'),
      ],
    );
  }
}

class TavilySearchProvider implements WebSearchProvider {
  const TavilySearchProvider(this.client);
  final WebHttpClient client;

  @override
  Future<WebSearchPage> search({
    required String query,
    required int maxResults,
    required WebSearchProfile profile,
    required String? apiKey,
    required WebRequestScope scope,
  }) async {
    final json = await client.json(
      searchEndpoint(profile, 'search'),
      scope,
      headers: {'Authorization': 'Bearer $apiKey'},
      body: {
        'query': query,
        'max_results': maxResults,
        'search_depth': profile.searchDepth,
        'include_answer': true,
        'include_raw_content': false,
      },
    );
    return WebSearchPage(
      answer: resultString(json['answer']),
      sources: [
        for (final item in resultObjects(json['results']))
          resultSource(item, snippetKey: 'content', dateKey: 'published_date'),
      ],
    );
  }
}

class PerplexitySearchProvider implements WebSearchProvider {
  const PerplexitySearchProvider(this.client);
  final WebHttpClient client;

  @override
  Future<WebSearchPage> search({
    required String query,
    required int maxResults,
    required WebSearchProfile profile,
    required String? apiKey,
    required WebRequestScope scope,
  }) async {
    final json = await client.json(
      searchEndpoint(profile, 'chat/completions'),
      scope,
      headers: {'Authorization': 'Bearer $apiKey'},
      body: {
        'model': profile.resolvedModel,
        'max_tokens': profile.maxTokens,
        'messages': [
          {'role': 'user', 'content': query},
        ],
      },
    );
    final choices = resultObjects(json['choices']);
    if (choices.isEmpty || choices.first['message'] is! Map<String, dynamic>) {
      throw const WebFailure('invalidResponse', 'Perplexity 未返回有效回答');
    }
    final String? answer = resultString(choices.first['message']['content']);
    final sources = <WebSearchSource>[];
    if (json['search_results'] != null) {
      for (final item in resultObjects(json['search_results'])) {
        sources.add(resultSource(item, dateKey: 'date'));
      }
    } else {
      final citations = json['citations'];
      if (citations is! List || citations.any((value) => value is! String)) {
        throw const WebFailure('invalidResponse', 'Perplexity 未返回有效来源');
      }
      sources.addAll(
        citations.cast<String>().map((url) => WebSearchSource(url: url)),
      );
    }
    return WebSearchPage(answer: answer, sources: sources);
  }
}

class SearxngSearchProvider implements WebSearchProvider {
  const SearxngSearchProvider(this.client);
  final WebHttpClient client;

  @override
  Future<WebSearchPage> search({
    required String query,
    required int maxResults,
    required WebSearchProfile profile,
    required String? apiKey,
    required WebRequestScope scope,
  }) async {
    final json = await client.json(
      searchEndpoint(profile, 'search', {
        'q': query,
        'format': 'json',
        if (profile.engines.isNotEmpty) 'engines': profile.engines,
        if (profile.language.isNotEmpty) 'language': profile.language,
      }),
      scope,
      method: 'GET',
      headers: {
        if (apiKey != null && apiKey.isNotEmpty)
          'Authorization': 'Bearer $apiKey',
      },
    );
    final sources = [
      for (final item in resultObjects(json['results']))
        resultSource(item, snippetKey: 'content'),
    ];
    // 引擎全部失败不能冒充一次成功的零结果搜索。
    if (sources.isEmpty &&
        (json['unresponsive_engines'] as List? ?? const []).isNotEmpty) {
      throw const WebFailure('providerError', 'SearXNG 搜索引擎不可用，请检查实例配置');
    }
    return WebSearchPage(sources: sources);
  }
}
