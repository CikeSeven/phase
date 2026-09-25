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
    RunCancellation cancellation, {
    WorkspaceSnapshot? binding,
    String? ownerId,
  }) async {
    final snapshot = binding ?? await repository.snapshot(workspace.id);
    final access = repository.files(snapshot, ownerId: ownerId);
    final relative = 'imports/${attachment.id}/${p.basename(attachment.name)}';
    try {
      if (await File(attachment.localPath).length() > maxCopyBytes) {
        throw const WorkspaceFailure('fileTooLarge', '单次导入文件上限为 64 MiB');
      }
      if ((await access.stat(relative, cancellation)).type == 'missing') {
        await access.importPath(relative, attachment.localPath, cancellation);
      }
      await repository.recordCopy(workspace.id, relative, {
        'kind': 'attachment',
        'id': attachment.id,
        'name': attachment.name,
      }, environment: snapshot.primaryEnvironment);
      return access.executionPath(relative);
    } on FileSystemException {
      throw WorkspaceFailure('importFailed', '无法复制附件「${attachment.name}」到工作区');
    }
  }

  Future<String> prepareSkill(
    WorkspaceSnapshot workspace,
    SkillSnapshot skill,
    RunCancellation cancellation, {
    required Future<void> Function() checkPermission,
    String? ownerId,
  }) async {
    final access = repository.files(workspace, ownerId: ownerId);
    final temporary = await access.temporary();
    final staging = Directory(p.join(temporary.path, 'skill'));
    final relative = '.skills/${skill.id}/${skill.revision}-${generateId()}';
    try {
      await checkPermission();
      await staging.create();
      var total = 0;
      for (final entry in skill.resources.entries) {
        cancellation.throwIfCancelled();
        final source = File(
          await workspacePath(skill.installedPath, entry.key),
        );
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
      await access.importPath(relative, staging.path, cancellation);
      await checkPermission();
      await repository.recordCopy(workspace.id, relative, {
        'kind': 'skill',
        'id': skill.id,
        'revision': skill.revision,
      }, environment: workspace.primaryEnvironment);
      return access.executionPath(relative);
    } on FileSystemException {
      throw const WorkspaceFailure(
        'skillCopyFailed',
        'Skill 工作区副本保存失败，请检查可用空间',
      );
    } finally {
      await temporary.delete(recursive: true);
    }
  }

  Future<List<(String, int)>> list(
    Workspace workspace, [
    String relative = '.',
  ]) async {
    final access = repository.files(await repository.snapshot(workspace.id));
    final entries = await access.list(relative, RunCancellation());
    if (entries.length > 1000) {
      throw const WorkspaceFailure('directoryLimit', '目录条目超过 1000，请进入子目录查看');
    }
    return [
      for (final entry in entries)
        if (entry.type == 'file' || entry.type == 'directory')
          (entry.path, entry.type == 'directory' ? -1 : entry.size),
    ];
  }

  Future<Attachment> artifact(
    WorkspaceSnapshot workspace,
    String relative,
    ToolContext context,
    RunCancellation cancellation,
  ) async {
    final access = repository.files(workspace, ownerId: context.runId);
    final temp = await access.temporary();
    final destination = File(
      p.join(
        context.artifactsDirectory,
        '${generateId()}-${p.basename(relative)}',
      ),
    );
    try {
      final staged = p.join(temp.path, 'artifact');
      await access.exportPath(relative, staged, cancellation);
      await destination.parent.create(recursive: true);
      await File(staged).copy(destination.path);
      return await context.storage.registerArtifact(
        conversationId: context.conversationId,
        path: destination.path,
        name: p.basename(relative),
      );
    } on FileSystemException {
      throw WorkspaceFailure('artifactFailed', '无法保存工作区产物「$relative」');
    } finally {
      await temp.delete(recursive: true);
    }
  }

  Future<Map<String, String>> outputs(
    WorkspaceSnapshot workspace, {
    String? ownerId,
    RunCancellation? cancellation,
  }) async {
    final access = repository.files(workspace, ownerId: ownerId);
    final cancel = cancellation ?? RunCancellation();
    final result = <String, String>{};
    var total = 0;
    Future<void> visit(String path) async {
      for (final entry in await access.list(path, cancel)) {
        if (path == '.' &&
            {'imports', '.skills'}.contains(p.basename(entry.path))) {
          continue;
        }
        if (entry.type == 'directory') {
          await visit(entry.path);
        } else if (entry.type == 'file') {
          total += entry.size;
          if (result.length >= 100 || total > maxCopyBytes) {
            throw const WorkspaceFailure(
              'artifactLimit',
              '工作区文件超过自动收集上限（100 个文件 / 64 MiB），原文件保留在工作区',
            );
          }
          final digest = (await access.stat(
            entry.path,
            cancel,
            withDigest: true,
          )).digest;
          if (digest == null || digest.isEmpty) {
            throw const WorkspaceFailure('fileChanged', '产物在收集期间已改变');
          }
          result[entry.path] = digest;
        }
      }
    }

    await visit('.');
    return result;
  }

  Future<void> transfer(
    WorkspaceSnapshot workspace,
    String path,
    bool toOther,
    RunCancellation cancellation, {
    String? ownerId,
  }) async {
    final other = workspace.select(workspace.primaryEnvironment.other);
    final from = repository.files(
      toOther ? workspace : other,
      ownerId: ownerId,
    );
    final to = repository.files(toOther ? other : workspace, ownerId: ownerId);
    final temporary = await from.temporary();
    try {
      final staged = p.join(temporary.path, 'transfer');
      try {
        await from.exportPath(path, staged, cancellation);
      } on WorkspaceFailure catch (error) {
        if (error.cancelled) throw const ToolCancelled();
        throw WorkspaceFailure(error.code, error.message);
      }
      try {
        await to.importPath(path, staged, cancellation);
      } on WorkspaceFailure catch (error) {
        final completed = [
          for (final item in error.completedPaths)
            item.isEmpty ? path : p.posix.join(path, item),
        ];
        for (final item in completed) {
          await repository.recordCopy(workspace.id, item, {
            'kind': 'workspace',
            'environment': from.binding.primaryEnvironment.name,
            'path': item,
          }, environment: to.binding.primaryEnvironment);
        }
        throw WorkspaceFailure(
          error.code,
          error.message,
          completedPaths: completed,
          cancelled: error.cancelled,
        );
      }
      await repository.recordCopy(workspace.id, path, {
        'kind': 'workspace',
        'environment': from.binding.primaryEnvironment.name,
        'path': path,
      }, environment: to.binding.primaryEnvironment);
    } finally {
      await temporary.delete(recursive: true);
    }
  }
}

String workspacePrompt(WorkspaceSnapshot? workspace) {
  if (workspace == null) return '';
  return '\n\n本会话主环境：${workspace.primaryEnvironment.label}，独立工作区 ${jsonEncode(workspace.name)}。'
      '文件工具使用相对路径；shell 默认目录 ${workspace.executionRoot}。'
      'Ubuntu 与 Termux 的会话文件各自保存，workspace_transfer 显式复制，不自动同步。'
      '${workspace.executable ? '附件在执行前复制到 imports/<附件ID>/<原文件名>。' : '所选命令环境未就绪，不要更换身份重试。'}'
      '${workspace.primaryEnvironment == PrimaryEnvironment.termux ? 'Termux 依赖由用户管理，缺失解释器需如实报告。' : ''}'
      '本地 MCP stdio 始终使用 Ubuntu 的服务专属目录，不自动共享本会话文件。';
}
