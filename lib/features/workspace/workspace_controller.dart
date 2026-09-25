import 'dart:async';

import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/error/failure.dart';
import '../../../data/datasources/local/settings_storage.dart';
import '../../../data/models/workspace.dart';
import '../../../data/repositories/workspace_repository.dart';
import '../tools/tool.dart';
import 'linux_installer.dart';
import 'process_driver.dart';
import 'process_api.g.dart';

part 'workspace_controller.g.dart';

class PrimaryEnvironmentSetting {
  const PrimaryEnvironmentSetting(
    this.environment, {
    this.saving = false,
    this.error,
  });
  final PrimaryEnvironment environment;
  final bool saving;
  final String? error;
}

@Riverpod(keepAlive: true, dependencies: [settingsStorage])
class DefaultPrimaryEnvironment extends _$DefaultPrimaryEnvironment {
  Future<void>? _pending;
  @override
  PrimaryEnvironmentSetting build() => PrimaryEnvironmentSetting(
    ref.read(settingsStorageProvider).readPrimaryEnvironment(),
  );

  Future<void> select(PrimaryEnvironment environment) async {
    if (state.saving || environment == state.environment) return;
    final previous = state.environment;
    state = PrimaryEnvironmentSetting(previous, saving: true);
    final pending = ref
        .read(settingsStorageProvider)
        .writePrimaryEnvironment(environment);
    _pending = pending;
    try {
      await pending;
      if (ref.mounted) state = PrimaryEnvironmentSetting(environment);
    } on Failure catch (error) {
      if (ref.mounted) {
        state = PrimaryEnvironmentSetting(previous, error: error.userMessage);
      }
    } finally {
      _pending = null;
    }
  }

  Future<PrimaryEnvironment> forNewConversation() async {
    await _pending;
    return state.environment;
  }
}

@riverpod
Future<LinuxPlatformInfo> linuxPlatformInfo(Ref ref) =>
    ref.watch(processDriverProvider).info();

@riverpod
Stream<RuntimeEnvironment> runtimeEnvironment(Ref ref) async* {
  yield* (await ref.watch(workspaceRepositoryProvider.future))
      .watchEnvironment();
}

class EnvironmentOperation {
  const EnvironmentOperation({
    this.busy = false,
    this.phase,
    this.bytes = 0,
    this.total,
    this.error,
    this.phaseStartedAt,
    this.lastProgressAt,
    this.uninstalling = false,
  });
  final bool busy;
  final EnvironmentPhase? phase;
  final int bytes;
  final int? total;
  final String? error;
  final DateTime? phaseStartedAt;
  final DateTime? lastProgressAt;
  final bool uninstalling;
}

@Riverpod(keepAlive: true)
class EnvironmentController extends _$EnvironmentController {
  RunCancellation? _cancellation;
  @override
  EnvironmentOperation build() {
    ref.onDispose(() => _cancellation?.cancel());
    return const EnvironmentOperation();
  }

  void cancel() => _cancellation?.cancel();
  Future<void> install() => _operate(false);
  Future<void> uninstall() => _operate(true);
  Future<void> _operate(bool uninstall) async {
    if (state.busy) return;
    final cancellation = RunCancellation();
    _cancellation = cancellation;
    state = EnvironmentOperation(
      busy: true,
      uninstalling: uninstall,
      phaseStartedAt: DateTime.now(),
    );
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );
    try {
      final installer = LinuxInstaller(
        await ref.read(workspaceRepositoryProvider.future),
        ref.read(processDriverProvider),
        dio,
      );
      if (uninstall) {
        await installer.uninstall();
      } else {
        var last = DateTime.fromMillisecondsSinceEpoch(0);
        await installer.install(cancellation, (phase, bytes, total) {
          // Keep the final check visible until commit and cleanup both finish.
          if (phase == EnvironmentPhase.ready) return;
          final now = DateTime.now();
          if (ref.mounted &&
              (state.phase != phase ||
                  now.difference(last).inMilliseconds >= 100 ||
                  bytes == total)) {
            state = EnvironmentOperation(
              busy: true,
              phase: phase,
              bytes: bytes,
              total: total,
              phaseStartedAt: state.phase == phase ? state.phaseStartedAt : now,
              lastProgressAt: now,
            );
            last = now;
          }
        });
      }
      if (ref.mounted) state = const EnvironmentOperation();
    } on ToolCancelled {
      if (ref.mounted) {
        state = const EnvironmentOperation(error: '已取消环境安装，已有工作区保留');
      }
    } catch (error) {
      if (ref.mounted) {
        state = EnvironmentOperation(
          error: error is Failure ? error.userMessage : '环境操作失败，请重试',
        );
      }
    } finally {
      _cancellation = null;
      dio.close(force: true);
    }
  }
}
