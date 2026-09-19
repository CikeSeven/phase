import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/error/failure.dart';
import '../../core/utils/id.dart';
import '../../features/workspace/process_driver.dart';
import '../datasources/local/app_database.dart';
import '../models/workspace.dart';

part 'workspace_repository.g.dart';

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
  bool _installingDependencies = false;
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

  Workspace _workspace(WorkspaceRow row, {String? name}) => Workspace(
    id: row.id,
    name: name ?? row.name,
    rootPath: p.join(root.path, 'workspaces', row.id),
    createdAt: row.createdAt,
    deleting: row.deleting,
  );
  JoinedSelectStatement<HasResultSet, dynamic> _ownedWorkspaces() =>
      db.select(db.workspaces).join([
        innerJoin(
          db.conversations,
          db.conversations.workspaceId.equalsExp(db.workspaces.id),
        ),
      ])..orderBy([OrderingTerm.desc(db.conversations.updatedAt)]);

  Workspace _ownedWorkspace(TypedResult row) => _workspace(
    row.readTable(db.workspaces),
    name: row.readTable(db.conversations).title,
  );

  Future<List<Workspace>> list() => _records(
    () async => (await _ownedWorkspaces().get()).map(_ownedWorkspace).toList(),
  );
  Stream<List<Workspace>> watch() async* {
    try {
      yield* _ownedWorkspaces().watch().map(
        (rows) => rows.map(_ownedWorkspace).toList(),
      );
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
  Future<Workspace> create(String name, {String? id}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > 100) {
      throw const OperationFailure('工作区名称需为 1–100 个字符');
    }
    final workspaceId = id ?? generateId();
    final directory = Directory(p.join(root.path, 'workspaces', workspaceId));
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
                id: workspaceId,
                name: trimmed,
                environmentId: environmentId,
                createdAt: now,
              ),
            ),
      );
      return Workspace(
        id: workspaceId,
        name: trimmed,
        rootPath: directory.path,
        createdAt: now,
      );
    } catch (_) {
      await directory.delete(recursive: true);
      rethrow;
    }
  }

  /// 复制会话文件，副本目录与来源记录均独立；不复制共享 Ubuntu 环境。
  Future<void> copyFiles(String sourceId, Workspace target) async {
    if (!_leases.add(sourceId)) {
      throw const OperationFailure('工作区正在使用，请先结束任务再复制会话');
    }
    try {
      final source = await get(sourceId);
      if (source == null || source.deleting) {
        throw const OperationFailure('原会话工作区不可用，无法复制');
      }
      final directory = Directory(source.rootPath);
      if (await directory.exists()) {
        await for (final entry in directory.list(
          recursive: true,
          followLinks: false,
        )) {
          final destination = p.join(
            target.rootPath,
            p.relative(entry.path, from: source.rootPath),
          );
          if (entry is Directory) {
            await Directory(destination).create(recursive: true);
          } else if (entry is File) {
            await File(destination).parent.create(recursive: true);
            await entry.copy(destination);
          } else if (entry is Link) {
            final link = await entry.target();
            final resolved = p.normalize(p.join(p.dirname(entry.path), link));
            if (!p.isWithin(source.rootPath, resolved) &&
                resolved != source.rootPath) {
              throw const OperationFailure('工作区包含指向外部的链接，无法安全复制');
            }
            final mapped = p.join(
              target.rootPath,
              p.relative(resolved, from: source.rootPath),
            );
            await Link(destination)
                .create(p.relative(mapped, from: p.dirname(destination)));
          }
        }
      }
      final copies = await _records(
        () => (db.select(
          db.workspaceCopies,
        )..where((t) => t.workspaceId.equals(sourceId))).get(),
      );
      for (final copy in copies) {
        await recordCopy(
          target.id,
          copy.relativePath,
          jsonDecode(copy.sourceJson) as Map<String, dynamic>,
        );
      }
    } on FileSystemException {
      throw const OperationFailure('会话工作区文件复制失败，请检查可用空间');
    } finally {
      _leases.remove(sourceId);
    }
  }

  /// 删除先撤销新使用，再处理文件。失败保留 deleting 行供显式重试。
  Future<void> delete(String id, {Future<void> Function()? deleteOwner}) async {
    if (!_leases.add(id)) throw const OperationFailure('工作区正在使用，请先停止所属任务');
    try {
      final workspace = await get(id);
      if (workspace == null) {
        await deleteOwner?.call();
        return;
      }
      await _records(
        () => (db.update(db.workspaces)..where((t) => t.id.equals(id))).write(
          const WorkspacesCompanion(deleting: Value(true)),
        ),
      );
      try {
        final directory = Directory(workspace.rootPath);
        if (await directory.exists()) await directory.delete(recursive: true);
      } on FileSystemException {
        throw const OperationFailure('会话工作区文件清理失败，请重试删除会话');
      }
      await _records(
        () => db.transaction(() async {
          await deleteOwner?.call();
          await (db.delete(db.workspaces)..where((t) => t.id.equals(id))).go();
        }),
      );
    } finally {
      _leases.remove(id);
    }
  }

  /// 安装/卸载与运行互斥，保留租约直到模型运行结束，防止固定快照失效。
  void beginEnvironmentChange() {
    if (busy || _installingDependencies) {
      throw const OperationFailure('环境或工作区正在使用，请先结束相关任务');
    }
    _mutatingEnvironment = true;
  }

  void endEnvironmentChange() {
    _mutatingEnvironment = false;
  }

  /// 依赖安装与环境级变更互斥；不替换 rootfs，因此不阻断运行租约，
  /// guest 内并发 apt 冲突由锁超时兜底。
  void beginDependencyChange() {
    if (_mutatingEnvironment) {
      throw const OperationFailure('环境正在安装或卸载，请稍候');
    }
    if (_installingDependencies) {
      throw const OperationFailure('已有依赖安装正在进行，请稍候');
    }
    _installingDependencies = true;
  }

  void endDependencyChange() {
    _installingDependencies = false;
  }

  Future<WorkspaceLease> acquire(
    String id, {
    WorkspaceSnapshot? expected,
  }) async {
    if (!_leases.add(id)) throw const OperationFailure('此工作区正在使用');
    var retained = false;
    try {
      final workspace = await get(id);
      final env = await environment();
      if (workspace == null || workspace.deleting) {
        throw const OperationFailure('会话工作区不可用，请完成会话删除后重新开始');
      }
      final snapshot = WorkspaceSnapshot(
        id: id,
        name: workspace.name,
        rootPath: workspace.rootPath,
        environmentRoot: !_mutatingEnvironment && env.ready
            ? env.rootPath
            : null,
        environmentRevision: !_mutatingEnvironment && env.ready
            ? env.revision
            : null,
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
          installedDependencies: env.installedDependencies,
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

@Riverpod(keepAlive: true)
Future<WorkspaceRepository> workspaceRepository(Ref ref) async {
  final db = await ref.watch(appDatabaseProvider.future);
  final info = await ref.watch(processDriverProvider).info();
  final repository = WorkspaceRepository(db, Directory(info.rootDirectory));
  await repository.recoverInstallation();
  return repository;
}
