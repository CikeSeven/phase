import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/error/failure.dart';

/// 一个操作共用总期限和取消源，包含凭据解析、DNS、请求及完整正文读取。
class WebRequestScope {
  WebRequestScope({required Duration timeout, Future<void>? cancellation}) {
    _timer = Timer(
      timeout,
      () => abort(const WebFailure('timeout', '网页请求超时，请重试')),
    );
    cancellation?.then((_) {
      if (!_closed) abort(const WebFailure('cancelled', '网页请求已停止'));
    }).ignore();
  }

  final cancelToken = CancelToken();
  final _aborted = Completer<void>();
  late final Timer _timer;
  WebFailure? _failure;
  bool _closed = false;

  Future<void> get whenAborted => _aborted.future;

  void check() {
    final failure = _failure;
    if (failure != null) throw failure;
  }

  void abort(WebFailure failure) {
    if (_closed || _failure != null) return;
    _failure = failure;
    _timer.cancel();
    cancelToken.cancel();
    _aborted.complete();
  }

  Future<T> guard<T>(Future<T> work) async {
    check();
    final result = await Future.any<T>([
      work,
      whenAborted.then<T>((_) {
        check();
        throw const WebFailure('cancelled', '网页请求已停止');
      }),
    ]);
    check();
    return result;
  }

  void close() {
    _closed = true;
    _timer.cancel();
    cancelToken.cancel();
  }
}

Future<({Uint8List bytes, bool truncated})> readWebResponse(
  Stream<List<int>> stream,
  WebRequestScope scope, {
  required int maxBytes,
  bool allowTruncation = false,
}) async {
  final iterator = StreamIterator(stream);
  final bytes = BytesBuilder(copy: false);
  var truncated = false;
  try {
    while (await scope.guard(iterator.moveNext())) {
      scope.check();
      final chunk = iterator.current;
      final remaining = maxBytes - bytes.length;
      if (chunk.length > remaining) {
        if (!allowTruncation) {
          throw const WebFailure('responseTooLarge', '网页响应超过大小上限，请缩小查询范围');
        }
        bytes.add(chunk.sublist(0, remaining));
        truncated = true;
        break;
      }
      bytes.add(chunk);
    }
    scope.check();
    return (bytes: bytes.takeBytes(), truncated: truncated);
  } finally {
    // 取消/超限后显式结束正文订阅，不仅丢弃等待它的 Future。
    await iterator.cancel();
  }
}
