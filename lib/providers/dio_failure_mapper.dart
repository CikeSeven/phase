import 'package:dio/dio.dart';

import '../core/error/failure.dart';

/// 把 dio 异常映射为统一的 [Failure] 体系。
///
/// 纯函数，便于独立单测；所有协议实现共用。
Failure mapDioExceptionToFailure(DioException error) {
  switch (error.type) {
    case DioExceptionType.cancel:
      return CancelledFailure('请求已取消', cause: error);
    case DioExceptionType.connectionError:
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
      return NetworkFailure('连接失败或超时: ${error.message}', cause: error);
    case DioExceptionType.badResponse:
      final status = error.response?.statusCode ?? 0;
      if (status == 401 || status == 403) {
        return AuthFailure('鉴权失败 (HTTP $status)', cause: error);
      }
      if (status == 429) {
        return RateLimitFailure('触发限流 (HTTP 429)', cause: error);
      }
      if (status >= 500) {
        return ServerFailure('服务端错误 (HTTP $status)', cause: error);
      }
      return UnknownFailure('未预期的响应 (HTTP $status)', cause: error);
    case DioExceptionType.badCertificate:
    case DioExceptionType.unknown:
      return UnknownFailure('网络请求异常: ${error.message}', cause: error);
  }
}
