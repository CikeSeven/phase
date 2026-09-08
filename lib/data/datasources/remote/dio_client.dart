import 'package:dio/dio.dart';

import '../../../core/utils/logger.dart';

/// 创建统一配置的 dio 实例：超时 + 脱敏日志。
Dio createAppDio({String? baseUrl}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl ?? '',
      connectTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 120),
    ),
  );
  dio.interceptors.add(AppLogInterceptor());
  return dio;
}

/// 请求日志拦截器。
///
/// 脱敏纪律：只记录方法与 URL，绝不打印 header（含 Authorization）与 body，
/// 避免 API Key / 对话内容进日志。
class AppLogInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    AppLogger.debug('--> ${options.method} ${options.uri}');
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    AppLogger.debug(
      '<-- ${response.statusCode} ${response.requestOptions.uri}',
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    AppLogger.warning(
      'xxx ${err.requestOptions.method} ${err.requestOptions.uri}: ${err.type}',
    );
    handler.next(err);
  }
}
