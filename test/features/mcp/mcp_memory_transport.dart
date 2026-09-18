import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:phase/data/models/mcp_server_profile.dart';

/// 模拟 HTTP 边界的数据，不替代 mcp_client_test 的真实连接取消验收。
class McpMemoryTransport implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  final messages = <Map<String, dynamic>>[];
  int calls = 0;
  int deletes = 0;
  bool closed = false;
  bool sse = true;
  bool hangCall = false;
  bool duplicate = false;
  bool paginate = false;
  bool listChanged = false;
  StreamController<Uint8List>? events;
  final eventsOpened = Completer<void>();
  bool repeatCursor = false;
  int? status;
  String version = '2025-06-18';
  String description = '读取样本文档';
  Object? responseId;
  final callStarted = Completer<void>();
  final callCancelled = Completer<void>();
  Future<void> Function()? onList;
  Map<String, dynamic> result = {
    'content': [
      {'type': 'text', 'text': '样本文档：月相记录。'},
    ],
    'structuredContent': {'title': '月相记录', 'pages': 2},
  };

  McpServerProfile profile({bool bearer = false}) => McpServerProfile(
    id: 'server-1',
    name: '样本文档',
    endpoint: 'https://mcp.test/mcp',
    definitionRevision: 'revision-1',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    requiresBearer: bearer,
  );

  Map<String, dynamic> tool([String name = 'read_sample']) => {
    'name': name,
    'description': description,
    'inputSchema': {'type': 'object', 'properties': <String, dynamic>{}},
    'annotations': {'readOnlyHint': true},
  };

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (options.method == 'DELETE') {
      deletes++;
      return ResponseBody.fromString('', 204);
    }
    if (options.method == 'GET') {
      if (!listChanged) return ResponseBody.fromString('', 405);
      final stream = events = StreamController<Uint8List>();
      cancelFuture?.then((_) => stream.close());
      if (!eventsOpened.isCompleted) eventsOpened.complete();
      return ResponseBody(
        stream.stream,
        200,
        headers: {
          Headers.contentTypeHeader: ['text/event-stream'],
        },
      );
    }
    final frame = options.data is String
        ? jsonDecode(options.data as String) as Map<String, dynamic>
        : options.data as Map<String, dynamic>;
    messages.add(frame);
    if (status != null) {
      return ResponseBody.fromString('sensitive remote error', status!);
    }
    if (!frame.containsKey('method') ||
        (frame['method'] as String).startsWith('notifications/')) {
      return ResponseBody.fromString('', 202);
    }
    final Object data;
    switch (frame['method']) {
      case 'initialize':
        data = {
          'protocolVersion': version,
          'capabilities': {
            'tools': {'listChanged': listChanged},
          },
          'serverInfo': {'name': 'fixture', 'version': '1'},
        };
      case 'tools/list':
        await onList?.call();
        final cursor = (frame['params'] as Map)['cursor'];
        data = {
          'tools': [
            tool(cursor == null ? 'read_sample' : 'second_tool'),
            if (duplicate) tool(),
          ],
          if (paginate && (cursor == null || repeatCursor))
            'nextCursor': 'page-2',
        };
      case 'tools/call':
        calls++;
        if (!callStarted.isCompleted) callStarted.complete();
        if (hangCall) {
          final stream = StreamController<Uint8List>();
          cancelFuture?.then((_) {
            if (!callCancelled.isCompleted) callCancelled.complete();
            stream.close();
          });
          return ResponseBody(
            stream.stream,
            200,
            headers: {
              Headers.contentTypeHeader: ['text/event-stream'],
            },
          );
        }
        data = result;
      default:
        data = <String, dynamic>{};
    }
    final envelope = {
      'jsonrpc': '2.0',
      'id': responseId ?? frame['id'],
      'result': data,
    };
    final isSse = sse && frame['method'] == 'tools/call';
    final text = isSse
        ? 'data: ${const JsonEncoder.withIndent(' ').convert(envelope).replaceAll('\n', '\ndata: ')}\n\n'
        : jsonEncode(envelope);
    final bytes = utf8.encode(text);
    final chunkSize = bytes.length > 64 * 1024 ? 8192 : 7;
    return ResponseBody(
      Stream.fromIterable([
        for (var offset = 0; offset < bytes.length; offset += chunkSize)
          Uint8List.fromList(
            bytes.sublist(offset, (offset + chunkSize).clamp(0, bytes.length)),
          ),
      ]),
      200,
      headers: {
        Headers.contentTypeHeader: [
          isSse ? 'text/event-stream' : 'application/json',
        ],
        if (frame['method'] == 'initialize') 'mcp-session-id': ['test-session'],
      },
    );
  }

  @override
  void close({bool force = false}) {
    closed = true;
  }
}
