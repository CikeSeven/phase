// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'model_request_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(modelRequestRepository)
final modelRequestRepositoryProvider = ModelRequestRepositoryProvider._();

final class ModelRequestRepositoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<ModelRequestRepository>,
          ModelRequestRepository,
          FutureOr<ModelRequestRepository>
        >
    with
        $FutureModifier<ModelRequestRepository>,
        $FutureProvider<ModelRequestRepository> {
  ModelRequestRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'modelRequestRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$modelRequestRepositoryHash();

  @$internal
  @override
  $FutureProviderElement<ModelRequestRepository> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ModelRequestRepository> create(Ref ref) {
    return modelRequestRepository(ref);
  }
}

String _$modelRequestRepositoryHash() =>
    r'49091cb36c69ae647b40fb84575f4896e33b9d85';

@ProviderFor(conversationRequests)
final conversationRequestsProvider = ConversationRequestsFamily._();

final class ConversationRequestsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ModelRequestRecord>>,
          List<ModelRequestRecord>,
          Stream<List<ModelRequestRecord>>
        >
    with
        $FutureModifier<List<ModelRequestRecord>>,
        $StreamProvider<List<ModelRequestRecord>> {
  ConversationRequestsProvider._({
    required ConversationRequestsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'conversationRequestsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$conversationRequestsHash();

  @override
  String toString() {
    return r'conversationRequestsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<ModelRequestRecord>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<ModelRequestRecord>> create(Ref ref) {
    final argument = this.argument as String;
    return conversationRequests(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ConversationRequestsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$conversationRequestsHash() =>
    r'21040c48ad67cfa6697cb4948b24b455be0448ec';

final class ConversationRequestsFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<ModelRequestRecord>>, String> {
  ConversationRequestsFamily._()
    : super(
        retry: null,
        name: r'conversationRequestsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ConversationRequestsProvider call(String conversationId) =>
      ConversationRequestsProvider._(argument: conversationId, from: this);

  @override
  String toString() => r'conversationRequestsProvider';
}
