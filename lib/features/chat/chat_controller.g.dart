// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 聊天状态在应用生命周期内保留：切到设置页再回来不应丢失当前会话与流式状态。

@ProviderFor(ChatController)
final chatControllerProvider = ChatControllerProvider._();

/// 聊天状态在应用生命周期内保留：切到设置页再回来不应丢失当前会话与流式状态。
final class ChatControllerProvider
    extends $NotifierProvider<ChatController, ChatState> {
  /// 聊天状态在应用生命周期内保留：切到设置页再回来不应丢失当前会话与流式状态。
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

String _$chatControllerHash() => r'5c9a6268a84de29a642d0d05c6b1c68c93e3eef7';

/// 聊天状态在应用生命周期内保留：切到设置页再回来不应丢失当前会话与流式状态。

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

/// 内置工具集：文件工具只访问应用私有目录，HTTP 工具走独立的 Dio 实例。
///
/// 单独开注入点是为了让测试能替换工具集（记录调用的假工具、替代网络实现），
/// 与 [aiProviderFactoryProvider] 同样的理由。

@ProviderFor(toolRegistry)
final toolRegistryProvider = ToolRegistryProvider._();

/// 内置工具集：文件工具只访问应用私有目录，HTTP 工具走独立的 Dio 实例。
///
/// 单独开注入点是为了让测试能替换工具集（记录调用的假工具、替代网络实现），
/// 与 [aiProviderFactoryProvider] 同样的理由。

final class ToolRegistryProvider
    extends $FunctionalProvider<ToolRegistry, ToolRegistry, ToolRegistry>
    with $Provider<ToolRegistry> {
  /// 内置工具集：文件工具只访问应用私有目录，HTTP 工具走独立的 Dio 实例。
  ///
  /// 单独开注入点是为了让测试能替换工具集（记录调用的假工具、替代网络实现），
  /// 与 [aiProviderFactoryProvider] 同样的理由。
  ToolRegistryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'toolRegistryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$toolRegistryHash();

  @$internal
  @override
  $ProviderElement<ToolRegistry> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ToolRegistry create(Ref ref) {
    return toolRegistry(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ToolRegistry value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ToolRegistry>(value),
    );
  }
}

String _$toolRegistryHash() => r'5af1cc322b2a9262377cf79604ad14d04e905e88';

/// 单一重试预算，协议传输不再叠加第二层自动重试。

@ProviderFor(modelRetryPolicy)
final modelRetryPolicyProvider = ModelRetryPolicyProvider._();

/// 单一重试预算，协议传输不再叠加第二层自动重试。

final class ModelRetryPolicyProvider
    extends
        $FunctionalProvider<
          ModelRetryPolicy,
          ModelRetryPolicy,
          ModelRetryPolicy
        >
    with $Provider<ModelRetryPolicy> {
  /// 单一重试预算，协议传输不再叠加第二层自动重试。
  ModelRetryPolicyProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'modelRetryPolicyProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$modelRetryPolicyHash();

  @$internal
  @override
  $ProviderElement<ModelRetryPolicy> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ModelRetryPolicy create(Ref ref) {
    return modelRetryPolicy(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ModelRetryPolicy value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ModelRetryPolicy>(value),
    );
  }
}

String _$modelRetryPolicyHash() => r'b4ddba276e47dcee02ad828fb86c647f8a0608cd';

/// 工具运行的存储能力：会话附件、按会话隔离的产物目录与产物登记。
///
/// 附件索引由仓储注入：数据源只依赖模型与文件系统。

@ProviderFor(artifactStorage)
final artifactStorageProvider = ArtifactStorageProvider._();

/// 工具运行的存储能力：会话附件、按会话隔离的产物目录与产物登记。
///
/// 附件索引由仓储注入：数据源只依赖模型与文件系统。

final class ArtifactStorageProvider
    extends
        $FunctionalProvider<
          AsyncValue<ArtifactStorage>,
          ArtifactStorage,
          FutureOr<ArtifactStorage>
        >
    with $FutureModifier<ArtifactStorage>, $FutureProvider<ArtifactStorage> {
  /// 工具运行的存储能力：会话附件、按会话隔离的产物目录与产物登记。
  ///
  /// 附件索引由仓储注入：数据源只依赖模型与文件系统。
  ArtifactStorageProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'artifactStorageProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$artifactStorageHash();

  @$internal
  @override
  $FutureProviderElement<ArtifactStorage> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ArtifactStorage> create(Ref ref) {
    return artifactStorage(ref);
  }
}

String _$artifactStorageHash() => r'2bb76c2793cbd29413863ba40b56353cb59fb727';

/// 会话列表流（置顶优先、按更新时间倒序）。

@ProviderFor(conversations)
final conversationsProvider = ConversationsProvider._();

/// 会话列表流（置顶优先、按更新时间倒序）。

final class ConversationsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Conversation>>,
          List<Conversation>,
          Stream<List<Conversation>>
        >
    with
        $FutureModifier<List<Conversation>>,
        $StreamProvider<List<Conversation>> {
  /// 会话列表流（置顶优先、按更新时间倒序）。
  ConversationsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'conversationsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$conversationsHash();

  @$internal
  @override
  $StreamProviderElement<List<Conversation>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Conversation>> create(Ref ref) {
    return conversations(ref);
  }
}

String _$conversationsHash() => r'2ac16e57c492917710a601ffe21e2efe7257c30a';

/// 某会话的当前分支视图。

@ProviderFor(conversationThread)
final conversationThreadProvider = ConversationThreadFamily._();

/// 某会话的当前分支视图。

final class ConversationThreadProvider
    extends
        $FunctionalProvider<
          AsyncValue<ConversationThread?>,
          ConversationThread?,
          Stream<ConversationThread?>
        >
    with
        $FutureModifier<ConversationThread?>,
        $StreamProvider<ConversationThread?> {
  /// 某会话的当前分支视图。
  ConversationThreadProvider._({
    required ConversationThreadFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'conversationThreadProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$conversationThreadHash();

  @override
  String toString() {
    return r'conversationThreadProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<ConversationThread?> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<ConversationThread?> create(Ref ref) {
    final argument = this.argument as String;
    return conversationThread(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ConversationThreadProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$conversationThreadHash() =>
    r'5aac3bb5841d39801bf7aceb65d941b8c05a1dc1';

/// 某会话的当前分支视图。

final class ConversationThreadFamily extends $Family
    with $FunctionalFamilyOverride<Stream<ConversationThread?>, String> {
  ConversationThreadFamily._()
    : super(
        retry: null,
        name: r'conversationThreadProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 某会话的当前分支视图。

  ConversationThreadProvider call(String conversationId) =>
      ConversationThreadProvider._(argument: conversationId, from: this);

  @override
  String toString() => r'conversationThreadProvider';
}

/// 助手列表；空库时先写入内置助手再发出，保证始终至少有一个助手。

@ProviderFor(assistants)
final assistantsProvider = AssistantsProvider._();

/// 助手列表；空库时先写入内置助手再发出，保证始终至少有一个助手。

final class AssistantsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Assistant>>,
          List<Assistant>,
          Stream<List<Assistant>>
        >
    with $FutureModifier<List<Assistant>>, $StreamProvider<List<Assistant>> {
  /// 助手列表；空库时先写入内置助手再发出，保证始终至少有一个助手。
  AssistantsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'assistantsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$assistantsHash();

  @$internal
  @override
  $StreamProviderElement<List<Assistant>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Assistant>> create(Ref ref) {
    return assistants(ref);
  }
}

String _$assistantsHash() => r'e669126c276bb39598993f28b6ad81678621ab97';

/// 当前生效的助手。
///
/// 已打开的会话用会话绑定的助手；新会话用草稿助手；两者都没有、
/// 或绑定的助手已被删除时回退到列表第一个（首次建库时为内置普通助手）。
///
/// 只读内存中的列表与线程：调用方先 await 好这两路数据（见
/// [awaitAssistantContext]），避免把「尚未加载」误判成「没有助手」。

@ProviderFor(currentAssistant)
final currentAssistantProvider = CurrentAssistantFamily._();

/// 当前生效的助手。
///
/// 已打开的会话用会话绑定的助手；新会话用草稿助手；两者都没有、
/// 或绑定的助手已被删除时回退到列表第一个（首次建库时为内置普通助手）。
///
/// 只读内存中的列表与线程：调用方先 await 好这两路数据（见
/// [awaitAssistantContext]），避免把「尚未加载」误判成「没有助手」。

final class CurrentAssistantProvider
    extends $FunctionalProvider<Assistant?, Assistant?, Assistant?>
    with $Provider<Assistant?> {
  /// 当前生效的助手。
  ///
  /// 已打开的会话用会话绑定的助手；新会话用草稿助手；两者都没有、
  /// 或绑定的助手已被删除时回退到列表第一个（首次建库时为内置普通助手）。
  ///
  /// 只读内存中的列表与线程：调用方先 await 好这两路数据（见
  /// [awaitAssistantContext]），避免把「尚未加载」误判成「没有助手」。
  CurrentAssistantProvider._({
    required CurrentAssistantFamily super.from,
    required ActiveConversationState super.argument,
  }) : super(
         retry: null,
         name: r'currentAssistantProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  static final $allTransitiveDependencies0 = assistantsProvider;
  static final $allTransitiveDependencies1 = conversationThreadProvider;

  @override
  String debugGetCreateSourceHash() => _$currentAssistantHash();

  @override
  String toString() {
    return r'currentAssistantProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<Assistant?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Assistant? create(Ref ref) {
    final argument = this.argument as ActiveConversationState;
    return currentAssistant(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Assistant? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Assistant?>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is CurrentAssistantProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$currentAssistantHash() => r'22256fa8d478f1e00d6839666171601a5a4f4038';

/// 当前生效的助手。
///
/// 已打开的会话用会话绑定的助手；新会话用草稿助手；两者都没有、
/// 或绑定的助手已被删除时回退到列表第一个（首次建库时为内置普通助手）。
///
/// 只读内存中的列表与线程：调用方先 await 好这两路数据（见
/// [awaitAssistantContext]），避免把「尚未加载」误判成「没有助手」。

final class CurrentAssistantFamily extends $Family
    with $FunctionalFamilyOverride<Assistant?, ActiveConversationState> {
  CurrentAssistantFamily._()
    : super(
        retry: null,
        name: r'currentAssistantProvider',
        dependencies: <ProviderOrFamily>[
          assistantsProvider,
          conversationThreadProvider,
        ],
        $allTransitiveDependencies: <ProviderOrFamily>[
          CurrentAssistantProvider.$allTransitiveDependencies0,
          CurrentAssistantProvider.$allTransitiveDependencies1,
        ],
        isAutoDispose: false,
      );

  /// 当前生效的助手。
  ///
  /// 已打开的会话用会话绑定的助手；新会话用草稿助手；两者都没有、
  /// 或绑定的助手已被删除时回退到列表第一个（首次建库时为内置普通助手）。
  ///
  /// 只读内存中的列表与线程：调用方先 await 好这两路数据（见
  /// [awaitAssistantContext]），避免把「尚未加载」误判成「没有助手」。

  CurrentAssistantProvider call(ActiveConversationState active) =>
      CurrentAssistantProvider._(argument: active, from: this);

  @override
  String toString() => r'currentAssistantProvider';
}

@ProviderFor(ActiveConversation)
final activeConversationProvider = ActiveConversationProvider._();

final class ActiveConversationProvider
    extends $NotifierProvider<ActiveConversation, ActiveConversationState> {
  ActiveConversationProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activeConversationProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activeConversationHash();

  @$internal
  @override
  ActiveConversation create() => ActiveConversation();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ActiveConversationState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ActiveConversationState>(value),
    );
  }
}

String _$activeConversationHash() =>
    r'f48db7acd16d8af76913812abdf6cb6b8f1b5758';

abstract class _$ActiveConversation extends $Notifier<ActiveConversationState> {
  ActiveConversationState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<ActiveConversationState, ActiveConversationState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ActiveConversationState, ActiveConversationState>,
              ActiveConversationState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
