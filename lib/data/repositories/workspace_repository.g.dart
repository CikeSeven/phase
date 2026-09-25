// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workspace_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(workspaceRepository)
final workspaceRepositoryProvider = WorkspaceRepositoryProvider._();

final class WorkspaceRepositoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<WorkspaceRepository>,
          WorkspaceRepository,
          FutureOr<WorkspaceRepository>
        >
    with
        $FutureModifier<WorkspaceRepository>,
        $FutureProvider<WorkspaceRepository> {
  WorkspaceRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workspaceRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workspaceRepositoryHash();

  @$internal
  @override
  $FutureProviderElement<WorkspaceRepository> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<WorkspaceRepository> create(Ref ref) {
    return workspaceRepository(ref);
  }
}

String _$workspaceRepositoryHash() =>
    r'66749523641b080c354c6d6015d97d5e04ca9116';
