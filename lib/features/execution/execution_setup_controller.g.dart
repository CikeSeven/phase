// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'execution_setup_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(executionSetupApi)
final executionSetupApiProvider = ExecutionSetupApiProvider._();

final class ExecutionSetupApiProvider
    extends
        $FunctionalProvider<
          ExecutionSetupApi,
          ExecutionSetupApi,
          ExecutionSetupApi
        >
    with $Provider<ExecutionSetupApi> {
  ExecutionSetupApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'executionSetupApiProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$executionSetupApiHash();

  @$internal
  @override
  $ProviderElement<ExecutionSetupApi> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ExecutionSetupApi create(Ref ref) {
    return executionSetupApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ExecutionSetupApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ExecutionSetupApi>(value),
    );
  }
}

String _$executionSetupApiHash() => r'af7c99c879937bb570e5ce1b19d960588e643640';

@ProviderFor(ExecutionSetupController)
final executionSetupControllerProvider = ExecutionSetupControllerProvider._();

final class ExecutionSetupControllerProvider
    extends
        $AsyncNotifierProvider<ExecutionSetupController, ExecutionSetupState> {
  ExecutionSetupControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'executionSetupControllerProvider',
        isAutoDispose: false,
        dependencies: <ProviderOrFamily>[settingsStorageProvider],
        $allTransitiveDependencies: <ProviderOrFamily>[
          ExecutionSetupControllerProvider.$allTransitiveDependencies0,
          ExecutionSetupControllerProvider.$allTransitiveDependencies1,
        ],
      );

  static final $allTransitiveDependencies0 = settingsStorageProvider;
  static final $allTransitiveDependencies1 =
      SettingsStorageProvider.$allTransitiveDependencies0;

  @override
  String debugGetCreateSourceHash() => _$executionSetupControllerHash();

  @$internal
  @override
  ExecutionSetupController create() => ExecutionSetupController();
}

String _$executionSetupControllerHash() =>
    r'8de01ab66ad16c3d8b90d683887ac8f7fe9a8792';

abstract class _$ExecutionSetupController
    extends $AsyncNotifier<ExecutionSetupState> {
  FutureOr<ExecutionSetupState> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<ExecutionSetupState>, ExecutionSetupState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<ExecutionSetupState>, ExecutionSetupState>,
              AsyncValue<ExecutionSetupState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
