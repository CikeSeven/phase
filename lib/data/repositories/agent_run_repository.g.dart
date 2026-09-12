// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'agent_run_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(agentRunRepository)
final agentRunRepositoryProvider = AgentRunRepositoryProvider._();

final class AgentRunRepositoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<AgentRunRepository>,
          AgentRunRepository,
          FutureOr<AgentRunRepository>
        >
    with
        $FutureModifier<AgentRunRepository>,
        $FutureProvider<AgentRunRepository> {
  AgentRunRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'agentRunRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$agentRunRepositoryHash();

  @$internal
  @override
  $FutureProviderElement<AgentRunRepository> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<AgentRunRepository> create(Ref ref) {
    return agentRunRepository(ref);
  }
}

String _$agentRunRepositoryHash() =>
    r'cd8759119b380dd852580fcaec184c802033863a';
