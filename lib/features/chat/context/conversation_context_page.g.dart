// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'conversation_context_page.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(contextSummaries)
final contextSummariesProvider = ContextSummariesFamily._();

final class ContextSummariesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ContextSummary>>,
          List<ContextSummary>,
          FutureOr<List<ContextSummary>>
        >
    with
        $FutureModifier<List<ContextSummary>>,
        $FutureProvider<List<ContextSummary>> {
  ContextSummariesProvider._({
    required ContextSummariesFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'contextSummariesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$contextSummariesHash();

  @override
  String toString() {
    return r'contextSummariesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<ContextSummary>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<ContextSummary>> create(Ref ref) {
    final argument = this.argument as String;
    return contextSummaries(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ContextSummariesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$contextSummariesHash() => r'ea7a4fe2c3369bb17b31fa62a1a26eaebdf0d8d3';

final class ContextSummariesFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<ContextSummary>>, String> {
  ContextSummariesFamily._()
    : super(
        retry: null,
        name: r'contextSummariesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ContextSummariesProvider call(String id) =>
      ContextSummariesProvider._(argument: id, from: this);

  @override
  String toString() => r'contextSummariesProvider';
}
