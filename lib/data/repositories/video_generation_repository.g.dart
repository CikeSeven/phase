// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'video_generation_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(videoGenerationRepository)
final videoGenerationRepositoryProvider = VideoGenerationRepositoryProvider._();

final class VideoGenerationRepositoryProvider
    extends
        $FunctionalProvider<
          VideoGenerationRepository,
          VideoGenerationRepository,
          VideoGenerationRepository
        >
    with $Provider<VideoGenerationRepository> {
  VideoGenerationRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'videoGenerationRepositoryProvider',
        isAutoDispose: false,
        dependencies: <ProviderOrFamily>[settingsStorageProvider],
        $allTransitiveDependencies: <ProviderOrFamily>[
          VideoGenerationRepositoryProvider.$allTransitiveDependencies0,
          VideoGenerationRepositoryProvider.$allTransitiveDependencies1,
        ],
      );

  static final $allTransitiveDependencies0 = settingsStorageProvider;
  static final $allTransitiveDependencies1 =
      SettingsStorageProvider.$allTransitiveDependencies0;

  @override
  String debugGetCreateSourceHash() => _$videoGenerationRepositoryHash();

  @$internal
  @override
  $ProviderElement<VideoGenerationRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  VideoGenerationRepository create(Ref ref) {
    return videoGenerationRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VideoGenerationRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VideoGenerationRepository>(value),
    );
  }
}

String _$videoGenerationRepositoryHash() =>
    r'd5c203263c58845074901b5066ed2a59a92bfea4';
