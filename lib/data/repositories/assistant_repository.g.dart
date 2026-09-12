// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'assistant_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(assistantRepository)
final assistantRepositoryProvider = AssistantRepositoryProvider._();

final class AssistantRepositoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<AssistantRepository>,
          AssistantRepository,
          FutureOr<AssistantRepository>
        >
    with
        $FutureModifier<AssistantRepository>,
        $FutureProvider<AssistantRepository> {
  AssistantRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'assistantRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$assistantRepositoryHash();

  @$internal
  @override
  $FutureProviderElement<AssistantRepository> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<AssistantRepository> create(Ref ref) {
    return assistantRepository(ref);
  }
}

String _$assistantRepositoryHash() =>
    r'99928a6f554d08d3728a017b743ffcc9e1f6cab5';
