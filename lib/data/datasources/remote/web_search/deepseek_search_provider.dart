import '../../../../core/error/failure.dart';
import '../../../models/web_search_result.dart';
import '../../../models/web_search_settings.dart';
import '../web_request_scope.dart';
import 'web_http_client.dart';
import 'web_search_provider.dart';

/// 独立的辅助 Messages 请求；不改变主对话协议，也不从自然语言答案猜来源。
class DeepseekSearchProvider implements WebSearchProvider {
  const DeepseekSearchProvider(this.client);
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
      searchEndpoint(profile, 'messages'),
      scope,
      headers: {'x-api-key': apiKey!, 'anthropic-version': '2023-06-01'},
      body: {
        'model': profile.resolvedModel,
        'max_tokens': profile.maxTokens,
        'messages': [
          {
            'role': 'user',
            'content': [
              {
                'type': 'text',
                'text': 'Perform a web search for the query: $query',
              },
            ],
          },
        ],
        'tools': [
          {
            'type': 'web_search_20250305',
            'name': 'web_search',
            'max_uses': profile.maxUses,
          },
        ],
      },
    );
    final blocks = resultObjects(json['content']);
    final snippets = <String, String>{};
    for (final block in blocks.where((block) => block['type'] == 'text')) {
      if (block['citations'] == null) continue;
      for (final citation in resultObjects(block['citations'])) {
        final url = resultString(citation['url']);
        final text = resultString(citation['cited_text']);
        if (url != null && text != null) snippets.putIfAbsent(url, () => text);
      }
    }
    final resultBlocks = blocks
        .where((block) => block['type'] == 'web_search_tool_result')
        .toList();
    if (resultBlocks.isEmpty) {
      throw const WebFailure(
        'searchNotTriggered',
        '搜索模型未返回原生搜索结果，请检查模型与接口是否支持搜索',
      );
    }
    final sources = <WebSearchSource>[];
    final seen = <String>{};
    for (final block in resultBlocks) {
      if (block['content'] is Map) {
        throw const WebFailure('providerError', '原生搜索执行失败，请检查搜索额度与服务状态');
      }
      for (final item in resultObjects(block['content'])) {
        if (item['type'] != 'web_search_result') continue;
        final source = resultSource(item, dateKey: 'page_age');
        if (!seen.add(source.url)) continue;
        sources.add(
          WebSearchSource(
            url: source.url,
            title: source.title,
            snippet: snippets[source.url],
            publishedAt: source.publishedAt,
          ),
        );
      }
    }
    return WebSearchPage(sources: sources);
  }
}
