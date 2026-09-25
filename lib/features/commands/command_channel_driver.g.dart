// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'command_channel_driver.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(commandChannelDriver)
final commandChannelDriverProvider = CommandChannelDriverProvider._();

final class CommandChannelDriverProvider
    extends
        $FunctionalProvider<
          CommandChannelDriver,
          CommandChannelDriver,
          CommandChannelDriver
        >
    with $Provider<CommandChannelDriver> {
  CommandChannelDriverProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'commandChannelDriverProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$commandChannelDriverHash();

  @$internal
  @override
  $ProviderElement<CommandChannelDriver> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CommandChannelDriver create(Ref ref) {
    return commandChannelDriver(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CommandChannelDriver value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CommandChannelDriver>(value),
    );
  }
}

String _$commandChannelDriverHash() =>
    r'141c092b58c29d093d11cc91e0dbabdd6db01e15';
