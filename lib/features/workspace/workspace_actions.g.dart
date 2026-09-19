// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workspace_actions.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(workspace)
final workspaceProvider = WorkspaceFamily._();

final class WorkspaceProvider
    extends
        $FunctionalProvider<
          AsyncValue<Workspace?>,
          Workspace?,
          FutureOr<Workspace?>
        >
    with $FutureModifier<Workspace?>, $FutureProvider<Workspace?> {
  WorkspaceProvider._({
    required WorkspaceFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'workspaceProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$workspaceHash();

  @override
  String toString() {
    return r'workspaceProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<Workspace?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Workspace?> create(Ref ref) {
    final argument = this.argument as String;
    return workspace(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is WorkspaceProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$workspaceHash() => r'54a6def19ef086019837eda471c299a874b471ae';

final class WorkspaceFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<Workspace?>, String> {
  WorkspaceFamily._()
    : super(
        retry: null,
        name: r'workspaceProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  WorkspaceProvider call(String id) =>
      WorkspaceProvider._(argument: id, from: this);

  @override
  String toString() => r'workspaceProvider';
}

@ProviderFor(workspaceEntries)
final workspaceEntriesProvider = WorkspaceEntriesFamily._();

final class WorkspaceEntriesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<(String, int)>>,
          List<(String, int)>,
          FutureOr<List<(String, int)>>
        >
    with
        $FutureModifier<List<(String, int)>>,
        $FutureProvider<List<(String, int)>> {
  WorkspaceEntriesProvider._({
    required WorkspaceEntriesFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: null,
         name: r'workspaceEntriesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$workspaceEntriesHash();

  @override
  String toString() {
    return r'workspaceEntriesProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<List<(String, int)>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<(String, int)>> create(Ref ref) {
    final argument = this.argument as (String, String);
    return workspaceEntries(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is WorkspaceEntriesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$workspaceEntriesHash() => r'ad2a1f1ab9917794123d4478c77bd12fbabbf6bd';

final class WorkspaceEntriesFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<(String, int)>>,
          (String, String)
        > {
  WorkspaceEntriesFamily._()
    : super(
        retry: null,
        name: r'workspaceEntriesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  WorkspaceEntriesProvider call(String id, String path) =>
      WorkspaceEntriesProvider._(argument: (id, path), from: this);

  @override
  String toString() => r'workspaceEntriesProvider';
}

@ProviderFor(WorkspaceActions)
final workspaceActionsProvider = WorkspaceActionsProvider._();

final class WorkspaceActionsProvider
    extends $NotifierProvider<WorkspaceActions, AsyncValue<void>> {
  WorkspaceActionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workspaceActionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workspaceActionsHash();

  @$internal
  @override
  WorkspaceActions create() => WorkspaceActions();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<void> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<void>>(value),
    );
  }
}

String _$workspaceActionsHash() => r'a8cfb67b9d2ea61c6c83f0eb68c07979969d63f3';

abstract class _$WorkspaceActions extends $Notifier<AsyncValue<void>> {
  AsyncValue<void> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<void>, AsyncValue<void>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<void>, AsyncValue<void>>,
              AsyncValue<void>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
