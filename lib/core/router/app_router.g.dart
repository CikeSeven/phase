// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_router.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 应用路由表。页面转场统一由主题（DESIGN.md §6）提供。
///
/// 每条路由必须显式给出 pageBuilder：go_router 18 靠检测 material_ui 包的
/// MaterialApp 决定页面类型，而本应用用的是 Flutter SDK 内置的 MaterialApp，
/// 检测失败会让所有路由退化为无动画的 NoTransitionPage（且失去预测性返回）。

@ProviderFor(appRouter)
final appRouterProvider = AppRouterProvider._();

/// 应用路由表。页面转场统一由主题（DESIGN.md §6）提供。
///
/// 每条路由必须显式给出 pageBuilder：go_router 18 靠检测 material_ui 包的
/// MaterialApp 决定页面类型，而本应用用的是 Flutter SDK 内置的 MaterialApp，
/// 检测失败会让所有路由退化为无动画的 NoTransitionPage（且失去预测性返回）。

final class AppRouterProvider
    extends $FunctionalProvider<GoRouter, GoRouter, GoRouter>
    with $Provider<GoRouter> {
  /// 应用路由表。页面转场统一由主题（DESIGN.md §6）提供。
  ///
  /// 每条路由必须显式给出 pageBuilder：go_router 18 靠检测 material_ui 包的
  /// MaterialApp 决定页面类型，而本应用用的是 Flutter SDK 内置的 MaterialApp，
  /// 检测失败会让所有路由退化为无动画的 NoTransitionPage（且失去预测性返回）。
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

String _$appRouterHash() => r'9aec977baa9b82485d48543a6fbca13fd1ec8e99';
