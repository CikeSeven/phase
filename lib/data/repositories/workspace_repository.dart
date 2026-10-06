import '../datasources/local/ubuntu_filesystem.dart';
import '../../features/workspace/workspace_file_access.dart';

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
  WorkspaceRepository(this.db, this.root) : filesystem = UbuntuFilesystem(root);

  WorkspaceFileAccess files(WorkspaceSnapshot binding) =>
      LocalWorkspaceFileAccess(
        binding,
        Directory(p.join(root.path, 'staging')),
      );

  final AppDatabase db;
  final Directory root;
  final UbuntuFilesystem filesystem;
  final Set<String> _leases = {};
  final Map<String, int> _taskUsers = {};
  final Set<String> _fileMutations = {};
  bool _mutatingEnvironment = false;
  bool _installingDependencies = false;
  int _environmentUsers = 0;
  bool get busy =>
      _mutatingEnvironment ||
      _leases.isNotEmpty ||
      _taskUsers.isNotEmpty ||
      _environmentUsers > 0;
  bool inUse(String id) => _leases.contains(id) || _taskUsers.containsKey(id);
  bool environmentReady(RuntimeEnvironment environment) =>
      environment.ready && environment.rootPath == filesystem.layout.rootfs;
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
    rootPath: filesystem.layout.sessionDirectory(row.id),
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
    if (row == null) return null;
    return _workspace(row);
  });
  Future<Workspace> create(String name, {String? id}) async {
    final release = retainEnvironment();
    Directory? directory;
    String? creatingId;
    var saved = false;
    try {
      final trimmed = name.trim();
      if (trimmed.isEmpty || trimmed.length > 100) {
        throw const OperationFailure('工作区名称需为 1–100 个字符');
      }
      final workspaceId = id ?? generateId();
      if (!_leases.add(workspaceId)) {
        throw const OperationFailure('此会话工作区正在创建或使用');
      }
      creatingId = workspaceId;
      if (await get(workspaceId) != null) {
        throw const OperationFailure('会话工作区已存在');
      }
      directory = await filesystem.createSession(workspaceId);
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
      saved = true;
      return Workspace(
        id: workspaceId,
        name: trimmed,
        rootPath: directory.path,
        createdAt: now,
      );
    } finally {
      try {
        if (!saved && directory != null) {
          await filesystem.deleteSession(creatingId!);
        }
      } on FileSystemException {
        throw const OperationFailure('未完成会话的目录清理失败，请重试');
      } finally {
        if (creatingId != null) _leases.remove(creatingId);
        release();
      }
    }
  }

  /// 复制会话文件，副本目录与来源记录均独立；不复制共享 Ubuntu 环境。
  Future<void> copyFiles(String sourceId, Workspace target) async {
    final release = retainEnvironment();
    if (_taskUsers.containsKey(sourceId) || _taskUsers.containsKey(target.id)) {
      release();
      throw const OperationFailure('请先停止后台任务，再复制会话');
    }
    if (!_leases.add(sourceId)) {
      release();
      throw const OperationFailure('工作区正在使用，请先结束任务再复制会话');
    }
    if (sourceId == target.id || !_leases.add(target.id)) {
      _leases.remove(sourceId);
      release();
      throw const OperationFailure('目标工作区正在使用，无法复制');
    }
    _fileMutations.addAll([sourceId, target.id]);
    try {
      final source = await get(sourceId);
      if (source == null || source.deleting) {
        throw const OperationFailure('原会话工作区不可用，无法复制');
      }
      if (target.rootPath != filesystem.layout.sessionDirectory(target.id) ||
          await filesystem.session(target.id) == null) {
        throw const OperationFailure('目标会话目录不可用');
      }
      final directory = await filesystem.session(sourceId);
      if (directory != null) {
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
      _leases.remove(target.id);
      _fileMutations.removeAll([sourceId, target.id]);
      release();
    }
  }

  /// 删除先撤销新使用，再处理文件。失败保留 deleting 行供显式重试。
  Future<void> delete(String id, {Future<void> Function()? deleteOwner}) async {
    final release = retainEnvironment();
    if (_taskUsers.containsKey(id)) {
      release();
      throw const OperationFailure('请先在任务管理中停止此会话的后台任务');
    }
    if (!_leases.add(id)) {
      release();
      throw const OperationFailure('工作区正在使用，请先停止所属任务');
    }
    _fileMutations.add(id);
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
        await filesystem.deleteSession(id);
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
      _fileMutations.remove(id);
      release();
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

  /// 覆盖整个异步存储操作或 MCP 连接，不能只在文件变更前检查一次。
  void Function() retainEnvironment() {
    if (_mutatingEnvironment) {
      throw const OperationFailure('环境正在安装或卸载，请稍候');
    }
    _environmentUsers++;
    var released = false;
    return () {
      if (released) return;
      released = true;
      _environmentUsers--;
    };
  }

  /// Background services share files with model runs but prevent destructive workspace changes.
  Future<WorkspaceLease> retainTask(WorkspaceSnapshot expected) async {
    if (_fileMutations.contains(expected.id)) {
      throw const OperationFailure('工作区正在删除或复制，请稍候');
    }
    final release = retainEnvironment();
    final id = expected.id;
    _taskUsers[id] = (_taskUsers[id] ?? 0) + 1;
    void close() {
      final count = _taskUsers[id]! - 1;
      if (count == 0) {
        _taskUsers.remove(id);
      } else {
        _taskUsers[id] = count;
      }
      release();
    }

    try {
      final current = await snapshot(id);
      if (!current.executable ||
          current.rootPath != expected.rootPath ||
          current.environmentRoot != expected.environmentRoot ||
          current.environmentRevision != expected.environmentRevision) {
        throw const OperationFailure('任务所用工作区或环境已改变');
      }
      return WorkspaceLease(current, close);
    } catch (_) {
      close();
      rethrow;
    }
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

  /// 只读规划与运行租约共用同一环境可用性判断。
  Future<WorkspaceSnapshot> snapshot(String id) async {
    final workspace = await get(id);
    if (workspace == null || workspace.deleting) {
      throw const OperationFailure('会话工作区不可用，请完成会话删除后重新开始');
    }
    return _snapshot(workspace);
  }

  Future<WorkspaceSnapshot> _snapshot(Workspace workspace) async {
    final env = await environment();
    return WorkspaceSnapshot(
      id: workspace.id,
      name: workspace.name,
      rootPath: workspace.rootPath,
      environmentRoot: !_mutatingEnvironment && environmentReady(env)
          ? env.rootPath
          : null,
      environmentRevision: !_mutatingEnvironment && environmentReady(env)
          ? env.revision
          : null,
    );
  }

  Future<WorkspaceLease> acquire(
    String id, {
    WorkspaceSnapshot? expected,
  }) async {
    if (_mutatingEnvironment) {
      throw const OperationFailure('环境正在安装或卸载，请稍候');
    }
    if (!_leases.add(id)) throw const OperationFailure('此工作区正在使用');
    var retained = false;
    try {
      final snapshot = await this.snapshot(id);
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
      EnvironmentPhase.configuring,
      EnvironmentPhase.checking,
    }.contains(env.phase)) {
      await saveEnvironment(
        RuntimeEnvironment(
          phase: EnvironmentPhase.failed,
          rootPath: env.rootPath,
          imageUrl: env.imageUrl,
          imageDigest: env.imageDigest,
          downloadBytes: env.downloadBytes,
          revision: env.revision,
          error: '上次安装已中断，请重新安装；会话和服务文件保留',
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
