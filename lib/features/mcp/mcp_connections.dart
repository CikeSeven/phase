import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/error/failure.dart';
import '../../data/models/mcp_server_profile.dart';
import '../../data/repositories/workspace_repository.dart';
import '../workspace/process_driver.dart';
import 'mcp_client.dart';
import 'mcp_stdio_client.dart';

part 'mcp_connections.g.dart';

/// stdio 服务的定位：环境 rootfs 与服务专属工作目录。
/// 目录不在数据库登记，删除服务时由控制器尽力清理。
/// 驱动与仓储都惰性获取，避免普通测试环境初始化平台通道。
class McpStdioLauncher {
  McpStdioLauncher({required this.openDriver, required this.openRepository});

  final ProcessDriver Function() openDriver;
  final Future<WorkspaceRepository> Function() openRepository;

  Future<McpStdioClient> create(
    McpServerProfile profile,
    Map<String, String> environment,
  ) async {
    final repository = await openRepository();
    final env = await repository.environment();
    if (!env.ready || env.rootPath == null) {
      throw const WorkspaceFailure('environmentMissing', '请先在设置中安装 Ubuntu 环境');
    }
    final directory = Directory(serverDirectory(repository, profile.id));
    if (!await directory.exists()) {
      try {
        await directory.create(recursive: true);
      } on FileSystemException {
        throw const OperationFailure('无法创建 MCP 服务目录，请检查可用空间');
      }
    }
    return McpStdioClient(
      profile,
      driver: openDriver(),
      rootfs: env.rootPath!,
      workspace: directory.path,
      environment: environment,
    );
  }

  static String serverDirectory(
    WorkspaceRepository repository,
    String serverId,
  ) => p.join(repository.root.path, 'workspaces', 'mcp', serverId);
}

/// 仅管理活连接的清理归属，不跨运行共享协议状态。
class McpConnections {
  McpConnections({
    McpClient Function(McpServerProfile, String?, Map<String, String>)?
    createClient,
    Future<McpStdioClient> Function(McpServerProfile, Map<String, String>)?
    createStdioClient,
    McpStdioLauncher? stdio,
  }) : _createClient =
           createClient ??
           ((profile, bearer, headers) =>
               McpHttpClient(profile, bearer: bearer, headers: headers)),
       _createStdioClient = createStdioClient ?? stdio?.create;
  final McpClient Function(McpServerProfile, String?, Map<String, String>)
  _createClient;
  final Future<McpStdioClient> Function(McpServerProfile, Map<String, String>)?
  _createStdioClient;
  final Set<McpClient> _clients = {};

  Future<McpClient> create(
    McpServerProfile profile, {
    String? bearer,
    Map<String, String> headers = const {},
    Map<String, String> environment = const {},
  }) async {
    final client = profile.transport == McpTransport.stdio
        ? await (_createStdioClient ?? _noStdioLauncher)(profile, environment)
        : _createClient(profile, bearer, headers);
    _clients.add(client);
    return client;
  }

  Future<McpStdioClient> _noStdioLauncher(
    McpServerProfile profile,
    Map<String, String> environment,
  ) async => throw const OperationFailure('此构建未提供本地 stdio 连接能力');

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
  final connections = McpConnections(
    stdio: McpStdioLauncher(
      openDriver: () => ref.read(processDriverProvider),
      openRepository: () => ref.read(workspaceRepositoryProvider.future),
    ),
  );
  ref.onDispose(() => connections.close().ignore());
  return connections;
}
