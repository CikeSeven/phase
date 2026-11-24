import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import '../../../core/error/failure.dart';
import '../../models/video_generation.dart';
import 'web_fetch_client.dart';
import 'web_request_scope.dart';

class VideoGenerationClient {
  const VideoGenerationClient();

  static const _maxVideoBytes = 256 * 1024 * 1024;
  static const _pollInterval = Duration(seconds: 15);
  static final _jobId = RegExp(r'^[A-Za-z0-9_-][A-Za-z0-9_.:-]{0,159}$');

  Dio _connection(String? apiKey) => Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 90),
      followRedirects: false,
      validateStatus: (_) => true,
      headers: {
        if (apiKey != null) HttpHeaders.authorizationHeader: 'Bearer $apiKey',
      },
    ),
  );

  Future<List<VideoCatalogModel>> listModels({
    required Uri endpoint,
    required VideoGenerationProtocol protocol,
    required String? apiKey,
    required Future<void> cancellation,
  }) async {
    final scope = WebRequestScope(
      timeout: const Duration(seconds: 25),
      cancellation: cancellation,
    );
    final dio = _connection(apiKey);
    try {
      final result = await _job(
        dio,
        scope,
        endpoint,
        maxBytes: 8 * 1024 * 1024,
      );
      return VideoCatalogModel.readList(result['data'], protocol);
    } on WebFailure catch (error) {
      if (error.code == 'cancelled') throw const CancelledFailure('视频模型查询已停止');
      throw const OperationFailure('读取视频模型列表超时或响应过大');
    } on DioException {
      throw const OperationFailure('无法连接视频服务商获取模型列表');
    } on FormatException {
      throw const OperationFailure('服务商返回了无法解析的视频模型列表');
    } finally {
      scope.close();
      dio.close(force: true);
    }
  }

  Future<void> generate({
    required Uri endpoint,
    required VideoGenerationProtocol protocol,
    required String? apiKey,
    required String modelId,
    required String prompt,
    required Map<String, Object?> parameters,
    required File destination,
    required Future<void> cancellation,
    void Function(String)? onProgress,
  }) async {
    final scope = WebRequestScope(
      timeout: const Duration(minutes: 15),
      cancellation: cancellation,
    );
    final dio = _connection(apiKey);
    String? jobId;
    try {
      var job = await _job(
        dio,
        scope,
        endpoint,
        payload: {
          ...parameters,
          'model': modelId,
          if (protocol == VideoGenerationProtocol.seedance)
            'content': [
              {'type': 'text', 'text': prompt},
            ]
          else
            'prompt': prompt,
        },
      );
      final id = job['id'];
      if (id is! String || !_jobId.hasMatch(id)) {
        throw const OperationFailure('视频服务未返回有效的任务编号');
      }
      jobId = id;
      final task = endpoint.replace(
        pathSegments: [...endpoint.pathSegments, id],
      );
      var status = job['status'] ?? 'pending';
      while (const {
        'pending',
        'queued',
        'running',
        'in_progress',
        'processing',
      }.contains(status)) {
        final pct = job['progress'];
        final label = const {'pending', 'queued'}.contains(status)
            ? '视频排队中'
            : '视频生成中';
        onProgress?.call(
          pct is num && pct >= 0 && pct <= 100
              ? '$label · ${pct.round()}%'
              : label,
        );
        await scope.guard(Future<void>.delayed(_pollInterval));
        try {
          job = await _job(dio, scope, task);
          status = job['status'];
        } on RateLimitFailure {
          onProgress?.call('等待视频服务恢复查询');
        } on ServerFailure {
          onProgress?.call('等待视频服务恢复查询');
        }
      }
      if (status == 'cancelled') throw const CancelledFailure('服务商取消了视频任务');
      if (status == 'expired') throw OperationFailure('视频任务已过期（$id）');
      if (status == 'failed') throw OperationFailure('视频服务生成失败（$id）');
      if (status != 'completed' && status != 'succeeded') {
        throw OperationFailure('视频服务返回了无法识别的任务状态（$id）');
      }

      onProgress?.call('正在下载视频');
      if (protocol == VideoGenerationProtocol.seedance) {
        final content = job['content'];
        final url = content is Map ? content['video_url'] : null;
        if (url is! String || url.isEmpty) {
          throw OperationFailure('视频服务未返回下载地址（$id）');
        }
        await const WebFetchClient().downloadVideo(
          url,
          scope,
          destination,
          maxBytes: _maxVideoBytes,
        );
      } else {
        await _download(
          dio,
          scope,
          task.replace(pathSegments: [...task.pathSegments, 'content']),
          destination,
        );
      }
      await _checkMp4(destination);
      scope.check();
    } on WebFailure catch (error) {
      throw switch (error.code) {
        'cancelled' => const CancelledFailure('视频等待已取消'),
        'timeout' => OperationFailure(
          jobId == null ? '等待视频服务响应超时' : '等待视频任务超时（$jobId）',
        ),
        'responseTooLarge' => const OperationFailure('视频或服务响应超过大小上限'),
        _ => OperationFailure(jobId == null ? '视频服务响应无效' : '视频下载失败（$jobId）'),
      };
    } on DioException catch (error) {
      if (error.type == DioExceptionType.cancel) {
        throw const CancelledFailure('视频等待已取消');
      }
      throw OperationFailure(
        jobId == null ? '连接视频服务失败，请检查网络' : '视频连接中断（$jobId）',
      );
    } on FileSystemException {
      throw const OperationFailure('无法写入视频文件，请检查可用存储空间');
    } on FormatException {
      throw const OperationFailure('视频服务返回了无效的数据');
    } finally {
      scope.close();
      dio.close(force: true);
    }
  }

  Future<Map<String, dynamic>> _job(
    Dio dio,
    WebRequestScope scope,
    Uri uri, {
    Map<String, Object?>? payload,
    int maxBytes = 256 * 1024,
  }) async {
    final response = await scope.guard(
      dio.requestUri<ResponseBody>(
        uri,
        data: payload,
        cancelToken: scope.cancelToken,
        options: Options(
          method: payload == null ? 'GET' : 'POST',
          responseType: ResponseType.stream,
          contentType: payload == null ? null : Headers.jsonContentType,
        ),
      ),
    );
    final body = await _body(response);
    final bytes = (await readWebResponse(
      body.stream,
      scope,
      maxBytes: maxBytes,
    )).bytes;
    if (jsonDecode(utf8.decode(bytes)) case final Map<String, dynamic> job) {
      return job;
    }
    throw const OperationFailure('视频服务未返回任务数据');
  }

  Future<void> _download(
    Dio dio,
    WebRequestScope scope,
    Uri uri,
    File destination,
  ) async {
    final response = await scope.guard(
      dio.getUri<ResponseBody>(
        uri,
        options: Options(
          responseType: ResponseType.stream,
          headers: {HttpHeaders.acceptHeader: 'video/mp4'},
        ),
        cancelToken: scope.cancelToken,
      ),
    );
    final location = response.headers.value(HttpHeaders.locationHeader);
    if (const {301, 302, 303, 307, 308}.contains(response.statusCode) &&
        location != null) {
      await response.data?.stream.listen(null).cancel();
      await const WebFetchClient().downloadVideo(
        uri.resolve(location).toString(),
        scope,
        destination,
        maxBytes: _maxVideoBytes,
      );
      return;
    }
    final body = await _body(response);
    if ((int.tryParse(
              response.headers.value(HttpHeaders.contentLengthHeader) ?? '',
            ) ??
            0) >
        _maxVideoBytes) {
      await body.stream.listen(null).cancel();
      throw const WebFailure('responseTooLarge', '下载结果超过大小上限');
    }
    await writeWebResponse(
      body.stream,
      scope,
      destination,
      maxBytes: _maxVideoBytes,
    );
  }

  Future<ResponseBody> _body(Response<ResponseBody> response) async {
    final status = response.statusCode ?? 0;
    if (status >= 200 && status < 300 && response.data != null) {
      return response.data!;
    }
    await response.data?.stream.listen(null).cancel();
    throw switch (status) {
      401 || 403 => const AuthFailure('Video generation authorization failed'),
      402 => const OperationFailure('视频服务余额不足或未启用计费'),
      404 => const OperationFailure('找不到视频接口、模型或任务，请检查服务商配置'),
      429 => const RateLimitFailure('Video generation rate limit'),
      >= 500 => const ServerFailure('Video service unavailable'),
      _ => OperationFailure('视频接口请求失败（HTTP $status），请检查协议与参数'),
    };
  }

  Future<void> _checkMp4(File file) async {
    final input = await file.open();
    try {
      final header = await input.read(12);
      if (header.length < 12 ||
          String.fromCharCodes(header.sublist(4, 8)) != 'ftyp') {
        throw const OperationFailure('视频服务未返回有效的 MP4 文件');
      }
    } finally {
      await input.close();
    }
  }
}
