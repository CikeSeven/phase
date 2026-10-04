// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'web_search_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(webSearchRepository)
final webSearchRepositoryProvider = WebSearchRepositoryProvider._();

final class WebSearchRepositoryProvider
    extends
        $FunctionalProvider<
          WebSearchRepository,
          WebSearchRepository,
          WebSearchRepository
        >
    with $Provider<WebSearchRepository> {
  WebSearchRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'webSearchRepositoryProvider',
        isAutoDispose: false,
        dependencies: <ProviderOrFamily>[settingsStorageProvider],
        $allTransitiveDependencies: <ProviderOrFamily>[
          WebSearchRepositoryProvider.$allTransitiveDependencies0,
          WebSearchRepositoryProvider.$allTransitiveDependencies1,
        ],
      );

  static final $allTransitiveDependencies0 = settingsStorageProvider;
  static final $allTransitiveDependencies1 =
      SettingsStorageProvider.$allTransitiveDependencies0;

  @override
  String debugGetCreateSourceHash() => _$webSearchRepositoryHash();

  @$internal
  @override
  $ProviderElement<WebSearchRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  WebSearchRepository create(Ref ref) {
    return webSearchRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WebSearchRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WebSearchRepository>(value),
    );
  }
}

String _$webSearchRepositoryHash() =>
    r'76414c539770fea80c60de739d9f23c43bdfa1e9';
