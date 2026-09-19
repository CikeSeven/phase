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
  });
  final bool busy;
  final DependencyStep? step;
  final List<String> logTail;
  final String? error;

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
  Future<void> install() async {
    if (state.busy) return;
    final cancellation = RunCancellation();
    _cancellation = cancellation;
    state = const DependencyOperation(busy: true);
    try {
      final installer = DependencyInstaller(
        await ref.read(workspaceRepositoryProvider.future),
        ref.read(processDriverProvider),
      );
      await installer.install(cancellation, (step, line) {
        if (!ref.mounted) return;
        state = DependencyOperation(
          busy: true,
          step: step,
          logTail: [...state.logTail, line].take(5).toList(),
        );
      });
      if (ref.mounted) state = const DependencyOperation();
    } on ToolCancelled {
      if (ref.mounted) {
        state = const DependencyOperation(error: '已取消安装，已安装内容保留', failed: true);
      }
    } catch (error) {
      if (ref.mounted) {
        state = DependencyOperation(
          error: error is Failure ? error.userMessage : '依赖安装失败，请重试',
          failed: true,
        );
      }
    } finally {
      _cancellation = null;
    }
  }
}
