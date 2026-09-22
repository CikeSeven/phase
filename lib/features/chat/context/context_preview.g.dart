// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'context_preview.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(contextPreview)
final contextPreviewProvider = ContextPreviewFamily._();

final class ContextPreviewProvider
    extends
        $FunctionalProvider<
          AsyncValue<ContextBuild?>,
          ContextBuild?,
          FutureOr<ContextBuild?>
        >
    with $FutureModifier<ContextBuild?>, $FutureProvider<ContextBuild?> {
  ContextPreviewProvider._({
    required ContextPreviewFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'contextPreviewProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  static final $allTransitiveDependencies0 = chatControllerProvider;
  static final $allTransitiveDependencies1 =
      ChatControllerProvider.$allTransitiveDependencies0;
  static final $allTransitiveDependencies2 =
      ChatControllerProvider.$allTransitiveDependencies1;
  static final $allTransitiveDependencies3 =
      ChatControllerProvider.$allTransitiveDependencies2;
  static final $allTransitiveDependencies4 =
      ChatControllerProvider.$allTransitiveDependencies3;
  static final $allTransitiveDependencies5 =
      ChatControllerProvider.$allTransitiveDependencies4;
  static final $allTransitiveDependencies6 =
      ChatControllerProvider.$allTransitiveDependencies5;
  static final $allTransitiveDependencies7 =
      ChatControllerProvider.$allTransitiveDependencies6;
  static final $allTransitiveDependencies8 =
      ChatControllerProvider.$allTransitiveDependencies7;
  static final $allTransitiveDependencies9 =
      ChatControllerProvider.$allTransitiveDependencies8;

  @override
  String debugGetCreateSourceHash() => _$contextPreviewHash();

  @override
  String toString() {
    return r'contextPreviewProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<ContextBuild?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ContextBuild?> create(Ref ref) {
    final argument = this.argument as String;
    return contextPreview(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ContextPreviewProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$contextPreviewHash() => r'bf4fa0a286add68c81d6738456c31f6b948a0874';

final class ContextPreviewFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<ContextBuild?>, String> {
  ContextPreviewFamily._()
    : super(
        retry: null,
        name: r'contextPreviewProvider',
        dependencies: <ProviderOrFamily>[
          chatControllerProvider,
          modelSelectionProvider,
          currentAssistantProvider,
          activeConversationProvider,
          conversationThreadProvider,
        ],
        $allTransitiveDependencies: <ProviderOrFamily>{
          ContextPreviewProvider.$allTransitiveDependencies0,
          ContextPreviewProvider.$allTransitiveDependencies1,
          ContextPreviewProvider.$allTransitiveDependencies2,
          ContextPreviewProvider.$allTransitiveDependencies3,
          ContextPreviewProvider.$allTransitiveDependencies4,
          ContextPreviewProvider.$allTransitiveDependencies5,
          ContextPreviewProvider.$allTransitiveDependencies6,
          ContextPreviewProvider.$allTransitiveDependencies7,
          ContextPreviewProvider.$allTransitiveDependencies8,
          ContextPreviewProvider.$allTransitiveDependencies9,
        },
        isAutoDispose: true,
      );

  ContextPreviewProvider call(String conversationId) =>
      ContextPreviewProvider._(argument: conversationId, from: this);

  @override
  String toString() => r'contextPreviewProvider';
}
