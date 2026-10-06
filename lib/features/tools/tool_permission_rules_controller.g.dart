// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tool_permission_rules_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ToolPermissionRulesController)
final toolPermissionRulesControllerProvider =
    ToolPermissionRulesControllerProvider._();

final class ToolPermissionRulesControllerProvider
    extends
        $AsyncNotifierProvider<
          ToolPermissionRulesController,
          List<ToolPermissionRule>
        > {
  ToolPermissionRulesControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'toolPermissionRulesControllerProvider',
        isAutoDispose: true,
        dependencies: <ProviderOrFamily>[settingsStorageProvider],
        $allTransitiveDependencies: <ProviderOrFamily>[
          ToolPermissionRulesControllerProvider.$allTransitiveDependencies0,
          ToolPermissionRulesControllerProvider.$allTransitiveDependencies1,
        ],
      );

  static final $allTransitiveDependencies0 = settingsStorageProvider;
  static final $allTransitiveDependencies1 =
      SettingsStorageProvider.$allTransitiveDependencies0;

  @override
  String debugGetCreateSourceHash() => _$toolPermissionRulesControllerHash();

  @$internal
  @override
  ToolPermissionRulesController create() => ToolPermissionRulesController();
}

String _$toolPermissionRulesControllerHash() =>
    r'70ba5965069a710d86bef984d4ee18670b16ba92';

abstract class _$ToolPermissionRulesController
    extends $AsyncNotifier<List<ToolPermissionRule>> {
  FutureOr<List<ToolPermissionRule>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<List<ToolPermissionRule>>,
              List<ToolPermissionRule>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<ToolPermissionRule>>,
                List<ToolPermissionRule>
              >,
              AsyncValue<List<ToolPermissionRule>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
