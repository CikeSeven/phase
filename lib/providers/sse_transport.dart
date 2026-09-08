import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../core/error/failure.dart';
import '../data/models/chat_chunk.dart';
import 'dio_failure_mapper.dart';

/// 从 SSE 字节流提取 `data:` 载荷行。
///
/// utf8 解码 + 按行切分天然处理了跨 chunk 的半截行；
/// 空行、注释与 `event:` 等字段行被忽略。
Stream<String> decodeSseDataLines(Stream<List<int>> byteStream) async* {
  final lines = utf8.decoder.bind(byteStream).transform(const LineSplitter());
  await for (final line in lines) {
    if (line.startsWith('data:')) {
      yield line.substring(5).trim();
    }
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
