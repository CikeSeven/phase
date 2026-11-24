import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show compute;

import '../../../core/error/failure.dart';
import '../../models/image_generation.dart';
import 'web_fetch_client.dart';
import 'web_request_scope.dart';

class OpenAiImageClient {
  const OpenAiImageClient();

  static const _maxImageBytes = 24 * 1024 * 1024;
  static const _maxJsonBytes = 34 * 1024 * 1024;
  static const _timeout = Duration(minutes: 3);

  Future<GeneratedImage> generate({
    required Uri endpoint,
    required String modelId,
    required String? apiKey,
    required ImageGenerationRequest request,
    required Future<void> cancellation,
  }) async {
    final scope = WebRequestScope(
      timeout: _timeout,
      cancellation: cancellation,
    );
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 30),
        receiveTimeout: _timeout,
      ),
    );
    try {
      final response = await scope.guard(
        dio.postUri<ResponseBody>(
          endpoint,
          data: {
            'model': modelId,
            'prompt': request.prompt,
            'size': ?request.size,
            'quality': ?request.quality,
            'background': ?request.background,
            'output_format': ?request.outputFormat,
          },
          cancelToken: scope.cancelToken,
          options: Options(
            contentType: Headers.jsonContentType,
            responseType: ResponseType.stream,
            followRedirects: false,
            validateStatus: (_) => true,
            headers: {if (apiKey != null) 'Authorization': 'Bearer $apiKey'},
          ),
        ),
      );
      final data = response.data;
      final status = response.statusCode ?? 0;
      if (status < 200 || status >= 300) {
        await data?.stream.listen(null).cancel();
        throw _httpFailure(status);
      }
      if (data == null) throw const OperationFailure('服务商未返回图像数据');
      final body = await readWebResponse(
        data.stream,
        scope,
        maxBytes: _maxJsonBytes,
      );
      final image = await scope.guard(compute(_decodeResponse, body.bytes));
      final bytes =
          image.bytes ??
          await const WebFetchClient().fetchImageBytes(
            image.url!,
            scope,
            maxBytes: _maxImageBytes,
          );
      scope.check();
      return _identify(bytes);
    } on WebFailure catch (error) {
      throw switch (error.code) {
        'cancelled' => const CancelledFailure('Image generation cancelled'),
        'timeout' => const OperationFailure('图像生成超时，请重试'),
        'responseTooLarge' => const OperationFailure('图像生成响应超过大小上限'),
        _ => const OperationFailure('图像下载失败，服务商需返回图片数据或公网地址'),
      };
    } on DioException catch (error) {
      throw switch (error.type) {
        DioExceptionType.cancel => const CancelledFailure(
          'Image generation cancelled',
        ),
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout ||
        DioExceptionType.transformTimeout => const OperationFailure(
          '图像生成请求超时，请重试',
        ),
        _ => const NetworkFailure('Image generation request failed'),
      };
    } on Failure {
      rethrow;
    } on FormatException {
      throw const OperationFailure('生图接口返回的图像数据格式无效');
    } on Exception {
      throw const OperationFailure('未收到完整的图像生成结果');
    } finally {
      scope.close();
      dio.close(force: true);
    }
  }

  static ({Uint8List? bytes, String? url}) _decodeResponse(Uint8List body) {
    if (jsonDecode(utf8.decode(body)) case {'data': [final Map item, ...]}) {
      if (item['b64_json'] case final String encoded when encoded.isNotEmpty) {
        if (encoded.length > ((_maxImageBytes + 2) ~/ 3) * 4) {
          throw const OperationFailure('生成的图像超过大小上限');
        }
        return (bytes: base64Decode(encoded), url: null);
      }
      if (item['url'] case final String url when url.isNotEmpty) {
        return (bytes: null, url: url);
      }
    }
    throw const OperationFailure('服务商未返回图像数据');
  }

  static GeneratedImage _identify(Uint8List bytes) {
    if (bytes.length > _maxImageBytes) {
      throw const OperationFailure('生成的图像超过大小上限');
    }
    final data = ByteData.sublistView(bytes);
    if (bytes.length >= 8 &&
        data.getUint32(0) == 0x89504e47 &&
        data.getUint32(4) == 0x0d0a1a0a) {
      return (bytes: bytes, mimeType: 'image/png', extension: 'png');
    }
    if (bytes.length >= 3 && data.getUint16(0) == 0xffd8 && bytes[2] == 0xff) {
      return (bytes: bytes, mimeType: 'image/jpeg', extension: 'jpg');
    }
    if (bytes.length >= 12 &&
        data.getUint32(0) == 0x52494646 &&
        data.getUint32(8) == 0x57454250) {
      return (bytes: bytes, mimeType: 'image/webp', extension: 'webp');
    }
    throw const OperationFailure('生图接口须返回 PNG、JPEG 或 WebP 图片');
  }

  static Failure _httpFailure(int status) => switch (status) {
    401 || 403 => const AuthFailure('Image generation authorization failed'),
    404 => const OperationFailure('找不到生图接口或图像模型，请检查服务商配置'),
    429 => const RateLimitFailure('Image generation rate limit'),
    >= 500 => const ServerFailure('Image generation service unavailable'),
    _ => OperationFailure('生图请求失败（HTTP $status），请检查图像模型与参数'),
  };
}
