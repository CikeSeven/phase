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
