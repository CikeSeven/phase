import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/error/failure.dart';
import 'package:phase/data/models/tool_source.dart';
import 'package:phase/features/mcp/mcp_client.dart';
import 'package:phase/features/tools/tool.dart';

import 'mcp_test_server.dart';

void main() {
  late McpTestServer server;
  late McpClient client;
  setUp(() async {
    server = await McpTestServer.start();
    client = McpClient(server.profile(), bearer: null);
  });
  tearDown(() async {
    await client.close();
    await server.close();
  });

  test('初始化协商、分页、会话头、只读声明不授予权限、关闭', () async {
    server.paginate = true;
    final tools = await client.connect(RunCancellation());
    expect(tools.map((t) => t.source.originalName), [
      'read_sample',
      'second_tool',
    ]);
    expect(tools.first.source.effectClass, ToolEffectClass.unknown);
    expect(server.calls, 0);
    expect(server.requests.first['params']['capabilities'], isEmpty);
    expect(server.protocolHeaders.skip(1), everyElement('2025-06-18'));
    expect(server.sessionHeaders.skip(1), everyElement('test-session'));
    await client.close();
    expect(server.closed, 1);
  });

  for (final mode in ['json', 'sse']) {
    test('$mode 原始 HTTP 响应与 UTF-8 分片正确回填', () async {
      server.mode = mode;
      final tools = await client.connect(RunCancellation());
      final result = await client.callTool(
        tools.first,
        {},
        RunCancellation(),
        beforeDispatch: () async {},
      );
      expect(result['structuredContent']['title'], '月相记录');
      expect(result['content'][0]['text'], contains('样本文档'));
      expect(server.calls, 1);
      expect(server.requests.last['params']['name'], 'read_sample');
    });
  }

  for (final mode in ['pending', 'idle']) {
    test('停止 $mode 中断真实请求，发送取消通知，不重发调用', () async {
      final tools = await client.connect(RunCancellation());
      server.mode = mode;
      final cancel = RunCancellation();
      final call = client.callTool(
        tools.first,
        {},
        cancel,
        beforeDispatch: () async {},
      );
      final assertion = expectLater(call, throwsA(isA<ToolCancelled>()));
      await server.callArrived.future;
      cancel.cancel();
      await assertion.timeout(const Duration(seconds: 1));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(server.calls, 1);
      expect(
        server.requests.where((r) => r['method'] == 'notifications/cancelled'),
        hasLength(1),
      );
    });
  }

  test('响应丢失明确失败且不重发', () async {
    final tools = await client.connect(RunCancellation());
    server.mode = 'drop';
    await expectLater(
      client.callTool(
        tools.first,
        {},
        RunCancellation(),
        beforeDispatch: () async {},
      ),
      throwsA(isA<McpFailure>()),
    );
    expect(server.calls, 1);
  });

  test('调用超时有界并取消空闲流', () async {
    await client.close();
    client = McpClient(server.profile(timeout: 1), bearer: null);
    final tools = await client.connect(RunCancellation());
    server.mode = 'idle';
    await expectLater(
      client.callTool(
        tools.first,
        {},
        RunCancellation(),
        beforeDispatch: () async {},
      ),
      throwsA(isA<McpFailure>().having((e) => e.code, 'code', 'timeout')),
    );
    expect(server.calls, 1);
  });

  test('schema/说明修订变化阻止已确认调用', () async {
    final tools = await client.connect(RunCancellation());
    server.description = '已变更的说明';
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
    expect(server.calls, 0);
  });

  test('tools/list_changed 与未实现的服务器请求', () async {
    server.listChanged = true;
    await client.connect(RunCancellation());
    await server.eventsOpened.future;
    await server.notifyChanged();
    for (var i = 0; i < 50 && client.catalogGeneration == 0; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(
      client.catalogGeneration,
      1,
      reason: 'connection state: ${client.state}',
    );
    server.events!.write(
      'data: {"jsonrpc":"2.0","id":"server-request","method":"sampling/createMessage","params":{}}\n\n',
    );
    await server.events!.flush();
    for (
      var i = 0;
      i < 50 && !server.requests.any((r) => r['id'] == 'server-request');
      i++
    ) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(server.requests.last['error']['code'], -32601);
  });

  test('鉴权失效没有业务派发，安全错误不含凭据', () async {
    server.requiredBearer = 'test-only-secret';
    await expectLater(
      client.connect(RunCancellation()),
      throwsA(
        isA<McpFailure>()
            .having((e) => e.code, 'code', 'authentication')
            .having(
              (e) => e.userMessage,
              'message',
              isNot(contains('test-only-secret')),
            ),
      ),
    );
    expect(server.calls, 0);
  });

  test('重复工具名与重复分页游标明确失败', () async {
    server.duplicate = true;
    await expectLater(
      client.connect(RunCancellation()),
      throwsA(isA<McpFailure>().having((e) => e.code, 'code', 'nameCollision')),
    );
    await client.close();
    client = McpClient(server.profile(), bearer: null);
    server.duplicate = false;
    server.paginate = true;
    server.repeatCursor = true;
    await expectLater(
      client.connect(RunCancellation()),
      throwsA(
        isA<McpFailure>().having((e) => e.code, 'code', 'invalidPagination'),
      ),
    );
  });
}
