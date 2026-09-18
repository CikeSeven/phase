// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'skill_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SkillImportController)
final skillImportControllerProvider = SkillImportControllerFamily._();

final class SkillImportControllerProvider
    extends $NotifierProvider<SkillImportController, SkillImportState> {
  SkillImportControllerProvider._({
    required SkillImportControllerFamily super.from,
    required String? super.argument,
  }) : super(
         retry: null,
         name: r'skillImportControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$skillImportControllerHash();

  @override
  String toString() {
    return r'skillImportControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  SkillImportController create() => SkillImportController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SkillImportState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SkillImportState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SkillImportControllerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$skillImportControllerHash() =>
    r'd991d6b6d60a1621671233cae9d1b185bace63f5';

final class SkillImportControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          SkillImportController,
          SkillImportState,
          SkillImportState,
          SkillImportState,
          String?
        > {
  SkillImportControllerFamily._()
    : super(
        retry: null,
        name: r'skillImportControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  SkillImportControllerProvider call(String? replaceId) =>
      SkillImportControllerProvider._(argument: replaceId, from: this);

  @override
  String toString() => r'skillImportControllerProvider';
}

abstract class _$SkillImportController extends $Notifier<SkillImportState> {
  late final _$args = ref.$arg as String?;
  String? get replaceId => _$args;

  SkillImportState build(String? replaceId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<SkillImportState, SkillImportState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SkillImportState, SkillImportState>,
              SkillImportState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}

@ProviderFor(SkillController)
final skillControllerProvider = SkillControllerFamily._();

final class SkillControllerProvider
    extends $AsyncNotifierProvider<SkillController, SkillInstallation?> {
  SkillControllerProvider._({
    required SkillControllerFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'skillControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$skillControllerHash();

  @override
  String toString() {
    return r'skillControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  SkillController create() => SkillController();

  @override
  bool operator ==(Object other) {
    return other is SkillControllerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$skillControllerHash() => r'f8dc99dba3bd9057df03222d98067e53e104c539';

final class SkillControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          SkillController,
          AsyncValue<SkillInstallation?>,
          SkillInstallation?,
          FutureOr<SkillInstallation?>,
          String
        > {
  SkillControllerFamily._()
    : super(
        retry: null,
        name: r'skillControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  SkillControllerProvider call(String id) =>
      SkillControllerProvider._(argument: id, from: this);

  @override
  String toString() => r'skillControllerProvider';
}

abstract class _$SkillController extends $AsyncNotifier<SkillInstallation?> {
  late final _$args = ref.$arg as String;
  String get id => _$args;

  FutureOr<SkillInstallation?> build(String id);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<SkillInstallation?>, SkillInstallation?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<SkillInstallation?>, SkillInstallation?>,
              AsyncValue<SkillInstallation?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
