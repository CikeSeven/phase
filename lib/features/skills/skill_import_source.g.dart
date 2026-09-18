// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'skill_import_source.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(skillImportSource)
final skillImportSourceProvider = SkillImportSourceProvider._();

final class SkillImportSourceProvider
    extends
        $FunctionalProvider<
          SkillImportSource,
          SkillImportSource,
          SkillImportSource
        >
    with $Provider<SkillImportSource> {
  SkillImportSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'skillImportSourceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$skillImportSourceHash();

  @$internal
  @override
  $ProviderElement<SkillImportSource> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SkillImportSource create(Ref ref) {
    return skillImportSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SkillImportSource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SkillImportSource>(value),
    );
  }
}

String _$skillImportSourceHash() => r'fc264e68adc02d7218957a05f71618f5e035c373';
