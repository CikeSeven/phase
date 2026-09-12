import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'http_tool.dart';

/// 独立的工具 HTTP 通道，不安装包含 URL 或正文的日志拦截器。
Future<HttpFetchResult> fetchToolHttp(Dio dio, HttpFetchRequest request) async {
  request.cancellation.throwIfCancelled();
  final token = CancelToken();
  var active = true;
  final cancelled = request.cancellation.whenCancelled.then((_) {
    if (active) token.cancel();
  });
  // 取消通知不抛出异常；请求结束后该通知不会再操作 token。
  cancelled.ignore();
  try {
    final response = await dio.request<ResponseBody>(
      request.uri.toString(),
      data: request.body,
      options: Options(
        method: request.method,
        headers: request.headers,
        responseType: ResponseType.stream,
        receiveTimeout: request.timeout,
        sendTimeout: request.timeout,
        validateStatus: (_) => true,
      ),
      cancelToken: token,
    );
    final bytes = BytesBuilder(copy: false);
    var truncated = false;
    final body = response.data;
    if (body != null) {
      await for (final chunk in body.stream) {
        final remaining = request.maxBytes - bytes.length;
        if (chunk.length > remaining) {
          bytes.add(chunk.sublist(0, remaining));
          truncated = true;
          break;
        }
        bytes.add(chunk);
      }
    }
    return HttpFetchResult(
      statusCode: response.statusCode ?? 0,
      body: bytes.takeBytes(),
      truncated: truncated,
    );
  } on DioException catch (error) {
    final code = switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => 'timeout',
      DioExceptionType.cancel => 'cancelled',
      DioExceptionType.badCertificate => 'badCertificate',
      _ => 'network',
    };
    // 写请求在取得响应前断开，不能推断外部动作没有发生。
    final unknown =
        request.method != 'GET' &&
        error.type != DioExceptionType.connectionTimeout &&
        error.type != DioExceptionType.badCertificate;
    throw HttpFetchException(
      code,
      unknown
          ? '请求可能已经生效，但未取得可靠结果，请核验目标状态。'
          : switch (code) {
              'cancelled' => '请求已取消',
              'timeout' => '请求超时',
              'badCertificate' => '服务端证书校验失败',
              _ => '连接服务器失败',
            },
      unknown: unknown,
    );
  } finally {
    active = false;
    token.cancel();
  }
}
