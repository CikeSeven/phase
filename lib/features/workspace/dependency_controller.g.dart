// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dependency_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(DependencyController)
final dependencyControllerProvider = DependencyControllerProvider._();

final class DependencyControllerProvider
    extends $NotifierProvider<DependencyController, DependencyOperation> {
  DependencyControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dependencyControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dependencyControllerHash();

  @$internal
  @override
  DependencyController create() => DependencyController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DependencyOperation value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DependencyOperation>(value),
    );
  }
}

String _$dependencyControllerHash() =>
    r'aeb240e05617308952bfa695e27028d321e5c047';

abstract class _$DependencyController extends $Notifier<DependencyOperation> {
  DependencyOperation build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<DependencyOperation, DependencyOperation>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<DependencyOperation, DependencyOperation>,
              DependencyOperation,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
