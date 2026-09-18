import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/error/failure.dart';
import '../../../core/utils/id.dart';
import '../execution/execution_api.g.dart';
import '../tools/tool.dart';
import 'skill_package.dart';

part 'skill_import_source.g.dart';

class SkillImportSource {
  Future<PickedSkill?> pick(bool zip, RunCancellation cancellation) async {
    if (zip) {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );
      cancellation.throwIfCancelled();
      if (result.isEmpty) return null;
      final file = result.single;
      if ((file.lengthSync() ?? await file.length()) >
          SkillLimits.archiveBytes) {
        throw const SkillFailure('packageTooLarge', 'ZIP 超过 16 MiB 导入上限');
      }
      if (file.path == null) {
        throw const SkillFailure('fileAccess', '无法读取所选 ZIP');
      }
      return PickedSkill(file.path!, true, file.name);
    }
    final api = ExecutionSetupApi();
    final id = generateId();
    var finished = false;
    Object? cancelError;
    final cancelled = cancellation.whenCancelled.then((_) async {
      if (finished) return;
      try {
        await api.cancelSkillImport(id);
      } catch (error) {
        cancelError = error;
      }
    });
    try {
      final result = await api.importSkillDirectory(
        SkillDirectoryImport(
          id: id,
          maxEntries: SkillLimits.entries,
          maxBytes: SkillLimits.totalBytes,
          maxFileBytes: SkillLimits.fileBytes,
          maxDepth: SkillLimits.depth,
          maxPathLength: SkillLimits.pathLength,
        ),
      );
      if (cancellation.isCancelled) {
        await cancelled;
        if (result != null) {
          await Directory(result.path).delete(recursive: true);
        }
        if (cancelError != null) {
          throw const SkillFailure('cancelFailed', '目录导入已结束，但未能发送停止请求');
        }
        throw const ToolCancelled();
      }
      return result == null
          ? null
          : PickedSkill(result.path, false, result.name, temporary: true);
    } on PlatformException catch (error) {
      if (error.code == 'cancelled') throw const ToolCancelled();
      throw SkillFailure(error.code, switch (error.code) {
        'invalidDirectory' => '目录含无效或重复路径，或超过 Skill 导入上限',
        'permissionRequired' => '没有读取所选目录的权限',
        'cleanupFailed' => '目录导入未完成，临时副本清理失败，请重试',
        'fileAccess' => '无法复制目录文件，请检查文件访问权限和可用空间',
        _ => '无法打开目录选择器，请返回相月后重试',
      });
    } finally {
      finished = true;
    }
  }
}

class PickedSkill {
  const PickedSkill(this.path, this.zip, this.name, {this.temporary = false});
  final String path;
  final bool zip;
  final String name;
  final bool temporary;
  Future<void> close() async {
    if (!temporary) return;
    try {
      if (await Directory(path).exists()) {
        await Directory(path).delete(recursive: true);
      }
    } on FileSystemException {
      throw const SkillFailure('cleanupFailed', 'Skill 目录副本清理失败，请重试导入');
    }
  }
}

@riverpod
SkillImportSource skillImportSource(Ref ref) => SkillImportSource();
