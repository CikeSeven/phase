import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/models/mcp_server_profile.dart';
import 'mcp_client.dart';

part 'mcp_connections.g.dart';

/// 仅管理活连接的清理归属，不跨运行共享协议状态。
class McpConnections {
  McpConnections({
    McpClient Function(McpServerProfile, String?, Map<String, String>)?
    createClient,
  }) : _createClient =
           createClient ??
           ((profile, bearer, headers) =>
               McpClient(profile, bearer: bearer, headers: headers));
  final McpClient Function(McpServerProfile, String?, Map<String, String>)
  _createClient;
  final Set<McpClient> _clients = {};

  McpClient create(
    McpServerProfile profile,
    String? bearer,
    Map<String, String> headers,
  ) {
    final client = _createClient(profile, bearer, headers);
    _clients.add(client);
    return client;
  }

  Future<void> release(McpClient client) async {
    await client.close();
    _clients.remove(client);
  }

  Future<void> closeServer(String id) async {
    await Future.wait([
      for (final client in _clients.toList())
        if (client.profile.id == id) release(client),
    ]);
  }

  Future<void> close() => Future.wait(_clients.toList().map(release));
}

@Riverpod(keepAlive: true)
McpConnections mcpConnections(Ref ref) {
  final connections = McpConnections();
  ref.onDispose(() => connections.close().ignore());
  return connections;
}
