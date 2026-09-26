import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/error/failure.dart';
import '../../../data/repositories/workspace_repository.dart';
import '../tools/tool.dart';
import 'dependency_installer.dart';
import 'dependency_profiles.dart';
import 'process_driver.dart';

part 'dependency_controller.g.dart';

class DependencyOperation {
  const DependencyOperation({
    this.busy = false,
    this.step,
    this.logTail = const [],
    this.error,
    this.failed = false,
    this.stepStartedAt,
    this.lastOutputAt,
  });
  final bool busy;
  final DependencyStep? step;
  final List<String> logTail;
  final String? error;
  final DateTime? stepStartedAt;
  final DateTime? lastOutputAt;

  /// 最近一次失败可原样重试；重试重发同样的完整安装。
  final bool failed;
}

@Riverpod(keepAlive: true)
class DependencyController extends _$DependencyController {
  RunCancellation? _cancellation;
  @override
  DependencyOperation build() {
    ref.onDispose(() => _cancellation?.cancel());
    return const DependencyOperation();
  }

  void cancel() => _cancellation?.cancel();
  void reset() {
    if (!state.busy) state = const DependencyOperation();
  }

  Future<void> install() => installWithCancellation(RunCancellation());

  /// Ubuntu 安装与后续依赖共用取消信号，阶段切换不丢失停止请求。
  Future<void> installWithCancellation(
    RunCancellation cancellation, {
    String? taskOwner,
  }) async {
    if (state.busy) return;
    _cancellation = cancellation;
    state = const DependencyOperation(busy: true);
    try {
      final repository = await ref.read(workspaceRepositoryProvider.future);
      if (!ref.mounted) return;
      cancellation.throwIfCancelled();
      final installer = DependencyInstaller(
        repository,
        ref.read(processDriverProvider),
        taskOwner: taskOwner,
      );
      await installer.install(cancellation, (step, line) {
        if (!ref.mounted) return;
        final now = DateTime.now();
        final lines = [if (state.step == step) ...state.logTail, line];
        state = DependencyOperation(
          busy: true,
          step: step,
          logTail: lines
              .skip((lines.length - 5).clamp(0, lines.length))
              .toList(),
          stepStartedAt: state.step == step ? state.stepStartedAt : now,
          lastOutputAt: now,
        );
      });
      if (ref.mounted) state = const DependencyOperation();
    } on ToolCancelled {
      if (ref.mounted) {
        state = DependencyOperation(
          step: state.step,
          logTail: state.logTail,
          error: '已取消安装，已安装内容保留',
          failed: true,
        );
      }
    } catch (error) {
      if (ref.mounted) {
        state = DependencyOperation(
          step: state.step,
          logTail: state.logTail,
          error: error is Failure ? error.userMessage : '依赖安装失败，请重试',
          failed: true,
        );
      }
    } finally {
      _cancellation = null;
    }
  }
}
