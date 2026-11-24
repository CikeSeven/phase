// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'image_generation_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(imageGenerationRepository)
final imageGenerationRepositoryProvider = ImageGenerationRepositoryProvider._();

final class ImageGenerationRepositoryProvider
    extends
        $FunctionalProvider<
          ImageGenerationRepository,
          ImageGenerationRepository,
          ImageGenerationRepository
        >
    with $Provider<ImageGenerationRepository> {
  ImageGenerationRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'imageGenerationRepositoryProvider',
        isAutoDispose: false,
        dependencies: <ProviderOrFamily>[settingsStorageProvider],
        $allTransitiveDependencies: <ProviderOrFamily>[
          ImageGenerationRepositoryProvider.$allTransitiveDependencies0,
          ImageGenerationRepositoryProvider.$allTransitiveDependencies1,
        ],
      );

  static final $allTransitiveDependencies0 = settingsStorageProvider;
  static final $allTransitiveDependencies1 =
      SettingsStorageProvider.$allTransitiveDependencies0;

  @override
  String debugGetCreateSourceHash() => _$imageGenerationRepositoryHash();

  @$internal
  @override
  $ProviderElement<ImageGenerationRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ImageGenerationRepository create(Ref ref) {
    return imageGenerationRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ImageGenerationRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ImageGenerationRepository>(value),
    );
  }
}

String _$imageGenerationRepositoryHash() =>
    r'03ab0fde9da23f9c856a99e0c27cc043598e791a';
