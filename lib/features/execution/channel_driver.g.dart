// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'channel_driver.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(channelDriver)
final channelDriverProvider = ChannelDriverProvider._();

final class ChannelDriverProvider
    extends $FunctionalProvider<ChannelDriver, ChannelDriver, ChannelDriver>
    with $Provider<ChannelDriver> {
  ChannelDriverProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'channelDriverProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$channelDriverHash();

  @$internal
  @override
  $ProviderElement<ChannelDriver> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ChannelDriver create(Ref ref) {
    return channelDriver(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ChannelDriver value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ChannelDriver>(value),
    );
  }
}

String _$channelDriverHash() => r'80196ebcc1b9c9ecca4848a9e412fe9067c0ee47';
