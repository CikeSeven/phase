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
          ProviderProfileRepository,
          ProviderProfileRepository,
          ProviderProfileRepository
        >
    with $Provider<ProviderProfileRepository> {
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
  $ProviderElement<ProviderProfileRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ProviderProfileRepository create(Ref ref) {
    return providerProfileRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ProviderProfileRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ProviderProfileRepository>(value),
    );
  }
}

String _$providerProfileRepositoryHash() =>
    r'35701c1e12c5d374e43a3be792fb88c5119410c1';

/// 服务商配置列表流。

@ProviderFor(providerProfiles)
final providerProfilesProvider = ProviderProfilesProvider._();

/// 服务商配置列表流。

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
  /// 服务商配置列表流。
  ProviderProfilesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'providerProfilesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

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

String _$providerProfilesHash() => r'29f7c3a2b601b1acb817bd7516373438cf70238e';
