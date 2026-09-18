// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'process_driver.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(processDriver)
final processDriverProvider = ProcessDriverProvider._();

final class ProcessDriverProvider
    extends $FunctionalProvider<ProcessDriver, ProcessDriver, ProcessDriver>
    with $Provider<ProcessDriver> {
  ProcessDriverProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'processDriverProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$processDriverHash();

  @$internal
  @override
  $ProviderElement<ProcessDriver> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ProcessDriver create(Ref ref) {
    return processDriver(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ProcessDriver value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ProcessDriver>(value),
    );
  }
}

String _$processDriverHash() => r'7c04514d75779bf1a57913b9202bab839715aaa5';
