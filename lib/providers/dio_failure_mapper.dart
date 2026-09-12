import 'dart:convert';

import 'package:dio/dio.dart';

import '../core/error/provider_error.dart';

/// 把 dio 异常映射为统一的 [ProviderError] 分类（design 第五部分 §5.2）。
///
/// 分类只依据 dio 异常类型、HTTP 状态码与协议明确写出的错误字段；
/// 不按错误文本匹配，也不为未见的网关变体猜测降级路径。
ProviderError mapDioExceptionToProviderError(DioException error) {
  switch (error.type) {
    case DioExceptionType.cancel:
      return ProviderError(
        ProviderErrorCategory.cancelled,
        '请求已取消',
        cause: error,
      );
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
      return ProviderError(
        ProviderErrorCategory.timeout,
        '请求超时或连接超时',
        cause: error,
      );
    case DioExceptionType.connectionError:
    case DioExceptionType.badCertificate:
      return ProviderError(
        ProviderErrorCategory.network,
        '网络连接失败',
        cause: error,
      );
    case DioExceptionType.badResponse:
      return mapHttpResponseError(
        statusCode: error.response?.statusCode ?? 0,
        body: error.response?.data,
        cause: error,
      );
    case DioExceptionType.unknown:
      return ProviderError(
        ProviderErrorCategory.network,
        '网络请求异常: ${error.type.name}',
        cause: error,
      );
  }
}

/// 按 HTTP 状态码与协议明确的错误字段分类响应错误。
///
/// 状态码只在协议没有给出错误字段时决定分类。
ProviderError mapHttpResponseError({
  required int statusCode,
  Object? body,
  Object? cause,
}) {
  final error = protocolErrorObject(body);
  final category =
      categoryForProtocolError(error) ??
      _categoryForStatus(statusCode) ??
      ProviderErrorCategory.providerError;
  final message = protocolErrorMessage(error) ?? 'HTTP $statusCode';
  return ProviderError(category, message, cause: cause);
}

/// 流内错误事件（HTTP 200 的 SSE 里夹带的 error 对象）映射为分类错误。
///
/// 错误值是纯字符串时只作为文案（协议没有给出可分类的字段）。
ProviderError mapProtocolError(Object? error) {
  if (error is String && error.trim().isNotEmpty) {
    return ProviderError(ProviderErrorCategory.providerError, error.trim());
  }
  final object = protocolErrorObject(error);
  return ProviderError(
    categoryForProtocolError(object) ?? ProviderErrorCategory.providerError,
    protocolErrorMessage(object) ?? '协议返回错误事件',
  );
}

/// 取出协议错误对象：`{"error": {...}}` 与错误对象本身都能识别。
Object? protocolErrorObject(Object? body) {
  Object? decoded = body;
  if (decoded is String) {
    try {
      decoded = jsonDecode(decoded);
    } on FormatException {
      return null;
    }
  }
  if (decoded is! Map) return null;
  final nested = decoded['error'];
  if (nested is Map) return nested;
  return decoded;
}

/// 协议错误对象里的安全文案（只取协议写明的 message 字段）。
String? protocolErrorMessage(Object? error) {
  if (error is Map && error['message'] is String) {
    final message = (error['message'] as String).trim();
    if (message.isNotEmpty) return message;
  }
  return null;
}

/// 协议错误字段到分类的映射表。
///
/// 键是各协议文档写明的错误类型/错误码（如 Anthropic 的 `invalid_request_error`、
/// Google 的 `INVALID_ARGUMENT`、OpenAI 的 `context_length_exceeded`），
/// 只做精确匹配，不做文本匹配或前缀猜测。
ProviderErrorCategory? categoryForProtocolError(Object? error) {
  if (error is! Map) return null;
  for (final field in const ['type', 'code', 'status', 'reason']) {
    final value = error[field];
    if (value is String && _categoryByErrorField[value] != null) {
      return _categoryByErrorField[value];
    }
  }
  return null;
}

const _categoryByErrorField = <String, ProviderErrorCategory>{
  // 鉴权与权限
  'authentication_error': ProviderErrorCategory.auth,
  'invalid_api_key': ProviderErrorCategory.auth,
  'permission_error': ProviderErrorCategory.auth,
  'permission_denied': ProviderErrorCategory.auth,
  'UNAUTHENTICATED': ProviderErrorCategory.auth,
  'PERMISSION_DENIED': ProviderErrorCategory.auth,
  'API_KEY_INVALID': ProviderErrorCategory.auth,
  // 限流与配额
  'rate_limit_error': ProviderErrorCategory.rateLimit,
  'rate_limit_exceeded': ProviderErrorCategory.rateLimit,
  'insufficient_quota': ProviderErrorCategory.rateLimit,
  'RESOURCE_EXHAUSTED': ProviderErrorCategory.rateLimit,
  // 超出模型上下文容量
  'context_length_exceeded': ProviderErrorCategory.contextLimit,
  'CONTEXT_LENGTH_EXCEEDED': ProviderErrorCategory.contextLimit,
  'request_too_large': ProviderErrorCategory.contextLimit,
  // 请求本身不合法
  'invalid_request_error': ProviderErrorCategory.invalidRequest,
  'invalid_request': ProviderErrorCategory.invalidRequest,
  'invalid_prompt': ProviderErrorCategory.invalidRequest,
  'not_found_error': ProviderErrorCategory.invalidRequest,
  'invalid_argument': ProviderErrorCategory.invalidRequest,
  'INVALID_ARGUMENT': ProviderErrorCategory.invalidRequest,
  'NOT_FOUND': ProviderErrorCategory.invalidRequest,
  'FAILED_PRECONDITION': ProviderErrorCategory.invalidRequest,
  // 服务商侧错误
  'api_error': ProviderErrorCategory.providerError,
  'server_error': ProviderErrorCategory.providerError,
  'overloaded_error': ProviderErrorCategory.providerError,
  'internal_error': ProviderErrorCategory.providerError,
  'INTERNAL': ProviderErrorCategory.providerError,
  'UNAVAILABLE': ProviderErrorCategory.providerError,
  // 超时
  'DEADLINE_EXCEEDED': ProviderErrorCategory.timeout,
};

ProviderErrorCategory? _categoryForStatus(int statusCode) {
  if (statusCode == 401 || statusCode == 403) {
    return ProviderErrorCategory.auth;
  }
  if (statusCode == 408) return ProviderErrorCategory.timeout;
  if (statusCode == 413) return ProviderErrorCategory.contextLimit;
  if (statusCode == 429) return ProviderErrorCategory.rateLimit;
  if (statusCode >= 400 && statusCode < 500) {
    return ProviderErrorCategory.invalidRequest;
  }
  if (statusCode >= 500) return ProviderErrorCategory.providerError;
  return null;
}
