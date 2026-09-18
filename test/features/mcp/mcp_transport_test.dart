import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/error/failure.dart';
import 'package:phase/data/models/mcp_server_profile.dart';
import 'package:phase/data/models/tool_source.dart';
import 'package:phase/features/mcp/mcp_client.dart';
import 'package:phase/features/mcp/mcp_tool.dart';
import 'package:phase/features/tools/tool.dart';

import 'mcp_memory_transport.dart';

void main() {
  late McpMemoryTransport adapter;
  late McpClient client;
  setUp(() {
    adapter = McpMemoryTransport();
    client = McpClient(
      adapter.profile(),
      bearer: null,
      dio: Dio()..httpClientAdapter = adapter,
    );
  });
  tearDown(() => client.close());

  for (final sse in [true, false]) {
    test('JSON/SSE $sse 分片、分页、来源和会话协商', () async {
      adapter.sse = sse;
      adapter.paginate = true;
      final tools = await client.connect(RunCancellation());
      expect(tools, hasLength(2));
      expect(tools.first.source.effectClass, ToolEffectClass.unknown);
      expect(adapter.calls, 0);
      final result = await client.callTool(
        tools.first,
        {},
        RunCancellation(),
        beforeDispatch: () async {},
      );
      expect(result['structuredContent']['title'], '月相记录');
      expect(adapter.calls, 1);
      expect(adapter.requests.last.headers['Mcp-Session-Id'], 'test-session');
      expect(
        adapter.requests.last.headers['MCP-Protocol-Version'],
        '2025-06-18',
      );
      await client.close();
      expect(adapter.deletes, 1);
      expect(adapter.closed, isTrue);
    });
  }

  test('模型别名不碰撞，修订不受对象键顺序影响且覆盖定义', () {
    expect(
      mcpToolName('server-1', '中文/工具'),
      isNot(mcpToolName('server-2', '中文/工具')),
    );
    expect(
      mcpToolName('server-1', 'a-b'),
      isNot(mcpToolName('server-1', 'a b')),
    );
    expect(mcpToolName('server-1', '长' * 200).length, lessThanOrEqualTo(64));
    final a = mcpToolSnapshot(adapter.profile(), adapter.tool());
    final reordered = Map<String, dynamic>.fromEntries(
      adapter.tool().entries.toList().reversed,
    );
    expect(
      mcpToolSnapshot(adapter.profile(), reordered).source.definitionRevision,
      a.source.definitionRevision,
    );
    expect(() => a.inputSchema['type'] = 'array', throwsUnsupportedError);
    final tool = McpTool(definition: a, serverName: '测试');
    expect(() => ToolRegistry([tool, tool]), throwsArgumentError);
  });

  test('目录变化和派发前撤权不执行 tools/call', () async {
    final tools = await client.connect(RunCancellation());
    adapter.description = '变更后的工具';
    await expectLater(
      client.callTool(
        tools.first,
        {},
        RunCancellation(),
        beforeDispatch: () async {},
      ),
      throwsA(
        isA<McpFailure>().having((e) => e.code, 'code', 'definitionChanged'),
      ),
    );
    adapter.description = '读取样本文档';
    await expectLater(
      client.callTool(
        tools.first,
        {},
        RunCancellation(),
        beforeDispatch: () async {
          throw const McpFailure('sourceDisabled', '服务已禁用');
        },
      ),
      throwsA(
        isA<McpFailure>().having((e) => e.code, 'code', 'sourceDisabled'),
      ),
    );
    expect(adapter.calls, 0);
  });

  test('取消传到 transport token，保持一次业务派发', () async {
    final tools = await client.connect(RunCancellation());
    adapter.hangCall = true;
    final cancellation = RunCancellation();
    final call = client.callTool(
      tools.first,
      {},
      cancellation,
      beforeDispatch: () async {},
    );
    final check = expectLater(call, throwsA(isA<ToolCancelled>()));
    await adapter.callStarted.future;
    cancellation.cancel();
    await check;
    await adapter.callCancelled.future.timeout(const Duration(seconds: 1));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(adapter.calls, 1);
    expect(
      adapter.messages.any((m) => m['method'] == 'notifications/cancelled'),
      isTrue,
    );
  });

  test('鉴权、协议版本和响应 ID 的失败都不会伪装成功', () async {
    adapter.status = 401;
    await expectLater(
      client.connect(RunCancellation()),
      throwsA(
        isA<McpFailure>()
            .having((e) => e.code, 'code', 'authentication')
            .having((e) => e.message, 'message', isNot(contains('sensitive'))),
      ),
    );
    await client.close();
    adapter.status = null;
    adapter.version = 'unsupported';
    client = McpClient(
      adapter.profile(),
      bearer: null,
      dio: Dio()..httpClientAdapter = adapter,
    );
    await expectLater(
      client.connect(RunCancellation()),
      throwsA(
        isA<McpFailure>().having((e) => e.code, 'code', 'protocolVersion'),
      ),
    );
    await client.close();
    adapter.version = '2025-06-18';
    adapter.responseId = 'wrong-id';
    client = McpClient(
      adapter.profile(),
      bearer: null,
      dio: Dio()..httpClientAdapter = adapter,
    );
    await expectLater(
      client.connect(RunCancellation()),
      throwsA(isA<McpFailure>().having((e) => e.code, 'code', 'responseId')),
    );
  });

  test('重复工具或分页不进行无界注册', () async {
    adapter.duplicate = true;
    await expectLater(
      client.connect(RunCancellation()),
      throwsA(isA<McpFailure>().having((e) => e.code, 'code', 'nameCollision')),
    );
    await client.close();
    adapter.duplicate = false;
    adapter.paginate = true;
    adapter.repeatCursor = true;
    client = McpClient(
      adapter.profile(),
      bearer: null,
      dio: Dio()..httpClientAdapter = adapter,
    );
    await expectLater(
      client.connect(RunCancellation()),
      throwsA(
        isA<McpFailure>().having((e) => e.code, 'code', 'invalidPagination'),
      ),
    );
  });

  test('快照序列化只保存凭据引用', () {
    final profile = adapter
        .profile(bearer: true)
        .copyWith(credentialRef: 'opaque-ref');
    final encoded = jsonEncode(profile.toJson());
    expect(
      McpServerProfile.fromJson(jsonDecode(encoded)).credentialRef,
      'opaque-ref',
    );
    expect(encoded, isNot(contains('Authorization')));
  });
  test('事件流接收目录变化，未实现的服务端请求返回不支持，关闭回收读流', () async {
    adapter.listChanged = true;
    await client.connect(RunCancellation());
    await adapter.eventsOpened.future;
    adapter.events!.add(
      Uint8List.fromList(
        utf8.encode(
          'data: {"jsonrpc":"2.0","method":"notifications/tools/list_changed"}\n\n'
          'data: {"jsonrpc":"2.0","id":"server-call","method":"sampling/createMessage","params":{}}\n\n',
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(client.catalogGeneration, 1);
    expect(adapter.messages.last['error']['code'], -32601);
    await client.close().timeout(const Duration(seconds: 1));
    expect(adapter.events!.isClosed, isTrue);
  });

  test('响应超过上限明确失败，工具只派发一次', () async {
    adapter.sse = false;
    adapter.result = {
      'content': [
        {'type': 'text', 'text': 'x' * (McpLimits.responseBytes + 1)},
      ],
    };
    final tools = await client.connect(RunCancellation());
    await expectLater(
      client.callTool(
        tools.first,
        {},
        RunCancellation(),
        beforeDispatch: () async {},
      ),
      throwsA(isA<McpFailure>().having((e) => e.code, 'code', 'responseLimit')),
    );
    expect(adapter.calls, 1);
  });
}
