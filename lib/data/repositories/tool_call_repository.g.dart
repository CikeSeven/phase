// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tool_call_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(toolCallRepository)
final toolCallRepositoryProvider = ToolCallRepositoryProvider._();

final class ToolCallRepositoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<ToolCallRepository>,
          ToolCallRepository,
          FutureOr<ToolCallRepository>
        >
    with
        $FutureModifier<ToolCallRepository>,
        $FutureProvider<ToolCallRepository> {
  ToolCallRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'toolCallRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$toolCallRepositoryHash();

  @$internal
  @override
  $FutureProviderElement<ToolCallRepository> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ToolCallRepository> create(Ref ref) {
    return toolCallRepository(ref);
  }
}

String _$toolCallRepositoryHash() =>
    r'eb65f0edc3bb534d35d98e3446fff474fc041464';
