import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/error/failure.dart';
import '../../../core/utils/logger.dart';
import '../../../data/models/mcp_server_profile.dart';
import '../../../data/repositories/mcp_server_repository.dart';
import '../../../data/repositories/workspace_repository.dart';
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
    Map<String, String>? environmentSecrets,
  }) => _operate(() async {
    final repository = await ref.read(mcpServerRepositoryProvider.future);
    final saved = await repository.save(
      profile,
      bearer: bearer,
      headers: headers,
      environmentSecrets: environmentSecrets,
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
    final profile = entry.profile;
    final bearer = profile.transport == McpTransport.streamableHttp
        ? await repository.readBearer(profile)
        : null;
    final headers = profile.transport == McpTransport.streamableHttp
        ? await repository.readHeaders(profile)
        : const <String, String>{};
    final secrets = profile.command == null
        ? const <String, String>{}
        : await repository.readEnvironmentSecrets(profile);
    cancellation.throwIfCancelled();
    final client = await connections.create(
      profile,
      bearer: bearer,
      headers: headers,
      environment: {...?profile.command?.environment, ...secrets},
    );
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
      await _cleanStdioDirectory(id);
      if (ref.mounted) state = const AsyncData(null);
    } catch (_) {
      final pending = await repository.get(id);
      if (ref.mounted) state = AsyncData(pending);
      rethrow;
    }
  });

  /// stdio 服务的专属目录不在数据库登记；删除成功后尽力清理，失败只记录。
  Future<void> _cleanStdioDirectory(String id) async {
    try {
      final workspaces = await ref.read(workspaceRepositoryProvider.future);
      final directory = Directory(
        McpStdioLauncher.serverDirectory(workspaces, id),
      );
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    } on Object catch (error) {
      AppLogger.warning('MCP 服务目录清理失败，残留目录不影响使用：${error.runtimeType}');
    }
  }

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
