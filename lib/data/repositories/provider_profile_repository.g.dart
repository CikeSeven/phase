// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'provider_profile_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(providerProfileRepository)
final providerProfileRepositoryProvider = ProviderProfileRepositoryProvider._();

final class ProviderProfileRepositoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<ProviderProfileRepository>,
          ProviderProfileRepository,
          FutureOr<ProviderProfileRepository>
        >
    with
        $FutureModifier<ProviderProfileRepository>,
        $FutureProvider<ProviderProfileRepository> {
  ProviderProfileRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'providerProfileRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$providerProfileRepositoryHash();

  @$internal
  @override
  $FutureProviderElement<ProviderProfileRepository> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ProviderProfileRepository> create(Ref ref) {
    return providerProfileRepository(ref);
  }
}

String _$providerProfileRepositoryHash() =>
    r'9861503977cd8ee90c99a3afecb4f578333ec8b9';

/// 服务商配置列表流（界面用）。

@ProviderFor(providerProfiles)
final providerProfilesProvider = ProviderProfilesProvider._();

/// 服务商配置列表流（界面用）。

final class ProviderProfilesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ProviderProfile>>,
          List<ProviderProfile>,
          Stream<List<ProviderProfile>>
        >
    with
        $FutureModifier<List<ProviderProfile>>,
        $StreamProvider<List<ProviderProfile>> {
  /// 服务商配置列表流（界面用）。
  ProviderProfilesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'providerProfilesProvider',
        isAutoDispose: true,
        dependencies: <ProviderOrFamily>[providerProfileRepositoryProvider],
        $allTransitiveDependencies: <ProviderOrFamily>[
          ProviderProfilesProvider.$allTransitiveDependencies0,
        ],
      );

  static final $allTransitiveDependencies0 = providerProfileRepositoryProvider;

  @override
  String debugGetCreateSourceHash() => _$providerProfilesHash();

  @$internal
  @override
  $StreamProviderElement<List<ProviderProfile>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<ProviderProfile>> create(Ref ref) {
    return providerProfiles(ref);
  }
}

String _$providerProfilesHash() => r'd85cec0f197e2ac8b62bace1cb58c9aaf296514b';
