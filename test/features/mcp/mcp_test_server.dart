import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:phase/data/models/mcp_server_profile.dart';

/// 可控的真实 HTTP 服务；断连/空闲 SSE 使用 socket 而非假 Tool 流。
class McpTestServer {
  McpTestServer._(this.server);
  final HttpServer server;
  final requests = <Map<String, dynamic>>[];
  final authorizations = <String?>[];
  final protocolHeaders = <String?>[];
  final sessionHeaders = <String?>[];
  final pending = <HttpResponse>[];
  final callArrived = Completer<void>();
  final eventsOpened = Completer<void>();
  HttpResponse? events;
  String mode = 'json';
  String? requiredBearer;
  bool listChanged = false;
  bool paginate = false;
  bool duplicate = false;
  bool repeatCursor = false;
  int calls = 0;
  int closed = 0;
  String description = '读取样本文档';
  Map<String, dynamic>? result;

  static Future<McpTestServer> start() async {
    final fixture = McpTestServer._(
      await HttpServer.bind(InternetAddress.loopbackIPv4, 0),
    );
    fixture.server.listen(
      (request) => fixture._handle(request).catchError((Object _) {}),
    );
    return fixture;
  }

  McpServerProfile profile({
    String id = 'server-1',
    bool bearer = false,
    int timeout = 3,
  }) => McpServerProfile(
    id: id,
    name: '样本文档',
    endpoint: 'http://127.0.0.1:${server.port}/mcp',
    definitionRevision: 'revision-1',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    requiresBearer: bearer,
    credentialRef: id,
    callTimeoutSeconds: timeout,
  );

  Map<String, dynamic> tool([String name = 'read_sample']) => {
    'name': name,
    'description': description,
    'inputSchema': {'type': 'object', 'properties': <String, dynamic>{}},
    'annotations': {'readOnlyHint': true},
  };

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    if (request.method == 'DELETE') {
      closed++;
      response.statusCode = 204;
      await response.close();
      return;
    }
    if (request.method == 'GET') {
      if (!listChanged) {
        response.statusCode = 405;
        await response.close();
      } else {
        events = response;
        pending.add(response);
        response.bufferOutput = false;
        response.headers.contentType = ContentType('text', 'event-stream');
        response.write(': ready\n\n');
        await response.flush();
        if (!eventsOpened.isCompleted) eventsOpened.complete();
      }
      return;
    }
    final frame = jsonDecode(
      await utf8.decoder.bind(request).join(),
    ) as Map<String, dynamic>;
    requests.add(frame);
    authorizations.add(request.headers.value('authorization'));
    protocolHeaders.add(request.headers.value('mcp-protocol-version'));
    sessionHeaders.add(request.headers.value('mcp-session-id'));
    if (requiredBearer != null &&
        request.headers.value('authorization') != 'Bearer $requiredBearer') {
      response.statusCode = 401;
      await response.close();
      return;
    }
    final method = frame['method'];
    if (method == 'notifications/initialized' ||
        method == 'notifications/cancelled' ||
        method == null) {
      response.statusCode = 202;
      await response.close();
      return;
    }
    Object data;
    switch (method) {
      case 'initialize':
        response.headers.set('Mcp-Session-Id', 'test-session');
        data = {
          'protocolVersion': '2025-06-18',
          'capabilities': {
            'tools': {'listChanged': listChanged},
          },
          'serverInfo': {'name': 'fixture', 'version': '1'},
        };
      case 'tools/list':
        final cursor = (frame['params'] as Map?)?['cursor'];
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
        if (!callArrived.isCompleted) callArrived.complete();
        if (mode == 'drop') {
          (await response.detachSocket()).destroy();
          return;
        }
        if (mode == 'pending' || mode == 'idle') {
          pending.add(response);
          if (mode == 'idle') {
            response.headers.contentType = ContentType('text', 'event-stream');
            response.write(': idle\n\n');
            await response.flush();
          }
          return;
        }
        data =
            result ??
            {
              'content': [
                {'type': 'text', 'text': '样本文档：月相记录。'},
              ],
              'structuredContent': {'title': '月相记录', 'pages': 2},
            };
      default:
        data = <String, dynamic>{};
    }
    final envelope = {'jsonrpc': '2.0', 'id': frame['id'], 'result': data};
    if (mode == 'sse' && method == 'tools/call') {
      response.headers.contentType = ContentType(
        'text',
        'event-stream',
        charset: 'utf-8',
      );
      final text =
          'data: ${const JsonEncoder.withIndent(' ').convert(envelope).replaceAll('\n', '\ndata: ')}\n\n';
      final bytes = utf8.encode(text);
      for (var offset = 0; offset < bytes.length; offset += 7) {
        response.add(
          bytes.sublist(offset, (offset + 7).clamp(0, bytes.length)),
        );
        await response.flush();
      }
    } else {
      response.headers.contentType = ContentType.json;
      response.write(jsonEncode(envelope));
    }
    await response.close();
  }

  Future<void> notifyChanged() async {
    events!.write(
      'data: ${jsonEncode({'jsonrpc': '2.0', 'method': 'notifications/tools/list_changed'})}\n\n',
    );
    await events!.flush();
  }

  Future<void> close() async {
    for (final response in pending) {
      response.close().ignore();
    }
    await server.close(force: true);
  }
}
