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
          Stream<List<ContextSummary>>
        >
    with
        $FutureModifier<List<ContextSummary>>,
        $StreamProvider<List<ContextSummary>> {
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
  $StreamProviderElement<List<ContextSummary>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<ContextSummary>> create(Ref ref) {
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

String _$contextSummariesHash() => r'6f80e70d5f7eb783b60118b6b29840cacfbfef9b';

final class ContextSummariesFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<ContextSummary>>, String> {
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
