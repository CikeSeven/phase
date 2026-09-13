import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/error/provider_error.dart';
import 'package:phase/features/chat/model_retry.dart';
import 'package:phase/providers/dio_failure_mapper.dart';

void main() {
  test('错误资格来自状态码/明确字段，不依据错误文案', () {
    for (final status in [408, 429, 500, 502, 503, 504]) {
      expect(mapHttpResponseError(statusCode: status).retryable, isTrue);
    }
    for (final status in [400, 401, 403, 404, 413]) {
      expect(mapHttpResponseError(statusCode: status).retryable, isFalse);
    }
    expect(mapProtocolError({'code': 'server_error'}).retryable, isTrue);
    expect(mapProtocolError({'type': 'overloaded_error'}).retryable, isTrue);
    expect(mapProtocolError({'status': 'UNAVAILABLE'}).retryable, isTrue);
    expect(
      mapProtocolError({'message': 'server error 503 please retry'}).retryable,
      isFalse,
    );
    expect(
      mapProtocolError({
        'type': 'rate_limit_error',
        'code': 'insufficient_quota',
      }).category,
      ProviderErrorCategory.quota,
    );
    expect(
      mapProtocolError({
        'type': 'rate_limit_error',
        'code': 'insufficient_quota',
      }).retryable,
      isFalse,
    );
    expect(
      mapDioExceptionToProviderError(
        DioException(
          requestOptions: RequestOptions(),
          type: DioExceptionType.badCertificate,
        ),
      ).retryable,
      isFalse,
    );
  });

  test('Retry-After 支持秒数、HTTP 日期，忽略非法值且不溢出', () {
    final now = DateTime.utc(2026, 9, 13);
    expect(
      parseRetryAfter({
        'Retry-After': ['3'],
      }),
      const Duration(seconds: 3),
    );
    expect(
      parseRetryAfter({
        'retry-after': [HttpDate.format(now.add(const Duration(seconds: 5)))],
      }, now: now),
      const Duration(seconds: 5),
    );
    expect(
      parseRetryAfter({
        'retry-after': [
          HttpDate.format(now.subtract(const Duration(seconds: 5))),
        ],
      }, now: now),
      Duration.zero,
    );
    for (final value in ['-1', 'NaN', 'Infinity', 'invalid']) {
      expect(
        parseRetryAfter({
          'retry-after': [value],
        }),
        isNull,
      );
    }
    expect(
      parseRetryAfter({
        'retry-after': ['1e100'],
      })!.isNegative,
      isFalse,
    );
  });

  test('同一模型轮的指数退避、次数上限与过长等待', () {
    const policy = ModelRetryPolicy();
    const network = ProviderError(ProviderErrorCategory.network, 'fixture');
    expect(policy.delayFor(network, 1), const Duration(seconds: 2));
    expect(policy.delayFor(network, 2), const Duration(seconds: 4));
    expect(policy.delayFor(network, 3), isNull);
    expect(
      policy.delayFor(
        const ProviderError(
          ProviderErrorCategory.rateLimit,
          'fixture',
          retryAfter: Duration(seconds: 30),
        ),
        1,
      ),
      const Duration(seconds: 30),
    );
    expect(
      policy.delayFor(
        const ProviderError(
          ProviderErrorCategory.rateLimit,
          'fixture',
          retryAfter: Duration(seconds: 61),
        ),
        1,
      ),
      isNull,
    );
  });
}
