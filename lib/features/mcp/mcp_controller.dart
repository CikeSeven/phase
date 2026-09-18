import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/error/failure.dart';
import '../../../data/models/mcp_server_profile.dart';
import '../../../data/repositories/mcp_server_repository.dart';
import '../tools/tool.dart';
import 'mcp_connections.dart';

part 'mcp_controller.g.dart';

@riverpod
class McpController extends _$McpController {
  RunCancellation? _cancellation;
  bool _working = false;

  @override
  Future<McpServerEntry?> build(String id) async {
    ref.onDispose(() => _cancellation?.cancel());
    return (await ref.watch(mcpServerRepositoryProvider.future)).get(id);
  }

  Future<void> save(
    McpServerProfile profile, {
    String? bearer,
    Map<String, String>? headers,
  }) => _operate(() async {
    final repository = await ref.read(mcpServerRepositoryProvider.future);
    final saved = await repository.save(
      profile,
      bearer: bearer,
      headers: headers,
    );
    if (!saved.enabled) await ref.read(mcpConnectionsProvider).closeServer(id);
    final entry = await repository.get(id);
    if (ref.mounted) state = AsyncData(entry);
  });

  Future<void> check() => _operate(() async {
    final repository = await ref.read(mcpServerRepositoryProvider.future);
    final entry = await repository.get(id);
    if (entry == null || entry.profile.deleting) {
      throw const OperationFailure('MCP 服务已不存在');
    }
    final connections = ref.read(mcpConnectionsProvider);
    final cancellation = RunCancellation();
    _cancellation = cancellation;
    final bearer = await repository.readBearer(entry.profile);
    final headers = await repository.readHeaders(entry.profile);
    cancellation.throwIfCancelled();
    final client = connections.create(entry.profile, bearer, headers);
    try {
      final tools = await client.connect(cancellation);
      cancellation.throwIfCancelled();
      await repository.saveCatalog(
        entry.profile,
        tools,
        client.protocolVersion!,
      );
      final current = await repository.get(id);
      if (ref.mounted) state = AsyncData(current);
    } finally {
      await connections.release(client);
      _cancellation = null;
    }
  });

  void cancelCheck() => _cancellation?.cancel();

  Future<void> delete() => _operate(() async {
    final repository = await ref.read(mcpServerRepositoryProvider.future);
    final entry = await repository.get(id);
    if (entry == null) return;
    if (!entry.profile.deleting) {
      await repository.save(entry.profile.copyWith(enabled: false));
    }
    await ref.read(mcpConnectionsProvider).closeServer(id);
    try {
      await repository.delete(id);
      if (ref.mounted) state = const AsyncData(null);
    } catch (_) {
      final pending = await repository.get(id);
      if (ref.mounted) state = AsyncData(pending);
      rethrow;
    }
  });

  Future<void> _operate(Future<void> Function() action) async {
    if (_working) throw const OperationFailure('请等待当前操作完成');
    _working = true;
    try {
      await action();
    } finally {
      _working = false;
    }
  }
}
