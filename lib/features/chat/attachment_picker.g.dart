// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'attachment_picker.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 附件选择器；依赖附件存储的异步初始化。

@ProviderFor(attachmentPicker)
final attachmentPickerProvider = AttachmentPickerProvider._();

/// 附件选择器；依赖附件存储的异步初始化。

final class AttachmentPickerProvider
    extends
        $FunctionalProvider<
          AsyncValue<AttachmentPicker>,
          AttachmentPicker,
          FutureOr<AttachmentPicker>
        >
    with $FutureModifier<AttachmentPicker>, $FutureProvider<AttachmentPicker> {
  /// 附件选择器；依赖附件存储的异步初始化。
  AttachmentPickerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'attachmentPickerProvider',
        isAutoDispose: false,
        dependencies: <ProviderOrFamily>[attachmentStorageProvider],
        $allTransitiveDependencies: <ProviderOrFamily>[
          AttachmentPickerProvider.$allTransitiveDependencies0,
        ],
      );

  static final $allTransitiveDependencies0 = attachmentStorageProvider;

  @override
  String debugGetCreateSourceHash() => _$attachmentPickerHash();

  @$internal
  @override
  $FutureProviderElement<AttachmentPicker> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<AttachmentPicker> create(Ref ref) {
    return attachmentPicker(ref);
  }
}

String _$attachmentPickerHash() => r'9b38c1475f13481db0f68885b9292d5c1d7ee31a';
