import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../core/error/failure.dart';
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

/// 各协议共用的 SSE POST 传输：鉴权头、流式响应、取消桥接、错误映射。
///
/// 手写 controller 是为了把「订阅取消」桥接到 dio 的 CancelToken，
/// 保证停止生成即时生效（AGENTS.md §4 取消语义）。
Stream<ChatChunk> postSseStream({
  required Dio dio,
  required Uri uri,
  required Map<String, dynamic> payload,
  required Map<String, String> headers,
  required Stream<ChatChunk> Function(Stream<List<int>> body) decode,
}) {
  final cancelToken = CancelToken();
  final controller = StreamController<ChatChunk>();

  controller.onListen = () async {
    try {
      final response = await dio.postUri<ResponseBody>(
        uri,
        data: payload,
        options: Options(responseType: ResponseType.stream, headers: headers),
        cancelToken: cancelToken,
      );
      final body = response.data;
      if (body == null) {
        throw const ServerFailure('响应体为空');
      }
      // 协议错误事件由 decode 以 Failure 形式抛出，addStream 原样转发。
      await controller.addStream(decode(body.stream));
    } on DioException catch (e) {
      if (!controller.isClosed) {
        controller.addError(mapDioExceptionToFailure(e));
      }
    }
    if (!controller.isClosed) {
      await controller.close();
    }
  };

  controller.onCancel = () {
    cancelToken.cancel('用户停止生成');
  };

  return controller.stream;
}
