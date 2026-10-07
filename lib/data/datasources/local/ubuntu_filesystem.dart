import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/error/failure.dart';
import '../../models/ubuntu_filesystem_layout.dart';

/// 固定 rootfs 的文件生命周期。调用者须持有仓储租约或环境独占权限。
class UbuntuFilesystem {
  UbuntuFilesystem(Directory linuxRoot)
    : layout = UbuntuFilesystemLayout(p.normalize(p.absolute(linuxRoot.path)));

  final UbuntuFilesystemLayout layout;

  Future<T> _files<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on FormatException {
      throw const OperationFailure('工作区或服务目录 ID 无效');
    } on FileSystemException {
      throw const WorkspaceFailure('filesystem', 'Ubuntu 文件操作失败，请检查目录和可用空间后重试');
    }
  }

  /// 不通过宿主链接创建、复制或删除受管理子树；shell 的 guest 访问不受此限制。
  Future<Directory?> _directory(String path, {bool create = false}) async {
    final root = Directory(layout.linuxRoot);
    if (!await root.exists()) {
      if (!create) return null;
      await root.create(recursive: true);
    }
    if (await root.resolveSymbolicLinks() != root.path) {
      throw const WorkspaceFailure('invalidPath', 'Linux 存储目录已改变');
    }
    var current = root.path;
    for (final component in p.split(p.relative(path, from: root.path))) {
      current = p.join(current, component);
      final type = await FileSystemEntity.type(current, followLinks: false);
      if (type == FileSystemEntityType.notFound) {
        if (!create) return null;
        await Directory(current).create();
      } else if (type != FileSystemEntityType.directory) {
        throw const WorkspaceFailure('invalidPath', 'Ubuntu 受管理目录已改变');
      }
      if (await Directory(current).resolveSymbolicLinks() != current) {
        throw const WorkspaceFailure('invalidPath', 'Ubuntu 受管理目录已改变');
      }
    }
    return Directory(path);
  }

  Future<Directory> _createWorkspace(String path) => _files(() async {
    await _directory(p.dirname(path), create: true);
    final directory = Directory(path);
    if (await FileSystemEntity.type(directory.path, followLinks: false) !=
        FileSystemEntityType.notFound) {
      throw const OperationFailure('工作区目录已存在，不能覆盖已有文件');
    }
    await directory.create();
    return directory;
  });

  Future<Directory> createSession(String id) =>
      _files(() => _createWorkspace(layout.sessionDirectory(id)));
  Future<Directory> createProject(String id) =>
      _files(() => _createWorkspace(layout.projectDirectory(id)));

  Future<Directory?> session(String id) =>
      _files(() => _directory(layout.sessionDirectory(id)));
  Future<Directory?> project(String id) =>
      _files(() => _directory(layout.projectDirectory(id)));

  Future<Directory> ensureMcpService(String id) => _files(
    () async => (await _directory(layout.mcpDirectory(id), create: true))!,
  );

  Future<void> _deleteOwnedDirectory(String path) async {
    if (await _directory(p.dirname(path)) == null) return;
    final type = await FileSystemEntity.type(path, followLinks: false);
    if (type == FileSystemEntityType.directory) {
      await Directory(path).delete(recursive: true);
    } else if (type == FileSystemEntityType.link) {
      // 只移除所属路径的链接，绝不递归清理链接指向的其他会话或全局目录。
      await Link(path).delete();
    } else if (type != FileSystemEntityType.notFound) {
      await File(path).delete();
    }
  }

  Future<void> deleteSession(String id) =>
      _files(() => _deleteOwnedDirectory(layout.sessionDirectory(id)));
  Future<void> rollbackProjectCreation(String id) =>
      _files(() => _deleteOwnedDirectory(layout.projectDirectory(id)));
  Future<void> deleteMcpService(String id) =>
      _files(() => _deleteOwnedDirectory(layout.mcpDirectory(id)));

  Future<void> _clearSystem(Directory rootfs, void Function() check) async {
    await for (final entry in rootfs.list(followLinks: false)) {
      check();
      if (UbuntuFilesystemLayout.persistentRootNames.contains(
        p.basename(entry.path),
      )) {
        continue;
      }
      await entry.delete(recursive: entry is Directory);
    }
    check();
  }

  Future<void> removeSystem({void Function()? check}) => _files(() async {
    final rootfs = await _directory(layout.rootfs);
    if (rootfs != null) await _clearSystem(rootfs, check ?? () {});
  });

  /// 清单来自已解包且检查通过的 staging；逐项移动保留模式与相对链接。
  /// 提交中断时保留部分系统内容但不开启执行，下次显式安装重新提交。
  Future<void> commitSystem(
    Directory stagedRootfs, {
    required void Function() check,
  }) => _files(() async {
    if (!p.isWithin(layout.staging, stagedRootfs.path) ||
        await _directory(stagedRootfs.path) == null) {
      throw const WorkspaceFailure('invalidPath', '安装暂存目录不可用');
    }
    final manifest = await stagedRootfs.list(followLinks: false).toList();
    manifest.sort((a, b) => a.path.compareTo(b.path));
    if (manifest.any(
      (entry) => UbuntuFilesystemLayout.persistentRootNames.contains(
        p.basename(entry.path),
      ),
    )) {
      throw const WorkspaceFailure('archivePath', '环境镜像不能覆盖工作区或服务目录');
    }
    check();
    final rootfs = (await _directory(layout.rootfs, create: true))!;
    await _clearSystem(rootfs, check);
    for (final entry in manifest) {
      check();
      await entry.rename(p.join(rootfs.path, p.basename(entry.path)));
    }
    check();
  });
}
