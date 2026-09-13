import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../core/error/provider_error.dart';
import '../data/models/chat_chunk.dart';
import 'dio_failure_mapper.dart';

/// 从 SSE 字节流提取事件载荷，多行 `data:` 以换行连接。
///
/// 完整 JSON 行即时交付，兼容省略事件间空行的接口；网络分片不作为边界。
Stream<String> decodeSseDataLines(Stream<List<int>> byteStream) async* {
  final lines = utf8.decoder.bind(byteStream).transform(const LineSplitter());
  var pending = <String>[];
  await for (final line in lines) {
    if (line.isEmpty) {
      if (pending.isNotEmpty) {
        yield pending.join('\n');
        pending = [];
      }
      continue;
    }
    if (!line.startsWith('data:')) continue;
    var data = line.substring(5);
    if (data.startsWith(' ')) data = data.substring(1);
    if (pending.isNotEmpty &&
        _ssePayloadState(data) == _SsePayloadState.complete) {
      final previous = pending.join('\n');
      if (data.trim() == '[DONE]' ||
          _ssePayloadState(previous) == _SsePayloadState.invalid) {
        yield previous;
        pending = [];
      }
    }
    pending.add(data);
    final payload = pending.join('\n');
    if (_ssePayloadState(payload) == _SsePayloadState.complete) {
      yield payload;
      pending = [];
    }
  }
  if (pending.isNotEmpty) yield pending.join('\n');
}

enum _SsePayloadState { complete, incomplete, invalid }

_SsePayloadState _ssePayloadState(String data) {
  if (data.trim() == '[DONE]') return _SsePayloadState.complete;
  try {
    jsonDecode(data);
    return _SsePayloadState.complete;
  } on FormatException catch (error) {
    return error.offset == data.length
        ? _SsePayloadState.incomplete
        : _SsePayloadState.invalid;
  }
}

/// 拼接 baseUrl 与协议子路径；baseUrl 为空是明确的配置错误，
/// 直接给出可展示的原因，不发出注定失败的请求。
Uri resolveEndpoint(String baseUrl, String path) {
  if (baseUrl.isEmpty) {
    throw const ProviderError(ProviderErrorCategory.config, '未填写服务商地址');
  }
  final base = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
  return Uri.parse(base).resolve(path);
}

/// 读出错误响应的正文。
///
/// 流式响应里 `data` 是 `ResponseBody`，直接当对象用会丢掉服务端写明的
/// 错误字段（分类与文案都靠它）；这里把字节流读完再交出文本。
Future<Object?> readErrorBody(Object? data) async {
  if (data is! ResponseBody) return data;
  try {
    final bytes = await data.stream.fold<List<int>>(
      <int>[],
      (all, chunk) => all..addAll(chunk),
    );
    return utf8.decode(bytes, allowMalformed: true);
  } on Exception {
    return null;
  }
}

/// 各协议共用的 SSE POST 传输：鉴权头、流式响应、取消桥接、错误映射。
///
/// 手写 controller 是为了把「订阅取消」桥接到 dio 的 CancelToken，
/// 保证停止生成即时生效（AGENTS.md §4 取消语义）。
///
/// 请求层错误（HTTP 状态、网络、取消）以 [ProviderError] 抛出；
/// 流内的协议错误由解码器转成 ResponseError 事件，不经过这里。
Stream<ChatChunk> postSseStream({
  required Dio dio,
  required Uri uri,
  required Map<String, dynamic> payload,
  required Map<String, String> headers,
  required Stream<ChatChunk> Function(Stream<List<int>> body) decode,
}) {
  final cancelToken = CancelToken();
  final controller = StreamController<ChatChunk>();
  StreamSubscription<ChatChunk>? responseSubscription;
  var cancelled = false;

  void fail(Object error, StackTrace stackTrace) {
    if (cancelled || controller.isClosed) return;
    controller.addError(mapProviderException(error), stackTrace);
    unawaited(controller.close());
  }

  controller.onListen = () async {
    try {
      final response = await dio.postUri<ResponseBody>(
        uri,
        data: payload,
        options: Options(responseType: ResponseType.stream, headers: headers),
        cancelToken: cancelToken,
      );
      if (cancelled) return;
      final body = response.data;
      if (body == null) {
        if (!controller.isClosed) {
          controller.addError(
            const ProviderError(ProviderErrorCategory.providerError, '响应体为空'),
          );
          await controller.close();
        }
      } else {
        responseSubscription = decode(body.stream).listen(
          (chunk) {
            if (!cancelled && !controller.isClosed) controller.add(chunk);
          },
          onError: fail,
          onDone: controller.close,
          cancelOnError: true,
        );
        if (controller.isPaused) responseSubscription!.pause();
      }
    } on DioException catch (e, stackTrace) {
      if (!cancelled && !controller.isClosed) {
        // 错误体可能是流式 ResponseBody：读出来才能用服务端写明的错误字段。
        final body = await readErrorBody(e.response?.data);
        if (cancelled) return;
        fail(
          e.response?.statusCode == null
              ? mapDioExceptionToProviderError(e)
              : mapHttpResponseError(
                  statusCode: e.response!.statusCode!,
                  body: body,
                  headers: e.response?.headers.map,
                  cause: e,
                ),
          stackTrace,
        );
      }
    } catch (error, stackTrace) {
      fail(error, stackTrace);
    }
  };

  controller.onPause = () => responseSubscription?.pause();
  controller.onResume = () => responseSubscription?.resume();
  controller.onCancel = () async {
    // 先中断网络，再等待解码流退出；addStream 会把这两个步骤倒置。
    cancelled = true;
    cancelToken.cancel('模型请求结束或取消');
    try {
      await responseSubscription?.cancel();
    } on DioException catch (e) {
      if (!CancelToken.isCancel(e)) rethrow;
    }
  };

  return controller.stream;
}
