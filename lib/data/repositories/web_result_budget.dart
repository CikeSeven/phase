import 'dart:convert';

import '../datasources/remote/web_page_text.dart';
import '../models/web_search_result.dart';

// 预留通用工具封装空间；完整 JSON 而非被切断的字符串进入工具记录和模型上下文。
const webResultMaxBytes = 48 * 1024;

WebSearchResult boundWebSearchResult(WebSearchResult result) {
  final sources = [...result.sources];
  final answers = [...result.answers];
  var truncated = result.truncated;
  WebSearchResult current() => WebSearchResult(
    queries: result.queries,
    sources: List.unmodifiable(sources),
    answers: List.unmodifiable(answers),
    retrievedAt: result.retrievedAt,
    truncated: truncated,
  );
  while (utf8.encode(jsonEncode(current().toJson())).length >
      webResultMaxBytes) {
    truncated = true;
    if (answers.isNotEmpty) {
      final index = answers.indexWhere((answer) => answer.text.length > 256);
      if (index >= 0) {
        final answer = answers[index];
        answers[index] = WebSearchAnswer(
          query: answer.query,
          text: clipWebText(answer.text, answer.text.length ~/ 2),
        );
      } else {
        answers.removeLast();
      }
      continue;
    }
    final index = sources.indexWhere(
      (source) => (source.snippet?.length ?? 0) > 128,
    );
    if (index >= 0) {
      final source = sources[index];
      sources[index] = WebSearchSource(
        url: source.url,
        title: source.title,
        publishedAt: source.publishedAt,
        snippet: clipWebText(source.snippet!, source.snippet!.length ~/ 2),
      );
    } else if (sources.isNotEmpty) {
      sources.removeLast();
    } else {
      break;
    }
  }
  return current();
}

WebFetchResult boundWebFetchResult(WebFetchResult result) {
  WebFetchResult withContent(String content, bool truncated) => WebFetchResult(
    url: result.url,
    statusCode: result.statusCode,
    content: content,
    title: result.title == null ? null : clipWebText(result.title!, 400),
    retrievedAt: result.retrievedAt,
    truncated: truncated,
  );
  var value = withContent(result.content, result.truncated);
  if (utf8.encode(jsonEncode(value.toJson())).length <= webResultMaxBytes) {
    return value;
  }
  var low = 0, high = result.content.length;
  while (low < high) {
    final midpoint = (low + high + 1) ~/ 2;
    value = withContent(clipWebText(result.content, midpoint), true);
    if (utf8.encode(jsonEncode(value.toJson())).length <= webResultMaxBytes) {
      low = midpoint;
    } else {
      high = midpoint - 1;
    }
  }
  return withContent(clipWebText(result.content, low), true);
}
