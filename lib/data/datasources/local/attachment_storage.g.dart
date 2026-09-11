// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'attachment_storage.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(attachmentStorage)
final attachmentStorageProvider = AttachmentStorageProvider._();

final class AttachmentStorageProvider
    extends
        $FunctionalProvider<
          AsyncValue<AttachmentStorage>,
          AttachmentStorage,
          FutureOr<AttachmentStorage>
        >
    with
        $FutureModifier<AttachmentStorage>,
        $FutureProvider<AttachmentStorage> {
  AttachmentStorageProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'attachmentStorageProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$attachmentStorageHash();

  @$internal
  @override
  $FutureProviderElement<AttachmentStorage> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<AttachmentStorage> create(Ref ref) {
    return attachmentStorage(ref);
  }
}

String _$attachmentStorageHash() => r'40edd3d36bf7256de7a16f6f985996a7e49c3ada';
