import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import '../../core/error/failure.dart';
import '../../core/utils/id.dart';
import '../datasources/local/app_database.dart';
import '../models/workspace.dart';

class WorkspaceLease {
  WorkspaceLease(this.snapshot, this._release);
  final WorkspaceSnapshot snapshot;
  final void Function() _release;
  bool _closed = false;
  void close() {
    if (!_closed) {
      _closed = true;
      _release();
    }
  }
}

class WorkspaceRepository {
  WorkspaceRepository(this.db, this.root);
  final AppDatabase db;
  final Directory root;
  final Set<String> _leases = {};
  bool _mutatingEnvironment = false;
  bool get busy => _mutatingEnvironment || _leases.isNotEmpty;
  bool inUse(String id) => _leases.contains(id);
  static const environmentId = 'ubuntu-arm64';

  Future<T> _records<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on Failure {
      rethrow;
    } catch (error) {
      throw StorageFailure('工作区记录读取或保存失败', cause: error);
    }
  }

  Future<RuntimeEnvironment> environment() => _records(() async {
    final row = await (db.select(
      db.runtimeEnvironments,
    )..where((t) => t.id.equals(environmentId))).getSingleOrNull();
    return row == null
        ? const RuntimeEnvironment()
        : RuntimeEnvironment.fromJson(
            jsonDecode(row.configurationJson) as Map<String, dynamic>,
          );
  });
  Future<void> saveEnvironment(RuntimeEnvironment value) => _records(() async {
    await db
        .into(db.runtimeEnvironments)
        .insertOnConflictUpdate(
          RuntimeEnvironmentsCompanion.insert(
            id: environmentId,
            configurationJson: jsonEncode(value.toJson()),
          ),
        );
  });
  Stream<RuntimeEnvironment> watchEnvironment() async* {
    try {
      yield* (db.select(
        db.runtimeEnvironments,
      )..where((t) => t.id.equals(environmentId))).watch().map(
        (rows) => rows.isEmpty
            ? const RuntimeEnvironment()
            : RuntimeEnvironment.fromJson(
                jsonDecode(rows.single.configurationJson)
                    as Map<String, dynamic>,
              ),
      );
    } catch (error) {
      throw StorageFailure('读取环境状态失败', cause: error);
    }
  }

  Workspace _workspace(WorkspaceRow row) => Workspace(
    id: row.id,
    name: row.name,
    rootPath: p.join(root.path, 'workspaces', row.id),
    createdAt: row.createdAt,
    deleting: row.deleting,
  );
  Future<List<Workspace>> list() => _records(
    () async => (await db.select(db.workspaces).get()).map(_workspace).toList(),
  );
  Stream<List<Workspace>> watch() async* {
    try {
      yield* db
          .select(db.workspaces)
          .watch()
          .map((rows) => rows.map(_workspace).toList());
    } catch (error) {
      throw StorageFailure('读取工作区失败', cause: error);
    }
  }

  Future<Workspace?> get(String id) => _records(() async {
    final row = await (db.select(
      db.workspaces,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _workspace(row);
  });
  Future<Workspace> create(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > 100) {
      throw const OperationFailure('工作区名称需为 1–100 个字符');
    }
    final id = generateId();
    final directory = Directory(p.join(root.path, 'workspaces', id));
    try {
      await directory.create(recursive: true);
    } on FileSystemException {
      throw const OperationFailure('无法创建工作区目录，请检查可用空间');
    }
    try {
      final now = DateTime.now();
      await _records(
        () => db
            .into(db.workspaces)
            .insert(
              WorkspacesCompanion.insert(
                id: id,
                name: trimmed,
                environmentId: environmentId,
                createdAt: now,
              ),
            ),
      );
      return Workspace(
        id: id,
        name: trimmed,
        rootPath: directory.path,
        createdAt: now,
      );
    } catch (_) {
      await directory.delete(recursive: true);
      rethrow;
    }
  }

  Future<void> bind(String conversationId, String? workspaceId) => _records(
    () => db.transaction(() async {
      if (workspaceId != null) {
        final workspace = await get(workspaceId);
        if (workspace == null || workspace.deleting) {
          throw const OperationFailure('工作区已删除');
        }
      }
      final changed =
          await (db.update(db.conversations)
                ..where((t) => t.id.equals(conversationId)))
              .write(ConversationsCompanion(workspaceId: Value(workspaceId)));
      if (changed == 0) throw const OperationFailure('会话已不存在');
    }),
  );
  Future<List<String>> conversationsUsing(String id) => _records(
    () async =>
        (await (db.select(
              db.conversations,
            )..where((t) => t.workspaceId.equals(id))).get())
            .map((c) => c.title)
            .toList(),
  );

  /// 删除先撤销新使用，再处理文件。失败保留 deleting 行供显式重试。
  Future<void> delete(String id) async {
    if (!_leases.add(id)) throw const OperationFailure('工作区正在使用，请先停止所属任务');
    try {
      final workspace = await get(id);
      if (workspace == null) return;
      await _records(
        () => (db.update(db.workspaces)..where((t) => t.id.equals(id))).write(
          const WorkspacesCompanion(deleting: Value(true)),
        ),
      );
      try {
        final directory = Directory(workspace.rootPath);
        if (await directory.exists()) await directory.delete(recursive: true);
      } on FileSystemException {
        throw const OperationFailure('工作区文件删除失败，可重试删除；历史消息仍保留');
      }
      await _records(
        () => (db.delete(db.workspaces)..where((t) => t.id.equals(id))).go(),
      );
    } finally {
      _leases.remove(id);
    }
  }

  /// 安装/卸载与运行互斥，保留租约直到模型运行结束，防止固定快照失效。
  void beginEnvironmentChange() {
    if (busy) throw const OperationFailure('环境或工作区正在使用，请先结束相关任务');
    _mutatingEnvironment = true;
  }

  void endEnvironmentChange() {
    _mutatingEnvironment = false;
  }

  Future<WorkspaceLease?> acquire(
    String id, {
    WorkspaceSnapshot? expected,
  }) async {
    if (_mutatingEnvironment) return null;
    if (!_leases.add(id)) throw const OperationFailure('此工作区正在使用');
    var retained = false;
    try {
      final workspace = await get(id);
      final env = await environment();
      if (workspace == null || workspace.deleting || !env.ready) return null;
      final snapshot = WorkspaceSnapshot(
        id: id,
        name: workspace.name,
        rootPath: workspace.rootPath,
        environmentRoot: env.rootPath!,
        environmentRevision: env.revision!,
      );
      if (expected != null &&
          jsonEncode(expected.toJson()) != jsonEncode(snapshot.toJson())) {
        throw const OperationFailure('运行所用环境或工作区已改变，不能继续旧任务');
      }
      retained = true;
      return WorkspaceLease(snapshot, () => _leases.remove(id));
    } finally {
      if (!retained) _leases.remove(id);
    }
  }

  Future<void> recordCopy(
    String id,
    String relativePath,
    Map<String, dynamic> source,
  ) => _records(() async {
    await db
        .into(db.workspaceCopies)
        .insertOnConflictUpdate(
          WorkspaceCopiesCompanion.insert(
            workspaceId: id,
            relativePath: relativePath,
            sourceJson: jsonEncode(source),
          ),
        );
  });

  Future<void> recoverInstallation() async {
    final env = await environment();
    if ({
      EnvironmentPhase.downloading,
      EnvironmentPhase.verifying,
      EnvironmentPhase.extracting,
      EnvironmentPhase.checking,
    }.contains(env.phase)) {
      await saveEnvironment(
        RuntimeEnvironment(
          phase: env.rootPath == null
              ? EnvironmentPhase.failed
              : EnvironmentPhase.ready,
          rootPath: env.rootPath,
          imageUrl: env.imageUrl,
          imageDigest: env.imageDigest,
          downloadBytes: env.downloadBytes,
          revision: env.revision,
          installedBytes: env.installedBytes,
          error: '上次安装已中断，可重试；已有工作区保留',
        ),
      );
    }
    final staging = Directory(p.join(root.path, 'staging'));
    try {
      if (await staging.exists()) await staging.delete(recursive: true);
    } on FileSystemException {
      throw const OperationFailure('中断安装的临时文件清理失败，请重试');
    }
  }
}
