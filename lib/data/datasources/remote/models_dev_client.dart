import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/error/provider_error.dart';
import '../../../providers/dio_failure_mapper.dart';
import '../../models/model_catalog.dart';
import 'dio_client.dart';

part 'models_dev_client.g.dart';

/// models.dev 刷新结果。
sealed class ModelsDevFetchResult {}

/// 服务端确认目录未变化（304），沿用现有缓存。
class ModelsDevNotModified extends ModelsDevFetchResult {}

/// 拉到新目录；etag 用于下次刷新的增量校验。
class ModelsDevFetched extends ModelsDevFetchResult {
  ModelsDevFetched({required this.catalog, this.etag});

  final ModelCatalog catalog;
  final String? etag;
}

/// 从 models.dev 拉取全量目录（约 4.8MB）。只有用户手动触发；
/// 带 ETag 时服务端无变化返回 304，流量约 1KB。
class ModelsDevClient {
  ModelsDevClient({Dio? dio}) : _dio = dio ?? createAppDio();

  static const url = 'https://models.dev/api.json';

  final Dio _dio;

  Future<ModelsDevFetchResult> fetch({
    String? etag,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.getUri<String>(
        Uri.parse(url),
        cancelToken: cancelToken,
        options: Options(
          responseType: ResponseType.plain,
          headers: {'accept': 'application/json', 'if-none-match': ?etag},
          validateStatus: (status) => status == 200 || status == 304,
        ),
      );
      if (response.statusCode == 304) {
        if (etag == null) {
          throw const ProviderError(
            ProviderErrorCategory.providerError,
            '模型目录未提供可复用的缓存',
          );
        }
        return ModelsDevNotModified();
      }
      final body = response.data;
      Object? decoded;
      try {
        decoded = body == null ? null : jsonDecode(body);
      } on FormatException {
        decoded = null;
      }
      if (decoded is! Map<String, dynamic>) {
        throw const ProviderError(
          ProviderErrorCategory.providerError,
          '模型目录响应格式无法识别',
        );
      }
      final catalog = ModelCatalog.slimFromModelsDevJson(
        decoded,
        fetchedAt: DateTime.now().toUtc(),
      );
      if (catalog.modelCount == 0) {
        throw const ProviderError(
          ProviderErrorCategory.providerError,
          '模型目录未包含有效上限',
        );
      }
      return ModelsDevFetched(
        catalog: catalog,
        etag: response.headers.value('etag'),
      );
    } on DioException catch (error) {
      throw mapDioExceptionToProviderError(error);
    }
  }

  void close() => _dio.close(force: true);
}

@Riverpod(keepAlive: true)
ModelsDevClient modelsDevClient(Ref ref) {
  final client = ModelsDevClient();
  ref.onDispose(client.close);
  return client;
}
