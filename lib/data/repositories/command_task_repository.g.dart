// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'command_task_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(commandTaskRepository)
final commandTaskRepositoryProvider = CommandTaskRepositoryProvider._();

final class CommandTaskRepositoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<CommandTaskRepository>,
          CommandTaskRepository,
          FutureOr<CommandTaskRepository>
        >
    with
        $FutureModifier<CommandTaskRepository>,
        $FutureProvider<CommandTaskRepository> {
  CommandTaskRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'commandTaskRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$commandTaskRepositoryHash();

  @$internal
  @override
  $FutureProviderElement<CommandTaskRepository> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<CommandTaskRepository> create(Ref ref) {
    return commandTaskRepository(ref);
  }
}

String _$commandTaskRepositoryHash() =>
    r'74c9bc73a2c287e549a5bc63f946538196a99b26';
