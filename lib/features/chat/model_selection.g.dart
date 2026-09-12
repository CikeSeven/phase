// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'model_selection.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 模型选择：会话显式覆盖优先于助手默认，再取「最近使用」，
/// 否则回退到第一个服务商的默认模型 / 候选模型第一个。

@ProviderFor(ModelSelection)
final modelSelectionProvider = ModelSelectionProvider._();

/// 模型选择：会话显式覆盖优先于助手默认，再取「最近使用」，
/// 否则回退到第一个服务商的默认模型 / 候选模型第一个。
final class ModelSelectionProvider
    extends $AsyncNotifierProvider<ModelSelection, ChatModelSelection?> {
  /// 模型选择：会话显式覆盖优先于助手默认，再取「最近使用」，
  /// 否则回退到第一个服务商的默认模型 / 候选模型第一个。
  ModelSelectionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'modelSelectionProvider',
        isAutoDispose: false,
        dependencies: <ProviderOrFamily>[
          settingsStorageProvider,
          providerProfilesProvider,
          assistantsProvider,
          conversationThreadProvider,
          activeConversationProvider,
        ],
        $allTransitiveDependencies: <ProviderOrFamily>{
          ModelSelectionProvider.$allTransitiveDependencies0,
          ModelSelectionProvider.$allTransitiveDependencies1,
          ModelSelectionProvider.$allTransitiveDependencies2,
          ModelSelectionProvider.$allTransitiveDependencies3,
          ModelSelectionProvider.$allTransitiveDependencies4,
          ModelSelectionProvider.$allTransitiveDependencies5,
          ModelSelectionProvider.$allTransitiveDependencies6,
        },
      );

  static final $allTransitiveDependencies0 = settingsStorageProvider;
  static final $allTransitiveDependencies1 =
      SettingsStorageProvider.$allTransitiveDependencies0;
  static final $allTransitiveDependencies2 = providerProfilesProvider;
  static final $allTransitiveDependencies3 =
      ProviderProfilesProvider.$allTransitiveDependencies0;
  static final $allTransitiveDependencies4 = assistantsProvider;
  static final $allTransitiveDependencies5 = conversationThreadProvider;
  static final $allTransitiveDependencies6 = activeConversationProvider;

  @override
  String debugGetCreateSourceHash() => _$modelSelectionHash();

  @$internal
  @override
  ModelSelection create() => ModelSelection();
}

String _$modelSelectionHash() => r'a1f60eaaafe0d82b33f3fea237bee10451644296';

/// 模型选择：会话显式覆盖优先于助手默认，再取「最近使用」，
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
