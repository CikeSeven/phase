import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../../../core/error/failure.dart';
import '../../../core/utils/id.dart';
import '../../../data/models/workspace.dart';
import '../commands/command_api.g.dart';
import '../commands/command_channel_driver.dart';
import '../tools/file_text.dart';
import '../tools/tool.dart';
import 'process_driver.dart';
import 'workspace_files.dart' show workspacePath;

class WorkspaceEntry {
  const WorkspaceEntry(this.path, this.type, this.size, {this.digest});
  final String path;
  final String type;
  final int size;
  final String? digest;
}

/// Paths are workspace-relative. Remote locations never masquerade as dart:io paths.
abstract class WorkspaceFileAccess {
  WorkspaceFileAccess(this.binding, this.staging);
  final WorkspaceSnapshot binding;
  final Directory staging;
  Future<WorkspaceEntry> stat(
    String path,
    RunCancellation cancellation, {
    bool withDigest = false,
  });
  Future<List<WorkspaceEntry>> list(String path, RunCancellation cancellation);
  Future<FileTextPage> readPage(
    String path,
    Map<String, dynamic> arguments,
    RunCancellation cancellation,
  );
  Future<void> ensure(RunCancellation cancellation);
  Future<void> exportPath(
    String path,
    String localPath,
    RunCancellation cancellation,
  );
  Future<void> importPath(
    String path,
    String localPath,
    RunCancellation cancellation, {
    String? expectedDigest,
  });
  Future<void> deleteRoot(RunCancellation cancellation);

  String executionPath(String relative) =>
      p.posix.join(binding.executionRoot, relative);
  Future<Directory> temporary() async {
    await staging.create(recursive: true);
    return staging.createTemp('workspace-');
  }

  Future<String> readText(String path, RunCancellation cancellation) async {
    final entry = await stat(path, cancellation);
    if (entry.type != 'file') {
      throw const FileToolException('fileNotFound', '文件不存在或不是普通文件');
    }
    if (entry.size > maxFileWriteBytes) {
      throw const FileToolException(
        'fileTooLarge',
        '编辑文件上限为 2 MiB，请通过工作区 shell 处理',
      );
    }
    final temp = await temporary();
    try {
      final file = File(p.join(temp.path, 'content'));
      await exportPath(path, file.path, cancellation);
      if (await file.length() > maxFileWriteBytes) {
        throw const FileToolException(
          'fileTooLarge',
          '编辑文件上限为 2 MiB，请通过工作区 shell 处理',
        );
      }
      return await readEditableText(file);
    } finally {
      await temp.delete(recursive: true);
    }
  }

  Future<void> write(
    String path,
    String text,
    RunCancellation cancellation, {
    String? original,
  }) async {
    final bytes = utf8.encode(text);
    if (bytes.length > maxFileWriteBytes) {
      throw const FileToolException(
        'contentTooLarge',
        '单次写入上限为 2 MiB UTF-8 内容',
      );
    }
    final temp = await temporary();
    try {
      final file = File(p.join(temp.path, 'content'));
      await file.writeAsBytes(bytes, flush: true);
      cancellation.throwIfCancelled();
      await importPath(
        path,
        file.path,
        cancellation,
        expectedDigest: original == null
            ? null
            : sha256.convert(utf8.encode(original)).toString(),
      );
    } finally {
      await temp.delete(recursive: true);
    }
  }
}

class LocalWorkspaceFileAccess extends WorkspaceFileAccess {
  LocalWorkspaceFileAccess(super.binding, super.staging);
  Future<String> _path(String path, {bool exists = true}) =>
      workspacePath(binding.rootPath, path, mustExist: exists);
  @override
  Future<void> ensure(RunCancellation cancellation) async {
    cancellation.throwIfCancelled();
    await Directory(binding.rootPath).create(recursive: true);
  }

  @override
  Future<WorkspaceEntry> stat(
    String path,
    RunCancellation cancellation, {
    bool withDigest = false,
  }) async {
    cancellation.throwIfCancelled();
    final location = await _path(path, exists: false);
    final s = await FileStat.stat(location);
    final type = s.type == FileSystemEntityType.file
        ? 'file'
        : s.type == FileSystemEntityType.directory
        ? 'directory'
        : 'missing';
    return WorkspaceEntry(
      path,
      type,
      s.size,
      digest: withDigest && type == 'file' && s.size <= 64 * 1024 * 1024
          ? (await sha256.bind(File(location).openRead()).first).toString()
          : null,
    );
  }

  @override
  Future<List<WorkspaceEntry>> list(
    String path,
    RunCancellation cancellation,
  ) async {
    final result = <WorkspaceEntry>[];
    await for (final entry in Directory(
      await _path(path),
    ).list(followLinks: false)) {
      cancellation.throwIfCancelled();
      result.add(
        WorkspaceEntry(
          p.relative(entry.path, from: binding.rootPath),
          entry is Directory
              ? 'directory'
              : entry is File
              ? 'file'
              : 'link',
          entry is File ? await entry.length() : 0,
        ),
      );
    }
    result.sort((a, b) => a.path.compareTo(b.path));
    return result;
  }

  @override
  Future<FileTextPage> readPage(
    String path,
    Map<String, dynamic> arguments,
    RunCancellation cancellation,
  ) async => readFilePage(File(await _path(path)), arguments, cancellation);
  @override
  Future<void> exportPath(
    String path,
    String localPath,
    RunCancellation cancellation,
  ) async => copyWorkspacePath(await _path(path), localPath, cancellation);
  @override
  Future<void> importPath(
    String path,
    String localPath,
    RunCancellation cancellation, {
    String? expectedDigest,
  }) async {
    final target = await _path(path, exists: false);
    await copyWorkspacePath(
      localPath,
      target,
      cancellation,
      beforeCommit: (destination) async {
        await _path(
          p.relative(destination, from: binding.rootPath),
          exists: false,
        );
        if (expectedDigest != null &&
            (await stat(path, cancellation, withDigest: true)).digest !=
                expectedDigest) {
          throw const WorkspaceFailure('fileChanged', '文件在编辑期间已改变，请重新读取后编辑');
        }
      },
    );
  }

  @override
  Future<void> deleteRoot(RunCancellation cancellation) async {
    cancellation.throwIfCancelled();
    final root = Directory(binding.rootPath);
    if (await root.exists()) await root.delete(recursive: true);
  }
}

class TermuxWorkspaceFileAccess extends WorkspaceFileAccess {
  TermuxWorkspaceFileAccess(
    super.binding,
    super.staging, {
    required this.driver,
    required this.processes,
    required this.beforeWrite,
    this.ownerId,
  });
  final CommandChannelDriver driver;
  final ProcessDriver processes;
  final Future<void> Function(int uid) beforeWrite;
  final String? ownerId;
  Future<Map<String, dynamic>> _call(
    WorkspaceFileOperation operation,
    String path,
    RunCancellation cancellation, {
    int offset = 0,
    int limit = 2000,
    String? localPath,
    String? expectedDigest,
    bool writing = false,
  }) async {
    final identity = binding.termux;
    if (identity == null) {
      throw const WorkspaceFailure(
        'environmentMissing',
        'Termux 未启用或尚未就绪，请检查环境设置',
      );
    }
    cancellation.throwIfCancelled();
    if (writing) await beforeWrite(identity.uid);
    final owner = ownerId ?? 'files-${generateId()}';
    try {
      await processes.beginTask(owner, 'Termux 文件操作');
      return await driver.workspaceFile(
        WorkspaceFileRequest(
          ownerId: owner,
          callId: generateId(),
          workspaceId: binding.id,
          revision: identity.revision,
          uid: identity.uid,
          operation: operation,
          path: path,
          offset: offset,
          limit: limit,
          localPath: localPath,
          expectedDigest: expectedDigest,
        ),
        cancellation,
      );
    } finally {
      if (ownerId == null) {
        try {
          await driver.endOwner(owner);
        } finally {
          await processes.endTask(owner);
        }
      }
    }
  }

  @override
  Future<void> ensure(RunCancellation cancellation) async {
    await _call(
      WorkspaceFileOperation.ensure,
      '.',
      cancellation,
      writing: true,
    );
  }

  @override
  Future<WorkspaceEntry> stat(
    String path,
    RunCancellation cancellation, {
    bool withDigest = false,
  }) async {
    final result = await _call(
      WorkspaceFileOperation.stat,
      path,
      cancellation,
      offset: withDigest ? 1 : 0,
    );
    return WorkspaceEntry(
      path,
      result['type'] as String,
      result['size'] as int,
      digest: result['digest'] as String?,
    );
  }

  @override
  Future<List<WorkspaceEntry>> list(
    String path,
    RunCancellation cancellation,
  ) async {
    final entries = <WorkspaceEntry>[];
    var offset = 0;
    while (true) {
      final result = await _call(
        WorkspaceFileOperation.list,
        path,
        cancellation,
        offset: offset,
      );
      for (final entry in (result['entries'] as List? ?? const [])) {
        final row = entry as Map;
        entries.add(
          WorkspaceEntry(
            p.posix.normalize(p.posix.join(path, row['name'] as String)),
            row['type'] as String,
            row['size'] as int,
          ),
        );
      }
      final next = result['nextOffset'] as int? ?? 0;
      if (next >= (result['total'] as int? ?? 0)) break;
      if (next <= offset) {
        throw const WorkspaceFailure('invalidResponse', '目录分页没有前进');
      }
      offset = next;
    }
    return entries;
  }

  @override
  Future<FileTextPage> readPage(
    String path,
    Map<String, dynamic> arguments,
    RunCancellation cancellation,
  ) async {
    final result = await _call(
      WorkspaceFileOperation.readPage,
      path,
      cancellation,
      offset: arguments['offset'] as int? ?? 1,
      limit: (arguments['limit'] as int? ?? 2000).clamp(1, 2000),
    );
    return FileTextPage(
      utf8.decode(base64Decode(result['text'] as String)),
      result['startLine'] as int,
      result['lineCount'] as int,
      result['hasMore'] as bool,
    );
  }

  @override
  Future<void> exportPath(
    String path,
    String localPath,
    RunCancellation cancellation,
  ) async {
    // The native bridge only accepts app-owned staging, never arbitrary host paths.
    await _call(
      WorkspaceFileOperation.exportPath,
      path,
      cancellation,
      localPath: localPath,
    );
  }

  @override
  Future<void> importPath(
    String path,
    String localPath,
    RunCancellation cancellation, {
    String? expectedDigest,
  }) async {
    final temp = await temporary();
    try {
      final staged = p.join(temp.path, 'payload');
      try {
        await copyWorkspacePath(localPath, staged, cancellation);
      } on WorkspaceFailure catch (error) {
        if (error.cancelled) throw const ToolCancelled();
        throw WorkspaceFailure(error.code, error.message);
      }
      await _call(
        WorkspaceFileOperation.importPath,
        path,
        cancellation,
        localPath: staged,
        expectedDigest: expectedDigest,
        writing: true,
      );
    } finally {
      await temp.delete(recursive: true);
    }
  }

  @override
  Future<void> deleteRoot(RunCancellation cancellation) async {
    await _call(WorkspaceFileOperation.deleteRoot, '.', cancellation);
  }
}

/// Explicit transfers merge directories, atomically replace each file, and never delete extras.
Future<void> copyWorkspacePath(
  String source,
  String destination,
  RunCancellation cancellation, {
  Future<void> Function(String destination)? beforeCommit,
}) async {
  final completed = <String>[];
  var total = 0, count = 0;
  Future<void> preflight(String from, String to) async {
    cancellation.throwIfCancelled();
    if (++count > 1000) {
      throw const WorkspaceFailure('transferLimit', '单次复制最多 1000 项');
    }
    final type = await FileSystemEntity.type(from, followLinks: false);
    final target = await FileSystemEntity.type(to, followLinks: false);
    if (type != FileSystemEntityType.file &&
        type != FileSystemEntityType.directory) {
      throw const WorkspaceFailure('invalidPath', '复制不支持符号链接或特殊文件');
    }
    if (target != FileSystemEntityType.notFound && target != type) {
      throw const WorkspaceFailure('typeConflict', '目标文件与目录类型冲突');
    }
    if (type == FileSystemEntityType.directory) {
      await for (final entry in Directory(from).list(followLinks: false)) {
        await preflight(entry.path, p.join(to, p.basename(entry.path)));
      }
    } else {
      final size = await File(from).length();
      total += size;
      if (size > 64 * 1024 * 1024 || total > 256 * 1024 * 1024) {
        throw const WorkspaceFailure(
          'transferLimit',
          '单文件上限 64 MiB，单次复制上限 256 MiB',
        );
      }
    }
  }

  Future<void> visit(String from, String to) async {
    cancellation.throwIfCancelled();
    if (++count > 1000) {
      throw const WorkspaceFailure('transferLimit', '单次复制最多 1000 项');
    }
    final type = await FileSystemEntity.type(from, followLinks: false);
    final targetType = await FileSystemEntity.type(to, followLinks: false);
    if (type != FileSystemEntityType.file &&
        type != FileSystemEntityType.directory) {
      throw const WorkspaceFailure('invalidPath', '复制不支持符号链接或特殊文件');
    }
    if (targetType != FileSystemEntityType.notFound && targetType != type) {
      throw const WorkspaceFailure('typeConflict', '目标文件与目录类型冲突');
    }
    if (type == FileSystemEntityType.directory) {
      await Directory(to).create(recursive: true);
      completed.add(to == destination ? '' : p.relative(to, from: destination));
      await for (final entry in Directory(from).list(followLinks: false)) {
        await visit(entry.path, p.join(to, p.basename(entry.path)));
      }
    } else {
      final file = File(from);
      final size = await file.length();
      total += size;
      if (size > 64 * 1024 * 1024 || total > 256 * 1024 * 1024) {
        throw const WorkspaceFailure(
          'transferLimit',
          '单文件上限 64 MiB，单次复制上限 256 MiB',
        );
      }
      await File(to).parent.create(recursive: true);
      final temp = File('$to.${generateId()}.part');
      final sink = await temp.open(mode: FileMode.write);
      var copied = 0;
      var closed = false;
      try {
        await for (final bytes in file.openRead()) {
          cancellation.throwIfCancelled();
          copied += bytes.length;
          if (copied > size) {
            throw const WorkspaceFailure('fileChanged', '复制期间源文件已改变');
          }
          await sink.writeFrom(bytes);
        }
        await sink.flush();
        await sink.close();
        closed = true;
        if (copied != size) {
          throw const WorkspaceFailure('fileChanged', '复制期间源文件已改变');
        }
        final copiedDigest = await sha256.bind(temp.openRead()).first;
        final sourceDigest = await sha256.bind(file.openRead()).first;
        if (copiedDigest != sourceDigest) {
          throw const WorkspaceFailure('fileChanged', '复制期间源文件已改变');
        }
        await beforeCommit?.call(to);
        cancellation.throwIfCancelled();
        await temp.rename(to);
        completed.add(
          to == destination ? '' : p.relative(to, from: destination),
        );
      } finally {
        if (!closed) await sink.close();
        if (await temp.exists()) await temp.delete();
      }
    }
  }

  await preflight(source, destination);
  total = 0;
  count = 0;
  try {
    await visit(source, destination);
  } on ToolCancelled {
    throw WorkspaceFailure(
      'cancelled',
      '复制已停止，已提交的文件保留',
      completedPaths: completed,
      cancelled: true,
    );
  } on WorkspaceFailure catch (error) {
    throw WorkspaceFailure(
      error.code,
      error.message,
      completedPaths: completed,
    );
  } on FileSystemException catch (error) {
    throw WorkspaceFailure(
      'copyFailed',
      '文件复制失败：${error.message}',
      completedPaths: completed,
    );
  }
}
