// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'project_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(projects)
final projectsProvider = ProjectsProvider._();

final class ProjectsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Project>>,
          List<Project>,
          Stream<List<Project>>
        >
    with $FutureModifier<List<Project>>, $StreamProvider<List<Project>> {
  ProjectsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'projectsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$projectsHash();

  @$internal
  @override
  $StreamProviderElement<List<Project>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Project>> create(Ref ref) {
    return projects(ref);
  }
}

String _$projectsHash() => r'929f7be64fe9a04b2f0975880a1d76ccf277fc89';

@ProviderFor(project)
final projectProvider = ProjectFamily._();

final class ProjectProvider
    extends
        $FunctionalProvider<AsyncValue<Project?>, Project?, Stream<Project?>>
    with $FutureModifier<Project?>, $StreamProvider<Project?> {
  ProjectProvider._({
    required ProjectFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'projectProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$projectHash();

  @override
  String toString() {
    return r'projectProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<Project?> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<Project?> create(Ref ref) {
    final argument = this.argument as String;
    return project(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ProjectProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$projectHash() => r'93d4f9e4f017f60a85cff3a8804ec36faa8f76a8';

final class ProjectFamily extends $Family
    with $FunctionalFamilyOverride<Stream<Project?>, String> {
  ProjectFamily._()
    : super(
        retry: null,
        name: r'projectProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ProjectProvider call(String id) =>
      ProjectProvider._(argument: id, from: this);

  @override
  String toString() => r'projectProvider';
}

@ProviderFor(projectConversations)
final projectConversationsProvider = ProjectConversationsFamily._();

final class ProjectConversationsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Conversation>>,
          List<Conversation>,
          Stream<List<Conversation>>
        >
    with
        $FutureModifier<List<Conversation>>,
        $StreamProvider<List<Conversation>> {
  ProjectConversationsProvider._({
    required ProjectConversationsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'projectConversationsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$projectConversationsHash();

  @override
  String toString() {
    return r'projectConversationsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<Conversation>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Conversation>> create(Ref ref) {
    final argument = this.argument as String;
    return projectConversations(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ProjectConversationsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$projectConversationsHash() =>
    r'8fb972fa46d69e9a541ad8d5211efcfb99728c32';

final class ProjectConversationsFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<Conversation>>, String> {
  ProjectConversationsFamily._()
    : super(
        retry: null,
        name: r'projectConversationsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ProjectConversationsProvider call(String id) =>
      ProjectConversationsProvider._(argument: id, from: this);

  @override
  String toString() => r'projectConversationsProvider';
}

@ProviderFor(projectAttachments)
final projectAttachmentsProvider = ProjectAttachmentsFamily._();

final class ProjectAttachmentsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Attachment>>,
          List<Attachment>,
          Stream<List<Attachment>>
        >
    with $FutureModifier<List<Attachment>>, $StreamProvider<List<Attachment>> {
  ProjectAttachmentsProvider._({
    required ProjectAttachmentsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'projectAttachmentsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$projectAttachmentsHash();

  @override
  String toString() {
    return r'projectAttachmentsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<Attachment>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Attachment>> create(Ref ref) {
    final argument = this.argument as String;
    return projectAttachments(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ProjectAttachmentsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$projectAttachmentsHash() =>
    r'e5ca5ae377e46530eb50f83063c933b4f10fd221';

final class ProjectAttachmentsFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<Attachment>>, String> {
  ProjectAttachmentsFamily._()
    : super(
        retry: null,
        name: r'projectAttachmentsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ProjectAttachmentsProvider call(String id) =>
      ProjectAttachmentsProvider._(argument: id, from: this);

  @override
  String toString() => r'projectAttachmentsProvider';
}
