import 'dart:convert';

import '../../../data/models/tool_policy.dart';
import 'tool.dart';

/// 发起一次 HTTP 请求并返回响应文本（截断到上限）。
///
/// 只做"取任务需要的数据"这一件事：不改方法、不跟随重定向之外的自动重试，
/// 也不替模型解释网页内容；返回的正文按不可信数据处理。
class HttpRequestTool implements Tool {
  HttpRequestTool({
    required this.fetch,
    this.maxBytes = 512 * 1024,
    this.timeout = const Duration(seconds: 30),
  });

  /// 实际发起请求的实现（生产用 Dio，测试注入可控实现）。
  final Future<HttpFetchResult> Function(HttpFetchRequest request) fetch;

  /// 响应正文保留上限（字节）。
  final int maxBytes;

  final Duration timeout;

  @override
  String get name => 'http_request';

  @override
  String get description =>
      '发起 HTTP 请求获取数据。支持 GET/POST/PUT/DELETE；'
      '不要在 url、headers 或 body 里放密钥或用户隐私（会被记录）。'
      '响应正文超过 ${_maxBytesLabel}KB 会被截断。';

  String get _maxBytesLabel => '${maxBytes ~/ 1024}';

  @override
  Map<String, dynamic> get inputSchema => {
    'type': 'object',
    'properties': {
      'url': {'type': 'string', 'description': '完整 URL，含协议'},
      'method': {
        'type': 'string',
        'enum': ['GET', 'POST', 'PUT', 'DELETE'],
        'description': '默认 GET',
      },
      'headers': {'type': 'object', 'description': '附加请求头，键值都为字符串'},
      'body': {'type': 'string', 'description': '请求正文（POST/PUT 使用）'},
    },
    'required': ['url'],
    'additionalProperties': false,
  };

  @override
  Set<String> get requiredCapabilities => const {'network'};

  @override
  ToolPolicy get defaultPolicy => ToolPolicy.ask;

  @override
  String describeAction(Map<String, dynamic> arguments) {
    final url = arguments['url'];
    final method = arguments['method'];
    final display = url is String ? url : '（缺少 URL）';
    return '${method is String ? method.toUpperCase() : 'GET'} $display';
  }

  @override
  Future<ToolOutcome> execute(
    Map<String, dynamic> arguments,
    ToolContext context,
    RunCancellation cancellation, {
    ToolProgress? onProgress,
  }) async {
    final args = ToolArguments(arguments, name);
    final rawUrl = args.string('url').trim();
    final method = (args.optionalString('method') ?? 'GET').toUpperCase();
    if (!const {'GET', 'POST', 'PUT', 'DELETE'}.contains(method)) {
      return ToolOutcome.failure(
        '不支持的请求方法「$method」',
        errorCode: 'invalidMethod',
      );
    }
    final uri = Uri.tryParse(rawUrl);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return ToolOutcome.failure(
        'URL 不合法：「$rawUrl」需要包含协议与主机',
        errorCode: 'invalidUrl',
      );
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return ToolOutcome.failure(
        '只支持 http/https，收到「${uri.scheme}」',
        errorCode: 'invalidUrl',
      );
    }

    final headers = <String, String>{};
    final rawHeaders = arguments['headers'];
    if (rawHeaders is Map) {
      for (final entry in rawHeaders.entries) {
        final key = entry.key;
        final value = entry.value;
        if (key is String && value is String) headers[key] = value;
      }
    }

    cancellation.throwIfCancelled();
    onProgress?.call('正在请求 $method ${uri.host}');

    try {
      final result = await fetch(
        HttpFetchRequest(
          uri: uri,
          method: method,
          headers: headers,
          body: args.optionalString('body'),
          timeout: timeout,
          maxBytes: maxBytes,
        ),
      );
      cancellation.throwIfCancelled();
      final body = _decodeBody(result);
      final headerLine =
          'HTTP ${result.statusCode}'
          '${result.statusCode >= 400 ? '（请求失败）' : ''}'
          '${result.truncated ? '，正文已截断到 ${maxBytes ~/ 1024}KB' : ''}';
      if (result.statusCode >= 400) {
        return ToolOutcome.failure(
          '$headerLine\n$body',
          errorCode: 'http${result.statusCode}',
        );
      }
      return ToolOutcome.success('$headerLine\n$body');
    } on HttpFetchException catch (error) {
      return ToolOutcome.failure(error.message, errorCode: error.code);
    }
  }

  /// 响应按 UTF-8 解码；无法解码时按 latin-1 兜底，避免整段丢弃。
  String _decodeBody(HttpFetchResult result) {
    try {
      return utf8.decode(result.body);
    } on FormatException {
      return latin1.decode(result.body, allowInvalid: true);
    }
  }
}

/// 一次 HTTP 请求的描述（工具与网络实现之间的契约）。
class HttpFetchRequest {
  const HttpFetchRequest({
    required this.uri,
    required this.method,
    required this.headers,
    required this.timeout,
    required this.maxBytes,
    this.body,
  });

  final Uri uri;
  final String method;
  final Map<String, String> headers;
  final String? body;
  final Duration timeout;
  final int maxBytes;
}

class HttpFetchResult {
  const HttpFetchResult({
    required this.statusCode,
    required this.body,
    this.truncated = false,
  });

  final int statusCode;
  final List<int> body;
  final bool truncated;
}

class HttpFetchException implements Exception {
  const HttpFetchException(this.code, this.message);

  final String code;
  final String message;
}
