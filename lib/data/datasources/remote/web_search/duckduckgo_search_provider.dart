import 'package:html/parser.dart' as html;

import '../../../../core/error/failure.dart';
import '../../../models/web_search_result.dart';
import '../../../models/web_search_settings.dart';
import '../web_request_scope.dart';
import 'web_http_client.dart';
import 'web_search_provider.dart';

class DuckduckgoSearchProvider implements WebSearchProvider {
  const DuckduckgoSearchProvider(this.client);
  final WebHttpClient client;

  @override
  Future<WebSearchPage> search({
    required String query,
    required int maxResults,
    required WebSearchProfile profile,
    required String? apiKey,
    required WebRequestScope scope,
  }) async {
    final uri = searchEndpoint(profile, 'html/', {
      'q': query,
      if (profile.region.isNotEmpty) 'kl': profile.region,
    });
    final content = await client.text(
      uri,
      scope,
      headers: const {
        'Accept': 'text/html',
        'User-Agent': 'Mozilla/5.0 (compatible; Phase/1.0)',
      },
    );
    scope.check();
    final document = html.parse(content);
    if (document.querySelector(
              '#anomaly-modal, .anomaly-modal, form[action*="anomaly"]',
            ) !=
            null ||
        document.querySelector('input[name="captcha"]') != null) {
      throw const WebFailure(
        'searchBlocked',
        'DuckDuckGo 要求人机验证，请稍后重试或选择 API 搜索服务',
      );
    }
    final elements = document.querySelectorAll('.result');
    if (elements.isEmpty &&
        document.querySelector('.no-results, .no-results__message') == null) {
      throw const WebFailure(
        'invalidResponse',
        'DuckDuckGo 未返回可识别的搜索页，请选择其他搜索服务',
      );
    }
    final sources = <WebSearchSource>[];
    for (final element in elements) {
      final link = element.querySelector('.result__a');
      final raw = link?.attributes['href'];
      if (raw == null || raw.trim().isEmpty) continue;
      final parsed = uri.resolve(raw);
      final url = parsed.queryParameters['uddg'] ?? parsed.toString();
      sources.add(
        WebSearchSource(
          url: url,
          title: link?.text.trim(),
          snippet: element.querySelector('.result__snippet')?.text.trim(),
        ),
      );
    }
    return WebSearchPage(sources: sources);
  }
}
