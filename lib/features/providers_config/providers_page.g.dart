// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'providers_page.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
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
