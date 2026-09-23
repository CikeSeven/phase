// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'model_catalog_cache.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(modelCatalogCache)
final modelCatalogCacheProvider = ModelCatalogCacheProvider._();

final class ModelCatalogCacheProvider
    extends
        $FunctionalProvider<
          AsyncValue<ModelCatalogCache>,
          ModelCatalogCache,
          FutureOr<ModelCatalogCache>
        >
    with
        $FutureModifier<ModelCatalogCache>,
        $FutureProvider<ModelCatalogCache> {
  ModelCatalogCacheProvider._()
    : super(
        from: null,
        argument: null,
        retry: _noCacheRetry,
        name: r'modelCatalogCacheProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$modelCatalogCacheHash();

  @$internal
  @override
  $FutureProviderElement<ModelCatalogCache> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ModelCatalogCache> create(Ref ref) {
    return modelCatalogCache(ref);
  }
}

String _$modelCatalogCacheHash() => r'd25ae8c168c987837cdd738ce2ac5b4bb4d9d8be';

/// 生效目录：内置快照为基线，存在刷新缓存时覆盖。只读盘，无网络副作用；
/// 联网刷新由用户动作触发，完成后 invalidate 本 provider。

@ProviderFor(modelCatalog)
final modelCatalogProvider = ModelCatalogProvider._();

/// 生效目录：内置快照为基线，存在刷新缓存时覆盖。只读盘，无网络副作用；
/// 联网刷新由用户动作触发，完成后 invalidate 本 provider。

final class ModelCatalogProvider
    extends
        $FunctionalProvider<
          AsyncValue<ModelCatalog>,
          ModelCatalog,
          FutureOr<ModelCatalog>
        >
    with $FutureModifier<ModelCatalog>, $FutureProvider<ModelCatalog> {
  /// 生效目录：内置快照为基线，存在刷新缓存时覆盖。只读盘，无网络副作用；
  /// 联网刷新由用户动作触发，完成后 invalidate 本 provider。
  ModelCatalogProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'modelCatalogProvider',
        isAutoDispose: false,
        dependencies: <ProviderOrFamily>[modelCatalogCacheProvider],
        $allTransitiveDependencies: <ProviderOrFamily>[
          ModelCatalogProvider.$allTransitiveDependencies0,
        ],
      );

  static final $allTransitiveDependencies0 = modelCatalogCacheProvider;

  @override
  String debugGetCreateSourceHash() => _$modelCatalogHash();

  @$internal
  @override
  $FutureProviderElement<ModelCatalog> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ModelCatalog> create(Ref ref) {
    return modelCatalog(ref);
  }
}

String _$modelCatalogHash() => r'db292eff1fceb448e027d8b6166d5a988a643204';
