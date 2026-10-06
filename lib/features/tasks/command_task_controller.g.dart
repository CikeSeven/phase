// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'command_task_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(CommandTaskController)
final commandTaskControllerProvider = CommandTaskControllerProvider._();

final class CommandTaskControllerProvider
    extends $NotifierProvider<CommandTaskController, CommandTaskState> {
  CommandTaskControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'commandTaskControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$commandTaskControllerHash();

  @$internal
  @override
  CommandTaskController create() => CommandTaskController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CommandTaskState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CommandTaskState>(value),
    );
  }
}

String _$commandTaskControllerHash() =>
    r'09dfb5741112223627291f36f1fe350538ddb792';

abstract class _$CommandTaskController extends $Notifier<CommandTaskState> {
  CommandTaskState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<CommandTaskState, CommandTaskState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<CommandTaskState, CommandTaskState>,
              CommandTaskState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(taskConversations)
final taskConversationsProvider = TaskConversationsProvider._();

final class TaskConversationsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Conversation>>,
          List<Conversation>,
          Stream<List<Conversation>>
        >
    with
        $FutureModifier<List<Conversation>>,
        $StreamProvider<List<Conversation>> {
  TaskConversationsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'taskConversationsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$taskConversationsHash();

  @$internal
  @override
  $StreamProviderElement<List<Conversation>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Conversation>> create(Ref ref) {
    return taskConversations(ref);
  }
}

String _$taskConversationsHash() => r'3ef6424d9854abc974dfe7c75cdb2dc209e2cf93';

@ProviderFor(commandTaskOutput)
final commandTaskOutputProvider = CommandTaskOutputFamily._();

final class CommandTaskOutputProvider
    extends
        $FunctionalProvider<
          AsyncValue<CommandTaskOutput>,
          CommandTaskOutput,
          FutureOr<CommandTaskOutput>
        >
    with
        $FutureModifier<CommandTaskOutput>,
        $FutureProvider<CommandTaskOutput> {
  CommandTaskOutputProvider._({
    required CommandTaskOutputFamily super.from,
    required (String, {int? stdoutOffset, int? stderrOffset}) super.argument,
  }) : super(
         retry: null,
         name: r'commandTaskOutputProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$commandTaskOutputHash();

  @override
  String toString() {
    return r'commandTaskOutputProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<CommandTaskOutput> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<CommandTaskOutput> create(Ref ref) {
    final argument =
        this.argument as (String, {int? stdoutOffset, int? stderrOffset});
    return commandTaskOutput(
      ref,
      argument.$1,
      stdoutOffset: argument.stdoutOffset,
      stderrOffset: argument.stderrOffset,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is CommandTaskOutputProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$commandTaskOutputHash() => r'6f1a6c755d2aacc8a75ceda79d73ef44a7721c1d';

final class CommandTaskOutputFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<CommandTaskOutput>,
          (String, {int? stdoutOffset, int? stderrOffset})
        > {
  CommandTaskOutputFamily._()
    : super(
        retry: null,
        name: r'commandTaskOutputProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  CommandTaskOutputProvider call(
    String id, {
    int? stdoutOffset,
    int? stderrOffset,
  }) => CommandTaskOutputProvider._(
    argument: (id, stdoutOffset: stdoutOffset, stderrOffset: stderrOffset),
    from: this,
  );

  @override
  String toString() => r'commandTaskOutputProvider';
}
