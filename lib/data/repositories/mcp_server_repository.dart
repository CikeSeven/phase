import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/error/failure.dart';
import '../../core/utils/id.dart';
import '../datasources/local/app_database.dart';
import '../datasources/local/secure_key_storage.dart';
import '../models/mcp_server_profile.dart';
import '../models/tool_source.dart';

part 'mcp_server_repository.g.dart';

class McpServerRepository {
  McpServerRepository(this._db, this._keys);
  final AppDatabase _db;
  final SecureKeyStorage _keys;

  McpServerEntry _entry(McpServerRow row) => McpServerEntry(
    profile: McpServerProfile.fromJson(
      jsonDecode(row.profileJson) as Map<String, dynamic>,
    ),
    tools: List.unmodifiable([
      for (final tool in jsonDecode(row.toolsJson) as List)
        ToolSnapshot.fromJson(tool as Map<String, dynamic>),
    ]),
    protocolVersion: row.protocolVersion,
  );

  Future<List<McpServerEntry>> list() => _guard(
    () async => (await _db.select(_db.mcpServers).get()).map(_entry).toList(),
  );

  Stream<List<McpServerEntry>> watch() async* {
    try {
      yield* _db
          .select(_db.mcpServers)
          .watch()
          .map((rows) => rows.map(_entry).toList());
    } on Object catch (error) {
      throw StorageFailure('读取 MCP 配置失败', cause: error);
    }
  }

  Future<McpServerEntry?> get(String id) => _guard(() async {
    final row = await (_db.select(
      _db.mcpServers,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _entry(row);
  });

  Future<McpServerProfile> save(
    McpServerProfile draft, {
    String? bearer,
    Map<String, String>? headers,
  }) => _guard(() async {
    draft.validate();
    final previous = await get(draft.id);
    if (previous?.profile.deleting == true) {
      throw const OperationFailure('请先完成此 MCP 服务的删除');
    }
    final old = previous?.profile;
    final changed =
        old == null ||
        old.endpoint != draft.endpoint ||
        old.requiresBearer != draft.requiresBearer ||
        old.connectTimeoutSeconds != draft.connectTimeoutSeconds ||
        old.callTimeoutSeconds != draft.callTimeoutSeconds ||
        (bearer?.trim().isNotEmpty ?? false) ||
        headers != null;
    // 空凭据保留旧值；免凭据模式不读取或删除它。
    var reference = old?.credentialRef;
    final references = {...?old?.credentialRefs};
    final newReferences = <String>[];
    final headerRefs = {...?old?.headerRefs};
    _validateHeaders(headers);
    try {
      if (bearer != null && bearer.trim().isNotEmpty) {
        if (bearer.contains('\r') || bearer.contains('\n')) {
          throw const OperationFailure('Bearer 凭据不能包含换行');
        }
        reference = generateId();
        newReferences.add(reference);
        await _keys.writeMcp(reference, bearer.trim());
        references.add(reference);
      }
      if (headers != null) {
        headerRefs.clear();
        for (final entry in headers.entries) {
          final reference = generateId();
          newReferences.add(reference);
          await _keys.writeMcp(reference, entry.value);
          references.add(reference);
          headerRefs[entry.key] = reference;
        }
      }
      final profile = draft.copyWith(
        credentialRef: reference,
        credentialRefs: List.unmodifiable(references),
        headerRefs: Map.unmodifiable(headerRefs),
        definitionRevision: changed ? generateId() : old.definitionRevision,
        updatedAt: DateTime.now(),
      );
      await _db
          .into(_db.mcpServers)
          .insertOnConflictUpdate(
            McpServersCompanion(
              id: Value(profile.id),
              profileJson: Value(jsonEncode(profile.toJson())),
              toolsJson: Value(
                jsonEncode(
                  changed
                      ? []
                      : previous!.tools.map((t) => t.toJson()).toList(),
                ),
              ),
              protocolVersion: Value(
                changed ? null : previous!.protocolVersion,
              ),
            ),
          );
      return profile;
    } catch (_) {
      for (final reference in newReferences) {
        await _keys.deleteMcp(reference);
      }
      rethrow;
    }
  });

  Future<void> saveCatalog(
    McpServerProfile profile,
    List<ToolSnapshot> tools,
    String version,
  ) => _guard(
    () => _db.transaction(() async {
      final current = await get(profile.id);
      if (current == null ||
          current.profile.deleting ||
          current.profile.definitionRevision != profile.definitionRevision) {
        throw const OperationFailure('MCP 配置已变化，请重新检查连接');
      }
      await (_db.update(
        _db.mcpServers,
      )..where((t) => t.id.equals(profile.id))).write(
        McpServersCompanion(
          toolsJson: Value(jsonEncode(tools.map((t) => t.toJson()).toList())),
          protocolVersion: Value(version),
        ),
      );
    }),
  );

  Future<Map<String, String>> readHeaders(McpServerProfile profile) async {
    final result = <String, String>{};
    for (final entry in profile.headerRefs.entries) {
      final value = await _keys.readMcp(entry.value);
      if (value == null) {
        throw const McpFailure('authentication', 'MCP 自定义请求头凭据缺失，请编辑服务配置');
      }
      result[entry.key] = value;
    }
    return result;
  }

  void _validateHeaders(Map<String, String>? headers) {
    if (headers == null) return;
    const reserved = {
      'authorization',
      'host',
      'connection',
      'content-length',
      'content-type',
      'accept',
      'mcp-session-id',
      'mcp-protocol-version',
      'transfer-encoding',
    };
    final names = <String>{};
    for (final entry in headers.entries) {
      if (headers.length > 16 ||
          !RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(entry.key) ||
          reserved.contains(entry.key.toLowerCase()) ||
          !names.add(entry.key.toLowerCase()) ||
          entry.value.contains('\r') ||
          entry.value.contains('\n') ||
          entry.value.length > 8192) {
        throw const OperationFailure('自定义请求头无效：最多 16 项，不能覆盖鉴权或协议头，值不能包含换行');
      }
    }
  }

  Future<String?> readBearer(McpServerProfile profile) =>
      profile.requiresBearer && profile.credentialRef != null
      ? _keys.readMcp(profile.credentialRef!)
      : Future.value(null);

  /// 先持久化禁用，凭据删除失败仍保留可重试条目。
  Future<void> delete(String id) => _guard(() async {
    final entry = await get(id);
    if (entry == null) return;
    await (_db.update(_db.mcpServers)..where((t) => t.id.equals(id))).write(
      McpServersCompanion(
        profileJson: Value(
          jsonEncode(
            entry.profile.copyWith(enabled: false, deleting: true).toJson(),
          ),
        ),
      ),
    );
    for (final reference in entry.profile.credentialRefs) {
      await _keys.deleteMcp(reference);
    }
    await (_db.delete(_db.mcpServers)..where((t) => t.id.equals(id))).go();
  });

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on Failure {
      rethrow;
    } on Object catch (error) {
      throw StorageFailure('读写 MCP 配置失败', cause: error);
    }
  }
}

@Riverpod(keepAlive: true)
Future<McpServerRepository> mcpServerRepository(Ref ref) async =>
    McpServerRepository(
      await ref.watch(appDatabaseProvider.future),
      ref.watch(secureKeyStorageProvider),
    );

@riverpod
Stream<List<McpServerEntry>> mcpServers(Ref ref) async* {
  final repository = await ref.watch(mcpServerRepositoryProvider.future);
  yield* repository.watch();
}
