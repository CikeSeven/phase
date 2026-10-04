import 'package:html/parser.dart' as html;

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

class BingSearchProvider implements WebSearchProvider {
  const BingSearchProvider(this.client);
  final WebHttpClient client;

  @override
  Future<WebSearchPage> search({
    required String query,
    required int maxResults,
    required WebSearchProfile profile,
    required String? apiKey,
    required WebRequestScope scope,
  }) async {
    final uri = searchEndpoint(profile, 'search', {
      'q': query,
      if (profile.language.isNotEmpty) 'setlang': profile.language,
    });
    final content = await client.text(
      uri,
      scope,
      headers: const {
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
        'Cookie': 'SRCHHPGUSR=ULSR=1',
      },
    );
    scope.check();
    final document = html.parse(content);
    final elements = document.querySelectorAll('li.b_algo');
    if (elements.isEmpty &&
        document.querySelector('.b_no, #b_results') == null) {
      throw const WebFailure('searchBlocked', 'Bing 搜索页面结构无法识别或被限制，请稍后重试');
    }
    final sources = <WebSearchSource>[];
    for (final element in elements) {
      final link = element.querySelector('h2 a');
      final rawUrl = link?.attributes['href'];
      if (rawUrl == null || rawUrl.trim().isEmpty) continue;
      final title = link?.text.trim();
      final snippet = element.querySelector('.b_caption p')?.text.trim();
      sources.add(WebSearchSource(url: rawUrl, title: title, snippet: snippet));
      if (sources.length >= maxResults) break;
    }
    return WebSearchPage(sources: sources);
  }
}

class BochaSearchProvider implements WebSearchProvider {
  const BochaSearchProvider(this.client);
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
      searchEndpoint(profile, 'web-search'),
      scope,
      headers: {'Authorization': 'Bearer $apiKey'},
      body: {
        'query': query,
        'freshness': 'noLimit',
        'summary': true,
        'count': maxResults,
      },
    );
    final data = json['data'];
    if (data is! Map<String, dynamic>) {
      throw const WebFailure('invalidResponse', '博查返回的搜索结构无效');
    }
    final webPages = data['webPages'];
    if (webPages is! Map<String, dynamic>) {
      return const WebSearchPage(sources: []);
    }
    final values = resultObjects(webPages['value']);
    final sources = <WebSearchSource>[];
    for (final item in values) {
      final url = resultString(item['url']);
      if (url == null) continue;
      sources.add(
        WebSearchSource(
          url: url,
          title: resultString(item['name']),
          snippet: resultString(item['snippet']),
          publishedAt: resultString(item['dateLastCrawled']),
        ),
      );
    }
    return WebSearchPage(sources: sources);
  }
}

class SerperSearchProvider implements WebSearchProvider {
  const SerperSearchProvider(this.client);
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
      headers: {'X-API-KEY': apiKey!},
      body: {
        'q': query,
        'num': maxResults,
        if (profile.language.isNotEmpty) 'gl': profile.language,
      },
    );
    final organic = json['organic'];
    if (organic == null) {
      return const WebSearchPage(sources: []);
    }
    final sources = <WebSearchSource>[];
    for (final item in resultObjects(organic)) {
      final url = resultString(item['link']);
      if (url == null) continue;
      sources.add(
        WebSearchSource(
          url: url,
          title: resultString(item['title']),
          snippet: resultString(item['snippet']),
          publishedAt: resultString(item['date']),
        ),
      );
    }
    return WebSearchPage(sources: sources);
  }
}

class JinaSearchProvider implements WebSearchProvider {
  const JinaSearchProvider(this.client);
  final WebHttpClient client;

  @override
  Future<WebSearchPage> search({
    required String query,
    required int maxResults,
    required WebSearchProfile profile,
    required String? apiKey,
    required WebRequestScope scope,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      if (apiKey != null && apiKey.isNotEmpty)
        'Authorization': 'Bearer $apiKey',
    };
    final uri = searchEndpoint(profile, Uri.encodeComponent(query));
    final json = await client.json(uri, scope, method: 'GET', headers: headers);
    final data = json['data'];
    if (data == null) {
      return const WebSearchPage(sources: []);
    }
    final sources = <WebSearchSource>[];
    for (final item in resultObjects(data)) {
      final url = resultString(item['url']);
      if (url == null) continue;
      sources.add(
        WebSearchSource(
          url: url,
          title: resultString(item['title']),
          snippet:
              resultString(item['description']) ??
              resultString(item['content']),
        ),
      );
      if (sources.length >= maxResults) break;
    }
    return WebSearchPage(sources: sources);
  }
}
