// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'run_recovery_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 启动核对只执行一次；读取失败保持错误状态，不能伪装成没有中断任务。

@ProviderFor(RunRecoveryController)
final runRecoveryControllerProvider = RunRecoveryControllerProvider._();

/// 启动核对只执行一次；读取失败保持错误状态，不能伪装成没有中断任务。
final class RunRecoveryControllerProvider
    extends $AsyncNotifierProvider<RunRecoveryController, List<RecoveredRun>> {
  /// 启动核对只执行一次；读取失败保持错误状态，不能伪装成没有中断任务。
  RunRecoveryControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'runRecoveryControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$runRecoveryControllerHash();

  @$internal
  @override
  RunRecoveryController create() => RunRecoveryController();
}

String _$runRecoveryControllerHash() =>
    r'21b634a7c9218195e284e0524cb534524a9d160f';

/// 启动核对只执行一次；读取失败保持错误状态，不能伪装成没有中断任务。

abstract class _$RunRecoveryController
    extends $AsyncNotifier<List<RecoveredRun>> {
  FutureOr<List<RecoveredRun>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<List<RecoveredRun>>, List<RecoveredRun>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<RecoveredRun>>, List<RecoveredRun>>,
              AsyncValue<List<RecoveredRun>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
