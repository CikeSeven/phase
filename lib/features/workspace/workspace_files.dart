import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../../../core/error/failure.dart';
import '../../../core/utils/id.dart';
import '../../../data/models/attachment.dart';
import '../../../data/models/skill_installation.dart';
import '../../../data/models/workspace.dart';
import '../../../data/repositories/workspace_repository.dart';
import '../tools/tool.dart';

/// App file operations validate lexical paths and actual link targets. Shell
/// remains an app-UID process and is not constrained by these file checks.
Future<String> workspacePath(
  String root,
  String relative, {
  bool mustExist = true,
}) async {
  if (relative.contains('\u0000') ||
      relative.contains('\\') ||
      p.posix.isAbsolute(relative) ||
      p.posix.split(relative).contains('..')) {
    throw const WorkspaceFailure('invalidPath', '请使用工作区内的相对路径');
  }
  final base = p.normalize(p.absolute(root));
  if (await Directory(base).resolveSymbolicLinks() != base) {
    throw const WorkspaceFailure('invalidPath', '工作区目录已改变');
  }
  final normalized = p.posix.normalize(relative);
  var path = base;
  for (final component in p.posix.split(normalized)) {
    if (component == '.') continue;
    path = p.join(path, component);
    final type = await FileSystemEntity.type(path, followLinks: false);
    if (type == FileSystemEntityType.link) {
      final resolved = await Link(path).resolveSymbolicLinks();
      if (!p.isWithin(base, resolved)) {
        throw const WorkspaceFailure('invalidPath', '文件链接越出工作区');
      }
    } else if (mustExist && type == FileSystemEntityType.notFound) {
      throw const WorkspaceFailure('fileMissing', '工作区文件已不存在');
    }
  }
  return path;
}

class WorkspaceFiles {
  WorkspaceFiles(this.repository);
  final WorkspaceRepository repository;
  static const maxCopyBytes = 64 * 1024 * 1024;

  Future<String> importAttachment(
    Workspace workspace,
    Attachment attachment,
    RunCancellation cancellation,
  ) async {
    final relative = 'imports/${attachment.id}/${p.basename(attachment.name)}';
    final destination = await workspacePath(
      workspace.rootPath,
      relative,
      mustExist: false,
    );
    try {
      final source = File(attachment.localPath);
      if (await source.length() > maxCopyBytes) {
        throw const WorkspaceFailure('fileTooLarge', '单次导入文件上限为 64 MiB');
      }
      await File(destination).parent.create(recursive: true);
      if (!await File(destination).exists()) {
        await _copy(source, File(destination), cancellation);
      }
      await repository.recordCopy(workspace.id, relative, {
        'kind': 'attachment',
        'id': attachment.id,
        'name': attachment.name,
      });
      return '/workspace/$relative';
    } on FileSystemException {
      throw WorkspaceFailure('importFailed', '无法复制附件「${attachment.name}」到工作区');
    }
  }

  Future<String> prepareSkill(
    WorkspaceSnapshot workspace,
    SkillSnapshot skill,
    RunCancellation cancellation, {
    required Future<void> Function() checkPermission,
  }) async {
    final relative = '.skills/${skill.id}/${skill.revision}-${generateId()}';
    final path = await workspacePath(
      workspace.rootPath,
      relative,
      mustExist: false,
    );
    final destination = Directory(path);
    final staging = Directory('$path.staging');
    try {
      await checkPermission();
      var total = 0;
      for (final entry in skill.resources.entries) {
        cancellation.throwIfCancelled();
        final sourcePath = await workspacePath(skill.installedPath, entry.key);
        final source = File(sourcePath);
        if (await source.length() != entry.value.size ||
            entry.value.size > 4 * 1024 * 1024) {
          throw const WorkspaceFailure('skillChanged', 'Skill 固定版本资源大小已改变');
        }
        final bytes = await source.readAsBytes();
        total += bytes.length;
        if (bytes.length != entry.value.size ||
            sha256.convert(bytes).toString() != entry.value.digest ||
            total > 32 * 1024 * 1024) {
          throw const WorkspaceFailure('skillChanged', 'Skill 固定版本资源已改变，请重新导入');
        }
        final file = File(p.join(staging.path, entry.key));
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes);
      }
      await checkPermission();
      cancellation.throwIfCancelled();
      await staging.rename(destination.path);
      await repository.recordCopy(workspace.id, relative, {
        'kind': 'skill',
        'id': skill.id,
        'revision': skill.revision,
      });
      return '/workspace/$relative';
    } on FileSystemException {
      throw const WorkspaceFailure(
        'skillCopyFailed',
        'Skill 工作区副本保存失败，请检查可用空间',
      );
    } finally {
      if (await staging.exists()) await staging.delete(recursive: true);
    }
  }

  Future<List<(String, int)>> list(
    Workspace workspace, [
    String relative = '.',
  ]) async {
    final directory = Directory(
      await workspacePath(workspace.rootPath, relative),
    );
    final entries = <(String, int)>[];
    await for (final entity in directory.list(followLinks: false)) {
      if (entries.length == 1000) {
        throw const WorkspaceFailure('directoryLimit', '目录条目超过 1000，请进入子目录查看');
      }
      if (entity is Link) continue;
      final name = p.relative(entity.path, from: workspace.rootPath);
      entries.add((
        name,
        entity is Directory ? -1 : (await entity.stat()).size,
      ));
    }
    entries.sort((a, b) => a.$1.compareTo(b.$1));
    return entries;
  }

  Future<Attachment> artifact(
    WorkspaceSnapshot workspace,
    String relative,
    ToolContext context,
    RunCancellation cancellation,
  ) async {
    final source = File(await workspacePath(workspace.rootPath, relative));
    if (await source.length() > maxCopyBytes) {
      throw const WorkspaceFailure('artifactLimit', '单个工作区产物上限为 64 MiB');
    }
    final destination = File(
      p.join(
        context.artifactsDirectory,
        '${generateId()}-${p.basename(relative)}',
      ),
    );
    try {
      await destination.parent.create(recursive: true);
      await _copy(source, destination, cancellation);
      return await context.storage.registerArtifact(
        conversationId: context.conversationId,
        path: destination.path,
        name: p.basename(relative),
      );
    } on FileSystemException {
      throw WorkspaceFailure('artifactFailed', '无法保存工作区产物「$relative」');
    }
  }

  Future<void> _copy(
    File source,
    File target,
    RunCancellation cancellation,
  ) async {
    final temp = File('${target.path}.${generateId()}.tmp');
    final output = await temp.open(mode: FileMode.write);
    var size = 0;
    try {
      await for (final bytes in source.openRead()) {
        cancellation.throwIfCancelled();
        size += bytes.length;
        if (size > maxCopyBytes) {
          throw const WorkspaceFailure('fileTooLarge', '文件复制超过 64 MiB 上限');
        }
        await output.writeFrom(bytes);
      }
    } catch (_) {
      await output.close();
      if (await temp.exists()) await temp.delete();
      rethrow;
    }
    await output.close();
    await temp.rename(target.path);
  }

  Future<Map<String, String>> outputs(WorkspaceSnapshot workspace) async {
    final result = <String, String>{};
    final path = await workspacePath(
      workspace.rootPath,
      'output',
      mustExist: false,
    );
    if (!await Directory(path).exists()) return result;
    var total = 0;
    await for (final entity in Directory(
      path,
    ).list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final relative = p.relative(entity.path, from: workspace.rootPath);
      await workspacePath(workspace.rootPath, relative);
      total += await entity.length();
      if (result.length >= 100 || total > maxCopyBytes) {
        throw const WorkspaceFailure(
          'artifactLimit',
          'output 目录超过 100 个文件或 64 MiB，请整理后再导出',
        );
      }
      result[relative] = (await sha256.bind(entity.openRead()).first)
          .toString();
    }
    return result;
  }
}

String workspacePrompt(WorkspaceSnapshot? workspace) {
  if (workspace == null) return '';
  final files =
      '\n\n本会话独立工作区：${jsonEncode(workspace.name)}，路径 /workspace。文件随会话持久保存，删除会话时一并删除，不与其他会话共享。文件工具可直接访问 /workspace 下的路径。';
  if (!workspace.linuxAvailable) {
    return '$files Ubuntu 环境未就绪，当前无法执行 shell 命令。';
  }
  return '$files Ubuntu ${workspace.environmentRevision}。命令默认在 /workspace 执行；每次 shell 的变量与 cd 不保留。将要返回的文件写入 /workspace/output，调用后会保存为会话产物。其他文件留在工作区；本会话附件在执行前复制到 /workspace/imports/<附件ID>/<文件名>。Skill 脚本先用 prepare_skill 复制固定版本，再通过 shell 显式调用解释器；没有的依赖如实返回缺失，不自动安装。';
}
