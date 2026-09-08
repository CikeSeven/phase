// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'model_selection.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 模型选择：优先「最近使用」（shared_preferences），
/// 否则回退到第一个服务商的默认模型 / 候选模型第一个。

@ProviderFor(ModelSelection)
final modelSelectionProvider = ModelSelectionProvider._();

/// 模型选择：优先「最近使用」（shared_preferences），
/// 否则回退到第一个服务商的默认模型 / 候选模型第一个。
final class ModelSelectionProvider
    extends $AsyncNotifierProvider<ModelSelection, ChatModelSelection?> {
  /// 模型选择：优先「最近使用」（shared_preferences），
  /// 否则回退到第一个服务商的默认模型 / 候选模型第一个。
  ModelSelectionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'modelSelectionProvider',
        isAutoDispose: true,
        dependencies: <ProviderOrFamily>[settingsStorageProvider],
        $allTransitiveDependencies: <ProviderOrFamily>[
          ModelSelectionProvider.$allTransitiveDependencies0,
          ModelSelectionProvider.$allTransitiveDependencies1,
        ],
      );

  static final $allTransitiveDependencies0 = settingsStorageProvider;
  static final $allTransitiveDependencies1 =
      SettingsStorageProvider.$allTransitiveDependencies0;

  @override
  String debugGetCreateSourceHash() => _$modelSelectionHash();

  @$internal
  @override
  ModelSelection create() => ModelSelection();
}

String _$modelSelectionHash() => r'e2e490f59c41f034fe408bd029b310ee7e826f41';

/// 模型选择：优先「最近使用」（shared_preferences），
/// 否则回退到第一个服务商的默认模型 / 候选模型第一个。

abstract class _$ModelSelection extends $AsyncNotifier<ChatModelSelection?> {
  FutureOr<ChatModelSelection?> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<ChatModelSelection?>, ChatModelSelection?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<ChatModelSelection?>, ChatModelSelection?>,
              AsyncValue<ChatModelSelection?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
