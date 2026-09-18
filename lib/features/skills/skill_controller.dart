import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/error/failure.dart';
import '../../../core/utils/logger.dart';
import '../../../data/models/skill_installation.dart';
import '../../../data/repositories/skill_repository.dart';
import '../tools/tool.dart';
import 'skill_import_source.dart';
import 'skill_package.dart';

part 'skill_controller.g.dart';

class SkillImportState {
  const SkillImportState({
    this.package,
    this.busy = false,
    this.phase = '',
    this.error,
  });
  final PreparedSkill? package;
  final bool busy;
  final String phase;
  final String? error;
}

@riverpod
class SkillImportController extends _$SkillImportController {
  RunCancellation? _cancellation;
  PreparedSkill? _prepared;
  bool _working = false;

  @override
  SkillImportState build(String? replaceId) {
    ref.onDispose(() {
      _cancellation?.cancel();
      final prepared = _prepared;
      if (!_working) _prepared = null;
      if (!_working && prepared != null) {
        unawaited(
          prepared.discard().catchError((Object _) {
            AppLogger.warning('Skill 临时文件清理失败，下次导入时重试');
          }),
        );
      }
    });
    return const SkillImportState();
  }

  void cancel() => _cancellation?.cancel();

  Future<void> pick(bool zip) async {
    if (_working) return;
    _working = true;
    final cancellation = RunCancellation();
    _cancellation = cancellation;
    final source = ref.read(skillImportSourceProvider);
    state = SkillImportState(
      package: _prepared,
      busy: true,
      phase: '选择并检查 Skill',
    );
    PreparedSkill? next;
    PickedSkill? picked;
    try {
      final repository = await ref.read(skillRepositoryProvider.future);
      cancellation.throwIfCancelled();
      picked = await source.pick(zip, cancellation);
      if (picked == null) return;
      if (ref.mounted) {
        state = SkillImportState(
          package: _prepared,
          busy: true,
          phase: '复制并校验文件',
        );
      }
      next = await repository.packages.prepare(
        picked.path,
        zip: picked.zip,
        sourceLabel: picked.name,
        cancellation: cancellation,
      );
      cancellation.throwIfCancelled();
      await _prepared?.discard();
      _prepared = next;
      next = null;
    } on ToolCancelled {
      if (ref.mounted) {
        state = SkillImportState(package: _prepared, phase: '已取消导入');
      }
    } catch (error) {
      if (ref.mounted) {
        state = SkillImportState(
          package: _prepared,
          error: error is Failure ? error.userMessage : 'Skill 导入失败，请重试',
        );
      }
    } finally {
      try {
        await next?.discard();
        await picked?.close();
      } catch (error) {
        if (ref.mounted) {
          state = SkillImportState(
            package: _prepared,
            error: error is Failure ? error.userMessage : '临时文件清理失败，请重试',
          );
        }
      }
      if (!ref.mounted) {
        try {
          await _prepared?.discard();
        } catch (_) {
          AppLogger.warning('Skill 临时文件清理失败，下次导入时重试');
        }
        _prepared = null;
      }
      _working = false;
      _cancellation = null;
      if (ref.mounted) {
        state = SkillImportState(
          package: _prepared,
          phase: state.phase,
          error: state.error,
        );
      }
    }
  }

  Future<SkillInstallation?> install() async {
    if (_working || _prepared == null) return null;
    _working = true;
    final package = _prepared!;
    final cancellation = RunCancellation();
    _cancellation = cancellation;
    state = SkillImportState(package: package, busy: true, phase: '保存安装版本');
    SkillInstallation? installed;
    try {
      final repository = await ref.read(skillRepositoryProvider.future);
      installed = await repository.install(
        package,
        cancellation,
        replaceId: replaceId,
      );
      _prepared = null;
      await package.discard();
      await repository.collectGarbage();
    } on ToolCancelled {
      if (ref.mounted) {
        state = SkillImportState(package: _prepared, phase: '已取消安装');
      }
    } catch (error) {
      if (ref.mounted) {
        state = SkillImportState(
          package: _prepared,
          error:
              '${installed == null ? '' : '已安装；'}${error is Failure ? error.userMessage : 'Skill 安装失败，请重试'}',
        );
      }
    } finally {
      if (!ref.mounted) {
        try {
          await _prepared?.discard();
        } catch (_) {
          AppLogger.warning('Skill 临时文件清理失败，下次导入时重试');
        }
        _prepared = null;
      }
      _working = false;
      _cancellation = null;
      if (ref.mounted) {
        state = SkillImportState(
          package: _prepared,
          phase: installed == null ? state.phase : '已安装',
          error: state.error,
        );
      }
    }
    return installed;
  }
}

@riverpod
class SkillController extends _$SkillController {
  bool _working = false;
  @override
  Future<SkillInstallation?> build(String id) async {
    final repository = await ref.watch(skillRepositoryProvider.future);
    ref.watch(skillInstallationsProvider);
    return repository.get(id);
  }

  Future<void> setEnabled(bool enabled) =>
      _operate((repository) => repository.setEnabled(id, enabled));
  Future<void> delete() => _operate((repository) => repository.delete(id));
  Future<void> _operate(Future<void> Function(SkillRepository) action) async {
    if (_working) return;
    _working = true;
    try {
      final repository = await ref.read(skillRepositoryProvider.future);
      await action(repository);
      if (ref.mounted) ref.invalidateSelf();
    } finally {
      _working = false;
    }
  }
}
