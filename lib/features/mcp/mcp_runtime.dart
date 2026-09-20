import '../../../core/error/failure.dart';
import '../../../data/models/agent_run.dart';
import '../../../data/models/mcp_server_profile.dart';
import '../../../data/models/tool_policy.dart';
import '../../../data/models/tool_source.dart';
import '../../../data/repositories/assistant_repository.dart';
import '../../../data/repositories/mcp_server_repository.dart';
import '../tools/tool.dart';
import 'mcp_client.dart';
import 'mcp_connections.dart';
import 'mcp_tool.dart';

/// 连接只属于本次运行；持久化快照不保存网络 session ID 或凭据。
class McpRunRuntime {
  McpRunRuntime({
    required this.run,
    required this.repository,
    required this.assistants,
    required this.connections,
  });
  final McpConnections connections;
  final AgentRun run;
  final McpServerRepository repository;
  final AssistantRepository assistants;
  final Map<String, McpClient> _clients = {};
  bool _closed = false;

  List<Tool> tools() => [
    for (final snapshot in run.configuration.toolSnapshots)
      if (snapshot.source.kind == ToolSourceKind.mcp)
        McpTool(
          definition: snapshot,
          serverName: run.configuration.mcpServers
              .where((p) => p.id == snapshot.source.id)
              .first
              .name,
          supportsImages: run.configuration.supportsImages,
          invoke: (arguments, cancellation, context) async {
            await checkAvailable(snapshot);
            var client = _clients[snapshot.source.id];
            if (client == null) {
              final profile = run.configuration.mcpServers
                  .where((p) => p.id == snapshot.source.id)
                  .first;
              // stdio 不使用 HTTP 头与 Bearer；敏感环境变量在此解析为进程环境。
              final bearer = profile.transport == McpTransport.streamableHttp
                  ? await repository.readBearer(profile)
                  : null;
              final headers = profile.transport == McpTransport.streamableHttp
                  ? await repository.readHeaders(profile)
                  : const <String, String>{};
              final secrets = profile.command == null
                  ? const <String, String>{}
                  : await repository.readEnvironmentSecrets(profile);
              final environment = {
                ...?profile.command?.environment,
                ...secrets,
              };
              cancellation.throwIfCancelled();
              if (_closed) throw const ToolCancelled();
              client = await connections.create(
                profile,
                bearer: bearer,
                headers: headers,
                environment: environment,
              );
              if (_closed || cancellation.isCancelled) {
                await connections.release(client);
                throw const ToolCancelled();
              }
              _clients[profile.id] = client;
              await client.connect(cancellation);
            }
            return client.callTool(
              snapshot,
              arguments,
              cancellation,
              beforeDispatch: () async {
                await checkAvailable(snapshot);
                final policy = await currentPolicy(snapshot);
                if (policy == ToolPolicy.deny ||
                    (!context.confirmed && policy == ToolPolicy.ask)) {
                  throw const McpFailure('policyChanged', '工具权限已收紧，本次调用未派发');
                }
              },
            );
          },
        ),
  ];

  Future<void> checkAvailable(ToolSnapshot snapshot) async {
    if (_closed) throw const ToolCancelled();
    final entry = await repository.get(snapshot.source.id);
    if (entry == null || !entry.profile.enabled || entry.profile.deleting) {
      throw const McpFailure('sourceDisabled', 'MCP 服务已禁用或删除，本次调用未派发');
    }
    // 编辑连接用于新运行；当前目录仅在同一连接修订内做撤销检查。
    final fixed = run.configuration.mcpServers
        .where((p) => p.id == snapshot.source.id)
        .first;
    if (entry.profile.definitionRevision == fixed.definitionRevision) {
      final current = entry.tools
          .where((t) => t.name == snapshot.name)
          .firstOrNull;
      if (current?.source.definitionRevision !=
          snapshot.source.definitionRevision) {
        throw const McpFailure('definitionChanged', 'MCP 工具定义已变化，请开始新任务');
      }
    }
  }

  Future<ToolPolicy> currentPolicy(ToolSnapshot snapshot) async {
    final id = run.assistantId;
    if (id == null) return ToolPolicy.deny;
    try {
      final assistant = await assistants.getById(id);
      return assistant?.toolPolicy.policies[snapshot.name] ?? ToolPolicy.deny;
    } on StorageFailure {
      rethrow;
    } on Object catch (error) {
      throw StorageFailure('读取助手工具权限失败', cause: error);
    }
  }

  Future<void> close() async {
    _closed = true;
    await Future.wait(_clients.values.map(connections.release));
    _clients.clear();
  }
}
