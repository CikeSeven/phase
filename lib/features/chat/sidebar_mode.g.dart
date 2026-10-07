// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sidebar_mode.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SidebarModeController)
final sidebarModeControllerProvider = SidebarModeControllerProvider._();

final class SidebarModeControllerProvider
    extends $NotifierProvider<SidebarModeController, SidebarMode> {
  SidebarModeControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sidebarModeControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sidebarModeControllerHash();

  @$internal
  @override
  SidebarModeController create() => SidebarModeController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SidebarMode value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SidebarMode>(value),
    );
  }
}

String _$sidebarModeControllerHash() =>
    r'8455f9f0f91875a9bd9c107f40ff4bc9e9880400';

abstract class _$SidebarModeController extends $Notifier<SidebarMode> {
  SidebarMode build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<SidebarMode, SidebarMode>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SidebarMode, SidebarMode>,
              SidebarMode,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
