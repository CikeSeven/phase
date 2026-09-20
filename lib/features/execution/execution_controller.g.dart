// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'execution_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 根任务的用户控制，与页面/Activity 的挂接无关。决定由 ToolExecutor 落库。

@ProviderFor(ExecutionController)
final executionControllerProvider = ExecutionControllerProvider._();

/// 根任务的用户控制，与页面/Activity 的挂接无关。决定由 ToolExecutor 落库。
final class ExecutionControllerProvider
    extends $NotifierProvider<ExecutionController, ExecutionState> {
  /// 根任务的用户控制，与页面/Activity 的挂接无关。决定由 ToolExecutor 落库。
  ExecutionControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'executionControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$executionControllerHash();

  @$internal
  @override
  ExecutionController create() => ExecutionController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ExecutionState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ExecutionState>(value),
    );
  }
}

String _$executionControllerHash() =>
    r'39a6694caf5bc9c3850e537ca5c6e0e121e9ae62';

/// 根任务的用户控制，与页面/Activity 的挂接无关。决定由 ToolExecutor 落库。

abstract class _$ExecutionController extends $Notifier<ExecutionState> {
  ExecutionState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ExecutionState, ExecutionState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ExecutionState, ExecutionState>,
              ExecutionState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
