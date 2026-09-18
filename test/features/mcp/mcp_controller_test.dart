import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase/data/repositories/mcp_server_repository.dart';
import 'package:phase/features/mcp/mcp_client.dart';
import 'package:phase/features/mcp/mcp_connections.dart';
import 'package:phase/features/mcp/mcp_controller.dart';

import '../tools/tool_loop_harness.dart';
import 'mcp_memory_transport.dart';

void main() {
  test('连接检查只发现工具，退出后关闭连接，禁用后配置持久化', () async {
    final transport = McpMemoryTransport();
    final connections = McpConnections(
      createClient: (profile, bearer, headers) => McpClient(
        profile,
        bearer: bearer,
        headers: headers,
        dio: Dio()..httpClientAdapter = transport,
      ),
    );
    addTearDown(connections.close);
    final h = await ToolLoopHarness.create(mcpConnections: connections);
    final repository = await h.container.read(
      mcpServerRepositoryProvider.future,
    );
    final saved = await repository.save(transport.profile());
    final subscription = h.container.listen(
      mcpControllerProvider(saved.id),
      (_, _) {},
    );
    addTearDown(subscription.close);
    await h.container.read(mcpControllerProvider(saved.id).future);
    final controller = h.container.read(
      mcpControllerProvider(saved.id).notifier,
    );
    await controller.check();
    expect(transport.calls, 0);
    expect(transport.deletes, 1);
    expect((await repository.get(saved.id))!.tools, hasLength(1));
    await controller.save(saved.copyWith(enabled: false));
    expect((await repository.get(saved.id))!.profile.enabled, isFalse);
    await controller.delete();
    expect(await repository.get(saved.id), isNull);
  });
}
