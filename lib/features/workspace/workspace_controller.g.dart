// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workspace_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(linuxPlatformInfo)
final linuxPlatformInfoProvider = LinuxPlatformInfoProvider._();

final class LinuxPlatformInfoProvider
    extends
        $FunctionalProvider<
          AsyncValue<LinuxPlatformInfo>,
          LinuxPlatformInfo,
          FutureOr<LinuxPlatformInfo>
        >
    with
        $FutureModifier<LinuxPlatformInfo>,
        $FutureProvider<LinuxPlatformInfo> {
  LinuxPlatformInfoProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'linuxPlatformInfoProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$linuxPlatformInfoHash();

  @$internal
  @override
  $FutureProviderElement<LinuxPlatformInfo> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<LinuxPlatformInfo> create(Ref ref) {
    return linuxPlatformInfo(ref);
  }
}

String _$linuxPlatformInfoHash() => r'd0578c8d448366da4fa2085ca8af75482df73de5';

@ProviderFor(workspaceRepository)
final workspaceRepositoryProvider = WorkspaceRepositoryProvider._();

final class WorkspaceRepositoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<WorkspaceRepository>,
          WorkspaceRepository,
          FutureOr<WorkspaceRepository>
        >
    with
        $FutureModifier<WorkspaceRepository>,
        $FutureProvider<WorkspaceRepository> {
  WorkspaceRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workspaceRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workspaceRepositoryHash();

  @$internal
  @override
  $FutureProviderElement<WorkspaceRepository> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<WorkspaceRepository> create(Ref ref) {
    return workspaceRepository(ref);
  }
}

String _$workspaceRepositoryHash() =>
    r'48a682f4b5ddc40d798da6616777a0b9c1ebc482';

@ProviderFor(workspaces)
final workspacesProvider = WorkspacesProvider._();

final class WorkspacesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Workspace>>,
          List<Workspace>,
          Stream<List<Workspace>>
        >
    with $FutureModifier<List<Workspace>>, $StreamProvider<List<Workspace>> {
  WorkspacesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workspacesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workspacesHash();

  @$internal
  @override
  $StreamProviderElement<List<Workspace>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Workspace>> create(Ref ref) {
    return workspaces(ref);
  }
}

String _$workspacesHash() => r'4279bc3650d6e6c7c968ae82d87f6dffbca2c513';

@ProviderFor(runtimeEnvironment)
final runtimeEnvironmentProvider = RuntimeEnvironmentProvider._();

final class RuntimeEnvironmentProvider
    extends
        $FunctionalProvider<
          AsyncValue<RuntimeEnvironment>,
          RuntimeEnvironment,
          Stream<RuntimeEnvironment>
        >
    with
        $FutureModifier<RuntimeEnvironment>,
        $StreamProvider<RuntimeEnvironment> {
  RuntimeEnvironmentProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'runtimeEnvironmentProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$runtimeEnvironmentHash();

  @$internal
  @override
  $StreamProviderElement<RuntimeEnvironment> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<RuntimeEnvironment> create(Ref ref) {
    return runtimeEnvironment(ref);
  }
}

String _$runtimeEnvironmentHash() =>
    r'ef9eeadacbf48690c59fcc1f39061cccd11b8b38';

@ProviderFor(EnvironmentController)
final environmentControllerProvider = EnvironmentControllerProvider._();

final class EnvironmentControllerProvider
    extends $NotifierProvider<EnvironmentController, EnvironmentOperation> {
  EnvironmentControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'environmentControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$environmentControllerHash();

  @$internal
  @override
  EnvironmentController create() => EnvironmentController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(EnvironmentOperation value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<EnvironmentOperation>(value),
    );
  }
}

String _$environmentControllerHash() =>
    r'cfc4a99728c9ce394af8719f5bcf5d986f05adf4';

abstract class _$EnvironmentController extends $Notifier<EnvironmentOperation> {
  EnvironmentOperation build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<EnvironmentOperation, EnvironmentOperation>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<EnvironmentOperation, EnvironmentOperation>,
              EnvironmentOperation,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
