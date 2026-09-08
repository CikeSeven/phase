// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_router.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 应用路由表。
///
/// TODO(motion): 按 DESIGN.md §7 统一 FadeThrough / SharedAxis 页面过渡。

@ProviderFor(appRouter)
final appRouterProvider = AppRouterProvider._();

/// 应用路由表。
///
/// TODO(motion): 按 DESIGN.md §7 统一 FadeThrough / SharedAxis 页面过渡。

final class AppRouterProvider
    extends $FunctionalProvider<GoRouter, GoRouter, GoRouter>
    with $Provider<GoRouter> {
  /// 应用路由表。
  ///
  /// TODO(motion): 按 DESIGN.md §7 统一 FadeThrough / SharedAxis 页面过渡。
  AppRouterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appRouterProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appRouterHash();

  @$internal
  @override
  $ProviderElement<GoRouter> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  GoRouter create(Ref ref) {
    return appRouter(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GoRouter value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GoRouter>(value),
    );
  }
}

String _$appRouterHash() => r'68f14061e95e3ad5300d8ceb9e641b03b49ca3fe';
