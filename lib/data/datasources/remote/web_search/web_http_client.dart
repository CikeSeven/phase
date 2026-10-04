import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../../core/error/failure.dart';
import '../web_request_scope.dart';

/// 专用搜索传输：不装请求日志，不跟随重定向，不向错误结果泄漏正文。
class WebHttpClient {
  const WebHttpClient(this.dio);
  final Dio dio;
  static const maxResponseBytes = 2 * 1024 * 1024;

  Future<String> text(
    Uri uri,
    WebRequestScope scope, {
    String method = 'GET',
    Map<String, String> headers = const {},
    Object? body,
  }) async {
    scope.check();
    try {
      final response = await scope.guard(
        dio.requestUri<ResponseBody>(
          uri,
          data: body,
          cancelToken: scope.cancelToken,
          options: Options(
            method: method,
            followRedirects: false,
            validateStatus: (_) => true,
            responseType: ResponseType.stream,
            headers: {
              'Accept': 'application/json, text/html;q=0.8',
              'User-Agent': 'Phase/1.0 (Web Search)',
              if (body != null) 'Content-Type': 'application/json',
              ...headers,
            },
          ),
        ),
      );
      final status = response.statusCode ?? 0;
      if (status < 200 || status >= 300) {
        final rejectedBody = response.data;
        if (rejectedBody != null) {
          await rejectedBody.stream.listen(null).cancel();
        }
        scope.check();
        if (status >= 300 && status < 400) {
          throw const WebFailure('redirectBlocked', '搜索接口返回重定向，请直接配置最终接口地址');
        }
        throw _httpFailure(status);
      }
      final data = response.data;
      if (data == null) {
        throw const WebFailure('invalidResponse', '搜索接口未返回有效内容');
      }
      final result = await readWebResponse(
        data.stream,
        scope,
        maxBytes: maxResponseBytes,
      );
      scope.check();
      return utf8.decode(result.bytes);
    } on WebFailure {
      rethrow;
    } on DioException catch (error) {
      scope.check();
      throw switch (error.type) {
        DioExceptionType.cancel => const WebFailure('cancelled', '网页请求已停止'),
        DioExceptionType.connectionTimeout ||
        DioExceptionType.receiveTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.transformTimeout => const WebFailure(
          'timeout',
          '搜索接口请求超时',
        ),
        DioExceptionType.badCertificate => const WebFailure(
          'certificate',
          '搜索接口证书校验失败',
        ),
        _ => const WebFailure('network', '搜索接口连接失败，请检查网络或接口地址'),
      };
    } on FormatException {
      throw const WebFailure('invalidResponse', '搜索接口返回了无法解析的内容');
    } on Object {
      scope.check();
      throw const WebFailure('network', '未收到搜索接口的完整响应');
    }
  }

  Future<Map<String, dynamic>> json(
    Uri uri,
    WebRequestScope scope, {
    String method = 'POST',
    Map<String, String> headers = const {},
    Map<String, dynamic>? body,
  }) async {
    final content = await text(
      uri,
      scope,
      method: method,
      headers: headers,
      body: body == null ? null : jsonEncode(body),
    );
    try {
      final decoded = jsonDecode(content);
      if (decoded is! Map<String, dynamic>) throw const FormatException();
      return decoded;
    } on FormatException {
      throw const WebFailure('invalidResponse', '搜索接口未返回有效的 JSON 数据');
    }
  }

  static WebFailure _httpFailure(int status) => switch (status) {
    401 || 403 => const WebFailure('authentication', '搜索接口拒绝访问，请检查密钥与权限'),
    429 => const WebFailure('rateLimited', '搜索请求过于频繁或额度不足，请稍后再试'),
    >= 500 => const WebFailure('server', '搜索服务暂时不可用，请稍后再试'),
    _ => WebFailure('http$status', '搜索接口请求失败（HTTP $status）'),
  };
}
