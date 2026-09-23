import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/error/provider_error.dart';
import 'package:phase/data/datasources/remote/models_dev_client.dart';

/// models.dev 拉取：ETag 增量校验、瘦身解析、错误统一映射为 ProviderError。
void main() {
  const apiBody =
      '{"anthropic":{"models":{'
      '"claude-haiku-4-5":{"limit":{"context":200000,"output":64000}}'
      '}}}';

  ModelsDevClient client(_FakeAdapter adapter) =>
      ModelsDevClient(dio: Dio()..httpClientAdapter = adapter);

  test('200 返回瘦身目录与 ETag', () async {
    final adapter = _FakeAdapter(apiBody, etag: '"tag-1"');
    final result = await client(adapter).fetch();
    expect(result, isA<ModelsDevFetched>());
    final fetched = result as ModelsDevFetched;
    expect(fetched.etag, '"tag-1"');
    expect(
      fetched.catalog.lookup('anthropic', 'claude-haiku-4-5')?.contextWindow,
      200000,
    );
    expect(fetched.catalog.fetchedAt, isNotNull);
    expect(adapter.lastRequest!.uri.toString(), ModelsDevClient.url);
    expect(adapter.lastRequest!.headers.containsKey('if-none-match'), isFalse);
  });

  test('带 ETag 时发送 if-none-match，304 返回未变化', () async {
    final adapter = _FakeAdapter('', statusCode: 304);
    final result = await client(adapter).fetch(etag: '"tag-1"');
    expect(result, isA<ModelsDevNotModified>());
    expect(adapter.lastRequest!.headers['if-none-match'], '"tag-1"');
  });

  test('200 但正文不是目录 JSON 时映射为 ProviderError', () async {
    final adapter = _FakeAdapter('["not","a","catalog"]');
    await expectLater(
      client(adapter).fetch(),
      throwsA(
        isA<ProviderError>().having(
          (error) => error.category,
          'category',
          ProviderErrorCategory.providerError,
        ),
      ),
    );
  });

  test('空对象、错误信封和无有效模型的 200 响应不能覆盖缓存', () async {
    for (final body in [
      '{}',
      '{"error":{"message":"not a catalog"}}',
      '{"openai":{"models":{"x":{"limit":{"context":0,"output":0}}}}}',
    ]) {
      await expectLater(
        client(_FakeAdapter(body)).fetch(),
        throwsA(isA<ProviderError>()),
      );
    }
  });

  test('未发送 ETag 的 304 不是成功更新', () async {
    await expectLater(
      client(_FakeAdapter('', statusCode: 304)).fetch(),
      throwsA(isA<ProviderError>()),
    );
  });

  test('取消目录请求映射为 cancelled', () async {
    final token = CancelToken()..cancel();
    await expectLater(
      client(_FakeAdapter(apiBody)).fetch(cancelToken: token),
      throwsA(
        isA<ProviderError>().having(
          (e) => e.category,
          'category',
          ProviderErrorCategory.cancelled,
        ),
      ),
    );
  });

  test('HTTP 500 映射为 ProviderError', () async {
    final adapter = _FakeAdapter('{}', statusCode: 500);
    await expectLater(
      client(adapter).fetch(),
      throwsA(
        isA<ProviderError>().having(
          (error) => error.category,
          'category',
          ProviderErrorCategory.providerError,
        ),
      ),
    );
  });

  test('断网映射为 network', () async {
    final adapter = _FakeAdapter('', connectionError: true);
    await expectLater(
      client(adapter).fetch(),
      throwsA(
        isA<ProviderError>().having(
          (error) => error.category,
          'category',
          ProviderErrorCategory.network,
        ),
      ),
    );
  });
}

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(
    this.body, {
    this.statusCode = 200,
    this.etag,
    this.connectionError = false,
  });

  final String body;
  final int statusCode;
  final String? etag;
  final bool connectionError;

  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    if (connectionError) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      );
    }
    return ResponseBody.fromString(
      body,
      statusCode,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
        if (etag != null) 'etag': [etag!],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
