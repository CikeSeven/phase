// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'skill_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(skillRepository)
final skillRepositoryProvider = SkillRepositoryProvider._();

final class SkillRepositoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<SkillRepository>,
          SkillRepository,
          FutureOr<SkillRepository>
        >
    with $FutureModifier<SkillRepository>, $FutureProvider<SkillRepository> {
  SkillRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'skillRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$skillRepositoryHash();

  @$internal
  @override
  $FutureProviderElement<SkillRepository> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<SkillRepository> create(Ref ref) {
    return skillRepository(ref);
  }
}

String _$skillRepositoryHash() => r'37ad6cc3018fdb67d50448338bffd9b0450b5188';

@ProviderFor(skillInstallations)
final skillInstallationsProvider = SkillInstallationsProvider._();

final class SkillInstallationsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<SkillInstallation>>,
          List<SkillInstallation>,
          Stream<List<SkillInstallation>>
        >
    with
        $FutureModifier<List<SkillInstallation>>,
        $StreamProvider<List<SkillInstallation>> {
  SkillInstallationsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'skillInstallationsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$skillInstallationsHash();

  @$internal
  @override
  $StreamProviderElement<List<SkillInstallation>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<SkillInstallation>> create(Ref ref) {
    return skillInstallations(ref);
  }
}

String _$skillInstallationsHash() =>
    r'dd12c8cdea49a95bca52373ff87542eae21b345e';
