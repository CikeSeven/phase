// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'models_dev_client.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(modelsDevClient)
final modelsDevClientProvider = ModelsDevClientProvider._();

final class ModelsDevClientProvider
    extends
        $FunctionalProvider<ModelsDevClient, ModelsDevClient, ModelsDevClient>
    with $Provider<ModelsDevClient> {
  ModelsDevClientProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'modelsDevClientProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$modelsDevClientHash();

  @$internal
  @override
  $ProviderElement<ModelsDevClient> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ModelsDevClient create(Ref ref) {
    return modelsDevClient(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ModelsDevClient value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ModelsDevClient>(value),
    );
  }
}

String _$modelsDevClientHash() => r'ecbb0d6b3eb96f3c8841e36aac65dc2d389d76b5';
