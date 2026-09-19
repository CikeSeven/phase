// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'conversation_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(conversationRepository)
final conversationRepositoryProvider = ConversationRepositoryProvider._();

final class ConversationRepositoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<ConversationRepository>,
          ConversationRepository,
          FutureOr<ConversationRepository>
        >
    with
        $FutureModifier<ConversationRepository>,
        $FutureProvider<ConversationRepository> {
  ConversationRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'conversationRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$conversationRepositoryHash();

  @$internal
  @override
  $FutureProviderElement<ConversationRepository> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ConversationRepository> create(Ref ref) {
    return conversationRepository(ref);
  }
}

String _$conversationRepositoryHash() =>
    r'9cd2f9a2e2e71f6ab86c0c5feea653264ea1a3c8';
