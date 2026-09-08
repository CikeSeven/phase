// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'provider_factory.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// AiProvider 构造工厂。
///
/// 单独开注入点是为了让测试能 override 成 fake AiProvider，
/// 不必伪造网络层。

@ProviderFor(aiProviderFactory)
final aiProviderFactoryProvider = AiProviderFactoryProvider._();

/// AiProvider 构造工厂。
///
/// 单独开注入点是为了让测试能 override 成 fake AiProvider，
/// 不必伪造网络层。

final class AiProviderFactoryProvider
    extends
        $FunctionalProvider<
          AiProvider Function(ProviderProfile profile, String apiKey),
          AiProvider Function(ProviderProfile profile, String apiKey),
          AiProvider Function(ProviderProfile profile, String apiKey)
        >
    with
        $Provider<AiProvider Function(ProviderProfile profile, String apiKey)> {
  /// AiProvider 构造工厂。
  ///
  /// 单独开注入点是为了让测试能 override 成 fake AiProvider，
  /// 不必伪造网络层。
  AiProviderFactoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'aiProviderFactoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$aiProviderFactoryHash();

  @$internal
  @override
  $ProviderElement<AiProvider Function(ProviderProfile profile, String apiKey)>
  $createElement($ProviderPointer pointer) => $ProviderElement(pointer);

  @override
  AiProvider Function(ProviderProfile profile, String apiKey) create(Ref ref) {
    return aiProviderFactory(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(
    AiProvider Function(ProviderProfile profile, String apiKey) value,
  ) {
    return $ProviderOverride(
      origin: this,
      providerOverride:
          $SyncValueProvider<
            AiProvider Function(ProviderProfile profile, String apiKey)
          >(value),
    );
  }
}

String _$aiProviderFactoryHash() => r'7c0e2aa88070cb031ec9f86ef884acdaec5deefc';
