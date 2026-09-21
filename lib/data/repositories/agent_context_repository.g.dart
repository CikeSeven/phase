// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'agent_context_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(agentContextRepository)
final agentContextRepositoryProvider = AgentContextRepositoryProvider._();

final class AgentContextRepositoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<AgentContextRepository>,
          AgentContextRepository,
          FutureOr<AgentContextRepository>
        >
    with
        $FutureModifier<AgentContextRepository>,
        $FutureProvider<AgentContextRepository> {
  AgentContextRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'agentContextRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$agentContextRepositoryHash();

  @$internal
  @override
  $FutureProviderElement<AgentContextRepository> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<AgentContextRepository> create(Ref ref) {
    return agentContextRepository(ref);
  }
}

String _$agentContextRepositoryHash() =>
    r'97bffa49bc5e6b6d485a1813508348aa944d2086';
