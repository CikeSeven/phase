// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plan_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(planRepository)
final planRepositoryProvider = PlanRepositoryProvider._();

final class PlanRepositoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<PlanRepository>,
          PlanRepository,
          FutureOr<PlanRepository>
        >
    with $FutureModifier<PlanRepository>, $FutureProvider<PlanRepository> {
  PlanRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'planRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$planRepositoryHash();

  @$internal
  @override
  $FutureProviderElement<PlanRepository> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<PlanRepository> create(Ref ref) {
    return planRepository(ref);
  }
}

String _$planRepositoryHash() => r'a481f842cb22ee83435564b1f09de9a6a588f28d';

@ProviderFor(conversationPlans)
final conversationPlansProvider = ConversationPlansFamily._();

final class ConversationPlansProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<AgentPlan>>,
          List<AgentPlan>,
          Stream<List<AgentPlan>>
        >
    with $FutureModifier<List<AgentPlan>>, $StreamProvider<List<AgentPlan>> {
  ConversationPlansProvider._({
    required ConversationPlansFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'conversationPlansProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$conversationPlansHash();

  @override
  String toString() {
    return r'conversationPlansProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<AgentPlan>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<AgentPlan>> create(Ref ref) {
    final argument = this.argument as String;
    return conversationPlans(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ConversationPlansProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$conversationPlansHash() => r'9e842245b05177837328eb94293c8a98943da868';

final class ConversationPlansFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<AgentPlan>>, String> {
  ConversationPlansFamily._()
    : super(
        retry: null,
        name: r'conversationPlansProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ConversationPlansProvider call(String conversationId) =>
      ConversationPlansProvider._(argument: conversationId, from: this);

  @override
  String toString() => r'conversationPlansProvider';
}
