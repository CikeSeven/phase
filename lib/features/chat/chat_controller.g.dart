// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 页面操作入口和展示投影；循环、流缓冲及资源生命周期由本次驱动持有。

@ProviderFor(ChatController)
final chatControllerProvider = ChatControllerProvider._();

/// 页面操作入口和展示投影；循环、流缓冲及资源生命周期由本次驱动持有。
final class ChatControllerProvider
    extends $NotifierProvider<ChatController, ChatState> {
  /// 页面操作入口和展示投影；循环、流缓冲及资源生命周期由本次驱动持有。
  ChatControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'chatControllerProvider',
        isAutoDispose: false,
        dependencies: <ProviderOrFamily>[
          modelSelectionProvider,
          currentAssistantProvider,
          activeConversationProvider,
          settingsStorageProvider,
          modelCatalogProvider,
          chatRunFactoryProvider,
          chatToolRuntimeFactoryProvider,
        ],
        $allTransitiveDependencies: <ProviderOrFamily>{
          ChatControllerProvider.$allTransitiveDependencies0,
          ChatControllerProvider.$allTransitiveDependencies1,
          ChatControllerProvider.$allTransitiveDependencies2,
          ChatControllerProvider.$allTransitiveDependencies3,
          ChatControllerProvider.$allTransitiveDependencies4,
          ChatControllerProvider.$allTransitiveDependencies5,
          ChatControllerProvider.$allTransitiveDependencies6,
          ChatControllerProvider.$allTransitiveDependencies7,
          ChatControllerProvider.$allTransitiveDependencies8,
          ChatControllerProvider.$allTransitiveDependencies9,
          ChatControllerProvider.$allTransitiveDependencies10,
          ChatControllerProvider.$allTransitiveDependencies11,
          ChatControllerProvider.$allTransitiveDependencies12,
        },
      );

  static final $allTransitiveDependencies0 = modelSelectionProvider;
  static final $allTransitiveDependencies1 =
      ModelSelectionProvider.$allTransitiveDependencies0;
  static final $allTransitiveDependencies2 =
      ModelSelectionProvider.$allTransitiveDependencies1;
  static final $allTransitiveDependencies3 =
      ModelSelectionProvider.$allTransitiveDependencies2;
  static final $allTransitiveDependencies4 =
      ModelSelectionProvider.$allTransitiveDependencies3;
  static final $allTransitiveDependencies5 =
      ModelSelectionProvider.$allTransitiveDependencies4;
  static final $allTransitiveDependencies6 =
      ModelSelectionProvider.$allTransitiveDependencies5;
  static final $allTransitiveDependencies7 =
      ModelSelectionProvider.$allTransitiveDependencies6;
  static final $allTransitiveDependencies8 = currentAssistantProvider;
  static final $allTransitiveDependencies9 = modelCatalogProvider;
  static final $allTransitiveDependencies10 =
      ModelCatalogProvider.$allTransitiveDependencies0;
  static final $allTransitiveDependencies11 = chatRunFactoryProvider;
  static final $allTransitiveDependencies12 =
      ChatRunFactoryProvider.$allTransitiveDependencies0;

  @override
  String debugGetCreateSourceHash() => _$chatControllerHash();

  @$internal
  @override
  ChatController create() => ChatController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ChatState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ChatState>(value),
    );
  }
}

String _$chatControllerHash() => r'607c663bcc1e8e1884cdb4362019cac3be85fc55';

/// 页面操作入口和展示投影；循环、流缓冲及资源生命周期由本次驱动持有。

abstract class _$ChatController extends $Notifier<ChatState> {
  ChatState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ChatState, ChatState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ChatState, ChatState>,
              ChatState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
