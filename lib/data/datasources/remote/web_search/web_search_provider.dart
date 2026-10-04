import '../../../../core/error/failure.dart';
import '../../../models/web_search_result.dart';
import '../../../models/web_search_settings.dart';
import '../web_request_scope.dart';

abstract interface class WebSearchProvider {
  Future<WebSearchPage> search({
    required String query,
    required int maxResults,
    required WebSearchProfile profile,
    required String? apiKey,
    required WebRequestScope scope,
  });
}

Uri searchEndpoint(
  WebSearchProfile profile,
  String path, [
  Map<String, String>? query,
]) {
  final base = Uri.parse(profile.baseUrl);
  final basePath = base.path.replaceFirst(RegExp(r'/+$'), '');
  return base.replace(path: '$basePath/$path', queryParameters: query);
}

/// JSON 属于网络边界，字段类型不符时不伪装为空结果。
List<Map<String, dynamic>> resultObjects(Object? value) {
  if (value is! List || value.any((item) => item is! Map<String, dynamic>)) {
    throw const WebFailure('invalidResponse', '搜索结果结构无效');
  }
  return value.cast<Map<String, dynamic>>();
}

String? resultString(Object? value) {
  if (value == null) return null;
  if (value is! String) throw const WebFailure('invalidResponse', '搜索结果字段无效');
  return value.trim().isEmpty ? null : value;
}

WebSearchSource resultSource(
  Map<String, dynamic> item, {
  String snippetKey = 'snippet',
  String dateKey = 'publishedDate',
}) {
  final url = resultString(item['url']);
  if (url == null) throw const WebFailure('invalidResponse', '搜索来源缺少 URL');
  return WebSearchSource(
    url: url,
    title: resultString(item['title']),
    snippet: resultString(item[snippetKey]),
    publishedAt: resultString(item[dateKey]),
  );
}
