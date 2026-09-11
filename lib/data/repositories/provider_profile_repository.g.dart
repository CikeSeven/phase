// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'provider_profile_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(providerProfileRepository)
final providerProfileRepositoryProvider = ProviderProfileRepositoryProvider._();

final class ProviderProfileRepositoryProvider
    extends
        $FunctionalProvider<
          ProviderProfileRepository,
          ProviderProfileRepository,
          ProviderProfileRepository
        >
    with $Provider<ProviderProfileRepository> {
  ProviderProfileRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'providerProfileRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$providerProfileRepositoryHash();

  @$internal
  @override
  $ProviderElement<ProviderProfileRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ProviderProfileRepository create(Ref ref) {
    return providerProfileRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ProviderProfileRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ProviderProfileRepository>(value),
    );
  }
}

String _$providerProfileRepositoryHash() =>
    r'35701c1e12c5d374e43a3be792fb88c5119410c1';

/// 一次性迁移：存量模型的 supportsReasoning 统一翻为 true。
/// 失败不阻断读取（下次启动重试）。

@ProviderFor(reasoningSupportMigration)
final reasoningSupportMigrationProvider = ReasoningSupportMigrationProvider._();

/// 一次性迁移：存量模型的 supportsReasoning 统一翻为 true。
/// 失败不阻断读取（下次启动重试）。

final class ReasoningSupportMigrationProvider
    extends $FunctionalProvider<AsyncValue<void>, void, FutureOr<void>>
    with $FutureModifier<void>, $FutureProvider<void> {
  /// 一次性迁移：存量模型的 supportsReasoning 统一翻为 true。
  /// 失败不阻断读取（下次启动重试）。
  ReasoningSupportMigrationProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'reasoningSupportMigrationProvider',
        isAutoDispose: false,
        dependencies: <ProviderOrFamily>[
          settingsStorageProvider,
          providerProfileRepositoryProvider,
        ],
        $allTransitiveDependencies: <ProviderOrFamily>[
          ReasoningSupportMigrationProvider.$allTransitiveDependencies0,
          ReasoningSupportMigrationProvider.$allTransitiveDependencies1,
          ReasoningSupportMigrationProvider.$allTransitiveDependencies2,
        ],
      );

  static final $allTransitiveDependencies0 = settingsStorageProvider;
  static final $allTransitiveDependencies1 =
      SettingsStorageProvider.$allTransitiveDependencies0;
  static final $allTransitiveDependencies2 = providerProfileRepositoryProvider;

  @override
  String debugGetCreateSourceHash() => _$reasoningSupportMigrationHash();

  @$internal
  @override
  $FutureProviderElement<void> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<void> create(Ref ref) {
    return reasoningSupportMigration(ref);
  }
}

String _$reasoningSupportMigrationHash() =>
    r'53e7b0a3a3b072ef1a5c3f504878d7052da38ee9';

/// 服务商配置列表流；先等一次性迁移完成再发出，避免读到迁移前的旧标记。

@ProviderFor(providerProfiles)
final providerProfilesProvider = ProviderProfilesProvider._();

/// 服务商配置列表流；先等一次性迁移完成再发出，避免读到迁移前的旧标记。

final class ProviderProfilesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ProviderProfile>>,
          List<ProviderProfile>,
          Stream<List<ProviderProfile>>
        >
    with
        $FutureModifier<List<ProviderProfile>>,
        $StreamProvider<List<ProviderProfile>> {
  /// 服务商配置列表流；先等一次性迁移完成再发出，避免读到迁移前的旧标记。
  ProviderProfilesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'providerProfilesProvider',
        isAutoDispose: true,
        dependencies: <ProviderOrFamily>[
          reasoningSupportMigrationProvider,
          providerProfileRepositoryProvider,
        ],
        $allTransitiveDependencies: <ProviderOrFamily>{
          ProviderProfilesProvider.$allTransitiveDependencies0,
          ProviderProfilesProvider.$allTransitiveDependencies1,
          ProviderProfilesProvider.$allTransitiveDependencies2,
          ProviderProfilesProvider.$allTransitiveDependencies3,
        },
      );

  static final $allTransitiveDependencies0 = reasoningSupportMigrationProvider;
  static final $allTransitiveDependencies1 =
      ReasoningSupportMigrationProvider.$allTransitiveDependencies0;
  static final $allTransitiveDependencies2 =
      ReasoningSupportMigrationProvider.$allTransitiveDependencies1;
  static final $allTransitiveDependencies3 =
      ReasoningSupportMigrationProvider.$allTransitiveDependencies2;

  @override
  String debugGetCreateSourceHash() => _$providerProfilesHash();

  @$internal
  @override
  $StreamProviderElement<List<ProviderProfile>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<ProviderProfile>> create(Ref ref) {
    return providerProfiles(ref);
  }
}

String _$providerProfilesHash() => r'868f8160c9158a0eac2c1a8e299cd488440920fe';
