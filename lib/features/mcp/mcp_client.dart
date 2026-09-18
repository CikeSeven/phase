import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/error/failure.dart';
import '../../../data/models/mcp_server_profile.dart';
import '../../../data/models/tool_source.dart';
import '../tools/tool.dart';

class McpLimits {
  static const responseBytes = 8 * 1024 * 1024;
  static const previewBytes = 6 * 1024;
  static const catalogTools = 1000;
  static const catalogPages = 100;
}

enum McpConnectionState { disconnected, connecting, ready, failed, closing }

/// 远程 Streamable HTTP。每个运行独立持有会话，不重放请求、不跟随重定向。
class McpClient {
  McpClient(
    this.profile, {
    required String? bearer,
    Map<String, String> headers = const {},
    Dio? dio,
  }) : _customHeaders = Map.unmodifiable(headers),
       _authorization = bearer == null || bearer.isEmpty
           ? null
           : 'Bearer $bearer',
       _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: Duration(seconds: profile.connectTimeoutSeconds),
             ),
           );

  static const supportedVersions = ['2025-06-18', '2025-03-26'];
  final McpServerProfile profile;
  final String? _authorization;
  final Map<String, String> _customHeaders;
  final Dio _dio;
  final Set<CancelToken> _requests = {};
  McpConnectionState state = McpConnectionState.disconnected;
  String? protocolVersion;
  String? _sessionId;
  int _nextId = 0;
  int catalogGeneration = 0;
  Future<void>? _eventStream;
  Future<void>? _closing;

  Map<String, String> get _headers => {
    ..._customHeaders,
    'Accept': 'application/json, text/event-stream',
    'Content-Type': 'application/json',
    if (profile.requiresBearer) 'Authorization': ?_authorization,
    'Mcp-Session-Id': ?_sessionId,
    'MCP-Protocol-Version': ?protocolVersion,
  };

  Future<List<ToolSnapshot>> connect(RunCancellation cancellation) async {
    profile.validate();
    if (state != McpConnectionState.disconnected) {
      throw const McpFailure('connectionState', 'MCP 连接已结束，请重新检查连接');
    }
    if (profile.requiresBearer && _authorization == null) {
      throw const McpFailure('authentication', 'MCP 服务缺少 Bearer 凭据，请编辑服务配置');
    }
    state = McpConnectionState.connecting;
    try {
      final result = await _rpc(
        'initialize',
        {
          'protocolVersion': supportedVersions.first,
          'capabilities': <String, dynamic>{},
          'clientInfo': {'name': 'xiangyue', 'version': '1.0.0'},
        },
        cancellation,
        timeout: Duration(seconds: profile.connectTimeoutSeconds),
      );
      final version = result['protocolVersion'];
      if (version is! String || !supportedVersions.contains(version)) {
        throw const McpFailure('protocolVersion', 'MCP 服务选择了当前不支持的协议版本');
      }
      protocolVersion = version;
      final capabilities = result['capabilities'];
      if (capabilities is! Map || capabilities['tools'] is! Map) {
        throw const McpFailure('toolsUnsupported', 'MCP 服务没有声明工具能力');
      }
      await _send({
        'jsonrpc': '2.0',
        'method': 'notifications/initialized',
      }, cancellation);
      state = McpConnectionState.ready;
      final tools = await listTools(cancellation);
      if (capabilities['tools']['listChanged'] == true) {
        _eventStream = _listenEvents();
      }
      return tools;
    } catch (_) {
      if (state != McpConnectionState.closing) {
        state = McpConnectionState.failed;
      }
      rethrow;
    }
  }

  Future<List<ToolSnapshot>> listTools(RunCancellation cancellation) async {
    final tools = <ToolSnapshot>[];
    final names = <String>{};
    final cursors = <String>{};
    String? cursor;
    var bytes = 0;
    for (var page = 0; page < McpLimits.catalogPages; page++) {
      final result = await _rpc('tools/list', {
        'cursor': ?cursor,
      }, cancellation);
      bytes += utf8.encode(jsonEncode(result)).length;
      if (bytes > McpLimits.responseBytes || result['tools'] is! List) {
        throw const McpFailure('catalogLimit', 'MCP 工具目录过大或格式无效');
      }
      for (final raw in result['tools'] as List) {
        if (raw is! Map<String, dynamic>) {
          throw const McpFailure('invalidDefinition', 'MCP 返回了无效的工具定义');
        }
        final tool = mcpToolSnapshot(profile, raw);
        if (!names.add(tool.name)) {
          throw const McpFailure('nameCollision', 'MCP 工具名称重复，无法安全注册');
        }
        tools.add(tool);
        if (tools.length > McpLimits.catalogTools) {
          throw const McpFailure('catalogLimit', 'MCP 工具数量超过上限');
        }
      }
      if (result['nextCursor'] != null && result['nextCursor'] is! String) {
        throw const McpFailure('invalidPagination', 'MCP 工具目录的分页游标无效');
      }
      cursor = result['nextCursor'] as String?;
      if (cursor == null) return List.unmodifiable(tools);
      if (!cursors.add(cursor)) {
        throw const McpFailure('invalidPagination', 'MCP 工具目录的分页游标重复');
      }
    }
    throw const McpFailure('catalogLimit', 'MCP 工具目录分页超过上限');
  }

  Future<Map<String, dynamic>> callTool(
    ToolSnapshot snapshot,
    Map<String, dynamic> arguments,
    RunCancellation cancellation, {
    required Future<void> Function() beforeDispatch,
  }) async {
    // 每次派发前验证目录，通知不能成为唯一的定义变化检查。
    final generation = catalogGeneration;
    final tools = await listTools(cancellation);
    final current = tools
        .where((tool) => tool.name == snapshot.name)
        .firstOrNull;
    if (current?.source.definitionRevision !=
            snapshot.source.definitionRevision ||
        generation != catalogGeneration) {
      throw const McpFailure('definitionChanged', 'MCP 工具定义已变化，请重新检查连接后开始新任务');
    }
    await beforeDispatch();
    cancellation.throwIfCancelled();
    if (generation != catalogGeneration) {
      throw const McpFailure('definitionChanged', 'MCP 工具目录已变化，本次调用未派发');
    }
    return _rpc('tools/call', {
      'name': snapshot.source.originalName,
      'arguments': arguments,
    }, cancellation);
  }

  Future<Map<String, dynamic>> _rpc(
    String method,
    Map<String, dynamic> params,
    RunCancellation cancellation, {
    Duration? timeout,
  }) async {
    if (state == McpConnectionState.failed ||
        state == McpConnectionState.closing ||
        (state == McpConnectionState.disconnected && method != 'initialize')) {
      throw const McpFailure('disconnected', 'MCP 连接已断开，本次调用没有完整响应');
    }
    final id = ++_nextId;
    return (await _exchange(
      'POST',
      {'jsonrpc': '2.0', 'id': id, 'method': method, 'params': params},
      cancellation,
      expectedId: id,
      timeout: timeout,
    ))!;
  }

  Future<void> _send(
    Map<String, dynamic> message,
    RunCancellation cancellation,
  ) async {
    await _exchange(
      'POST',
      message,
      cancellation,
      timeout: const Duration(seconds: 2),
    );
  }

  Future<Map<String, dynamic>?> _exchange(
    String method,
    Map<String, dynamic>? payload,
    RunCancellation cancellation, {
    int? expectedId,
    Duration? timeout,
    bool events = false,
  }) async {
    cancellation.throwIfCancelled();
    final token = CancelToken();
    _requests.add(token);
    final aborted = Completer<Map<String, dynamic>?>();
    var active = true;
    void abort(Object error) {
      if (!active || aborted.isCompleted) return;
      aborted.completeError(error);
      token.cancel();
    }

    cancellation.whenCancelled.then((_) {
      if (!active) return;
      if (expectedId != null && payload?['method'] != 'initialize') {
        _send({
          'jsonrpc': '2.0',
          'method': 'notifications/cancelled',
          'params': {'requestId': expectedId, 'reason': 'Cancelled'},
        }, RunCancellation()).ignore();
      }
      abort(const ToolCancelled());
    }).ignore();
    final timer = events
        ? null
        : Timer(timeout ?? Duration(seconds: profile.callTimeoutSeconds), () {
            if (expectedId != null && payload?['method'] != 'initialize') {
              _send({
                'jsonrpc': '2.0',
                'method': 'notifications/cancelled',
                'params': {'requestId': expectedId, 'reason': 'Timeout'},
              }, RunCancellation()).ignore();
            }
            abort(const McpFailure('timeout', 'MCP 请求超时；已派发的操作不会自动重发'));
          });
    try {
      return await Future.any([
        _readExchange(method, payload, token, expectedId, events),
        aborted.future,
      ]);
    } on ToolCancelled {
      rethrow;
    } on McpFailure {
      rethrow;
    } on DioException catch (error) {
      if (cancellation.isCancelled) throw const ToolCancelled();
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout) {
        throw const McpFailure('timeout', 'MCP 请求超时；已派发的操作不会自动重发');
      }
      throw const McpFailure(
        'connectionLost',
        'MCP 连接中断，没有收到完整响应；已派发的操作不会自动重发',
      );
    } on Object {
      throw const McpFailure('invalidResponse', 'MCP 响应格式无效');
    } finally {
      active = false;
      timer?.cancel();
      token.cancel();
      _requests.remove(token);
    }
  }

  Future<Map<String, dynamic>?> _readExchange(
    String method,
    Map<String, dynamic>? payload,
    CancelToken token,
    int? expectedId,
    bool events,
  ) async {
    final response = await _dio.request<ResponseBody>(
      profile.endpoint,
      data: payload == null ? null : jsonEncode(payload),
      cancelToken: token,
      options: Options(
        method: method,
        headers: _headers,
        responseType: ResponseType.stream,
        followRedirects: false,
        validateStatus: (_) => true,
        sendTimeout: Duration(seconds: profile.connectTimeoutSeconds),
      ),
    );
    final status = response.statusCode ?? 0;
    if (events && status == 405) return null;
    if (method == 'DELETE' && [200, 202, 204, 404, 405].contains(status)) {
      return null;
    }
    if (status == 401 || status == 403) {
      throw const McpFailure('authentication', 'MCP 鉴权失败，请检查服务凭据');
    }
    if (status < 200 || status >= 300) {
      throw McpFailure('http$status', 'MCP 服务返回 HTTP $status；本次请求不会自动重发');
    }
    if (payload?['method'] == 'initialize') {
      final session = response.headers.value('mcp-session-id');
      if (session != null &&
          (session.isEmpty || !RegExp(r'^[\x21-\x7E]+$').hasMatch(session))) {
        throw const McpFailure('invalidSession', 'MCP 返回了无效的会话标识');
      }
      _sessionId = session;
    }
    if (expectedId == null && !events) {
      if (status != 202 && status != 204) {
        throw const McpFailure('invalidAcknowledgement', 'MCP 通知未被正确接受');
      }
      return null;
    }
    final body = response.data;
    if (body == null) throw const McpFailure('emptyResponse', 'MCP 响应为空');
    final contentType = response.headers
        .value('content-type')
        ?.split(';')
        .first
        .trim();
    if (contentType == 'text/event-stream') {
      await for (final data in _sse(body.stream, totalBound: !events)) {
        final frame = _frame(data);
        final result = await _handleFrame(frame, expectedId);
        if (result != null) return result;
      }
    } else if (!events && contentType == 'application/json') {
      final bytes = <int>[];
      await for (final chunk in body.stream) {
        if (bytes.length + chunk.length > McpLimits.responseBytes) {
          throw const McpFailure('responseLimit', 'MCP 响应超过 8 MiB 上限，读取已停止');
        }
        bytes.addAll(chunk);
      }
      final result = await _handleFrame(_frame(utf8.decode(bytes)), expectedId);
      if (result != null) return result;
    } else {
      throw const McpFailure('contentType', 'MCP 返回了不支持的响应类型');
    }
    throw const McpFailure('responseLost', 'MCP 响应流在结果返回前结束；已派发的操作不会自动重发');
  }

  Map<String, dynamic> _frame(String data) {
    final value = jsonDecode(data);
    if (value is! Map<String, dynamic> || value['jsonrpc'] != '2.0') {
      throw const McpFailure('invalidResponse', 'MCP 返回了无效的 JSON-RPC 消息');
    }
    return value;
  }

  Future<Map<String, dynamic>?> _handleFrame(
    Map<String, dynamic> frame,
    int? expectedId,
  ) async {
    if (frame['method'] case final String method) {
      if (frame.containsKey('id')) {
        await _send({
          'jsonrpc': '2.0',
          'id': frame['id'],
          if (method == 'ping')
            'result': <String, dynamic>{}
          else
            'error': {'code': -32601, 'message': 'Method not supported'},
        }, RunCancellation());
      } else if (method == 'notifications/tools/list_changed') {
        catalogGeneration++;
      }
      return null;
    }
    if (expectedId == null || frame['id'] != expectedId) {
      throw const McpFailure('responseId', 'MCP 响应标识与请求不一致');
    }
    if (frame.containsKey('error')) {
      throw const McpFailure('rpcError', 'MCP 服务拒绝了本次请求');
    }
    final result = frame['result'];
    if (result is! Map<String, dynamic>) {
      throw const McpFailure('invalidResult', 'MCP 返回了无效的结果');
    }
    return result;
  }

  Future<void> _listenEvents() async {
    try {
      await _exchange('GET', null, RunCancellation(), events: true);
    } on Object {
      if (state != McpConnectionState.closing) {
        state = McpConnectionState.failed;
        for (final request in _requests.toList()) {
          request.cancel();
        }
      }
    }
  }

  Future<void> close() => _closing ??= _close();

  Future<void> _close() async {
    state = McpConnectionState.closing;
    for (final request in _requests.toList()) {
      request.cancel();
    }
    if (_sessionId != null) {
      try {
        await _exchange(
          'DELETE',
          null,
          RunCancellation(),
          timeout: const Duration(seconds: 1),
        );
      } on Object {
        /* 关闭失败不改变已经保存的业务结果。 */
      }
    }
    _dio.close(force: true);
    await _eventStream;
    _sessionId = null;
    state = McpConnectionState.disconnected;
  }
}

/// 严格的 SSE 事件边界；按 UTF-8 增量解码，多行 data 合并。
Stream<String> _sse(
  Stream<List<int>> stream, {
  required bool totalBound,
}) async* {
  var eventBytes = 0;
  var totalBytes = 0;
  Stream<List<int>> bounded() async* {
    await for (final chunk in stream) {
      // 行解码器本身也受限，不能靠永不换行的数据无限占内存。
      eventBytes += chunk.length;
      totalBytes += chunk.length;
      if (eventBytes > McpLimits.responseBytes ||
          (totalBound && totalBytes > McpLimits.responseBytes)) {
        throw const McpFailure('responseLimit', 'MCP 响应事件超过 8 MiB 上限');
      }
      yield chunk;
    }
  }

  final lines = utf8.decoder.bind(bounded()).transform(const LineSplitter());
  final data = <String>[];
  await for (final line in lines) {
    if (line.isEmpty) {
      if (data.isNotEmpty) {
        yield data.join('\n');
        data.clear();
      }
      eventBytes = 0;
    } else if (line.startsWith('data:')) {
      final value = line.substring(5);
      data.add(value.startsWith(' ') ? value.substring(1) : value);
    }
  }
}
