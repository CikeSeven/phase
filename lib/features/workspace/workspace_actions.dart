import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';

import '../execution/execution_api.g.dart';

import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/error/failure.dart';
import '../../../core/utils/id.dart';
import '../../../data/models/attachment.dart';
import '../../../data/models/workspace.dart';
import '../../../data/repositories/workspace_repository.dart';
import '../tools/tool.dart';
import 'workspace_files.dart';

part 'workspace_actions.g.dart';

@riverpod
Future<Workspace?> workspace(Ref ref, String id) async =>
    (await ref.watch(workspaceRepositoryProvider.future)).get(id);
@riverpod
Future<List<(String, int)>> workspaceEntries(
  Ref ref,
  String id,
  String path,
) async {
  final repository = await ref.watch(workspaceRepositoryProvider.future);
  final value = await repository.get(id);
  if (value == null || value.deleting) throw const OperationFailure('工作区已删除');
  return WorkspaceFiles(repository).list(value, path);
}

@riverpod
class WorkspaceActions extends _$WorkspaceActions {
  @override
  AsyncValue<void> build() => const AsyncData(null);
  Future<T?> perform<T>(Future<T?> Function() operation) async {
    if (state.isLoading) return null;
    state = const AsyncLoading();
    try {
      final result = await operation();
      if (ref.mounted) state = const AsyncData(null);
      return result;
    } catch (error, stack) {
      if (ref.mounted) {
        state = AsyncError(
          error is Failure ? error : const OperationFailure('工作区文件操作失败，请重试'),
          stack,
        );
      }
      return null;
    }
  }

  Future<Attachment> preview(String id, String relative) async {
    final repository = await ref.read(workspaceRepositoryProvider.future);
    final value = await repository.get(id);
    if (value == null || value.deleting) throw const OperationFailure('工作区已删除');
    final path = await workspacePath(value.rootPath, relative);
    return Attachment(
      id: generateId(),
      kind: AttachmentKind.artifact,
      name: p.basename(relative),
      mimeType: lookupMimeType(relative) ?? 'application/octet-stream',
      size: await File(path).length(),
      localPath: path,
      createdAt: DateTime.now(),
    );
  }

  Future<void> importFile(String id) async {
    await perform(() async {
      final repository = await ref.read(workspaceRepositoryProvider.future);
      if (repository.inUse(id)) {
        throw const OperationFailure('工作区正在使用，请结束任务后导入');
      }
      final value = await repository.get(id);
      if (value == null || value.deleting) {
        throw const OperationFailure('工作区已删除');
      }
      final picked = await FilePicker.pickFiles();
      final file = picked.firstOrNull;
      if (file == null) return null;
      if (file.path == null) throw const OperationFailure('无法读取所选文件');
      // 文件选择器打开期间会话可能已删除或开始运行，导入前重新取得租约。
      final lease = await repository.acquire(id);
      try {
        await WorkspaceFiles(repository).importAttachment(
          value,
          Attachment(
            id: generateId(),
            kind: AttachmentKind.artifact,
            name: file.name,
            mimeType: lookupMimeType(file.name) ?? 'application/octet-stream',
            size: file.lengthSync() ?? await file.length(),
            localPath: file.path!,
            createdAt: DateTime.now(),
          ),
          RunCancellation(),
        );
      } finally {
        lease.close();
      }
      if (ref.mounted) ref.invalidate(workspaceEntriesProvider);
      return true;
    });
  }

  Future<void> exportFile(String id, String relative) async {
    await perform(() async {
      final file = await preview(id, relative);
      if (file.size > WorkspaceFiles.maxCopyBytes) {
        throw const OperationFailure('单次导出文件上限为 64 MiB');
      }
      try {
        await ExecutionSetupApi().exportWorkspaceFile(
          file.localPath,
          file.name,
          file.mimeType,
        );
      } on PlatformException catch (error) {
        throw OperationFailure(
          error.code == 'exportFailed'
              ? '文件导出未完整保存，请检查目标位置后重试'
              : '无法导出文件，请检查工作区文件和目标授权',
        );
      }
      return true;
    });
  }
}
