// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 内置工具集：文件路径由当前环境或授权 URI 解释，HTTP 走独立 Dio 实例。
///
/// 单独开注入点是为了让测试能替换工具集（记录调用的假工具、替代网络实现），
/// 与 [aiProviderFactoryProvider] 同样的理由。

@ProviderFor(toolRegistry)
final toolRegistryProvider = ToolRegistryProvider._();

/// 内置工具集：文件路径由当前环境或授权 URI 解释，HTTP 走独立 Dio 实例。
///
/// 单独开注入点是为了让测试能替换工具集（记录调用的假工具、替代网络实现），
/// 与 [aiProviderFactoryProvider] 同样的理由。

final class ToolRegistryProvider
    extends $FunctionalProvider<ToolRegistry, ToolRegistry, ToolRegistry>
    with $Provider<ToolRegistry> {
  /// 内置工具集：文件路径由当前环境或授权 URI 解释，HTTP 走独立 Dio 实例。
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

String _$artifactStorageHash() => r'f4da8ac5911f15d72fad7f51be70c8c0da5bfb28';

/// 助手列表；先确保内置助手存在再发出。

@ProviderFor(assistants)
final assistantsProvider = AssistantsProvider._();

/// 助手列表；先确保内置助手存在再发出。

final class AssistantsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Assistant>>,
          List<Assistant>,
          Stream<List<Assistant>>
        >
    with $FutureModifier<List<Assistant>>, $StreamProvider<List<Assistant>> {
  /// 助手列表；先确保内置助手存在再发出。
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
/// 或绑定的助手已被删除时回退到列表第一个（内置助手）。
///
/// 只读内存中的列表与线程：调用方先 await 好这两路数据（见
/// [awaitAssistantContext]），避免把「尚未加载」误判成「没有助手」。

@ProviderFor(currentAssistant)
final currentAssistantProvider = CurrentAssistantFamily._();

/// 当前生效的助手。
///
/// 已打开的会话用会话绑定的助手；新会话用草稿助手；两者都没有、
/// 或绑定的助手已被删除时回退到列表第一个（内置助手）。
///
/// 只读内存中的列表与线程：调用方先 await 好这两路数据（见
/// [awaitAssistantContext]），避免把「尚未加载」误判成「没有助手」。

final class CurrentAssistantProvider
    extends $FunctionalProvider<Assistant?, Assistant?, Assistant?>
    with $Provider<Assistant?> {
  /// 当前生效的助手。
  ///
  /// 已打开的会话用会话绑定的助手；新会话用草稿助手；两者都没有、
  /// 或绑定的助手已被删除时回退到列表第一个（内置助手）。
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
/// 或绑定的助手已被删除时回退到列表第一个（内置助手）。
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
  /// 或绑定的助手已被删除时回退到列表第一个（内置助手）。
  ///
  /// 只读内存中的列表与线程：调用方先 await 好这两路数据（见
  /// [awaitAssistantContext]），避免把「尚未加载」误判成「没有助手」。

  CurrentAssistantProvider call(ActiveConversationState active) =>
      CurrentAssistantProvider._(argument: active, from: this);

  @override
  String toString() => r'currentAssistantProvider';
}

/// 装配点只提供依赖；目录发现、运行创建和资源启动由对应组件显式调用。

@ProviderFor(chatToolRuntimeFactory)
final chatToolRuntimeFactoryProvider = ChatToolRuntimeFactoryProvider._();

/// 装配点只提供依赖；目录发现、运行创建和资源启动由对应组件显式调用。

final class ChatToolRuntimeFactoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<ChatToolRuntimeFactory>,
          ChatToolRuntimeFactory,
          FutureOr<ChatToolRuntimeFactory>
        >
    with
        $FutureModifier<ChatToolRuntimeFactory>,
        $FutureProvider<ChatToolRuntimeFactory> {
  /// 装配点只提供依赖；目录发现、运行创建和资源启动由对应组件显式调用。
  ChatToolRuntimeFactoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'chatToolRuntimeFactoryProvider',
        isAutoDispose: false,
        dependencies: <ProviderOrFamily>[
          settingsStorageProvider,
          webSearchRepositoryProvider,
        ],
        $allTransitiveDependencies: <ProviderOrFamily>[
          ChatToolRuntimeFactoryProvider.$allTransitiveDependencies0,
          ChatToolRuntimeFactoryProvider.$allTransitiveDependencies1,
          ChatToolRuntimeFactoryProvider.$allTransitiveDependencies2,
        ],
      );

  static final $allTransitiveDependencies0 = settingsStorageProvider;
  static final $allTransitiveDependencies1 =
      SettingsStorageProvider.$allTransitiveDependencies0;
  static final $allTransitiveDependencies2 = webSearchRepositoryProvider;

  @override
  String debugGetCreateSourceHash() => _$chatToolRuntimeFactoryHash();

  @$internal
  @override
  $FutureProviderElement<ChatToolRuntimeFactory> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ChatToolRuntimeFactory> create(Ref ref) {
    return chatToolRuntimeFactory(ref);
  }
}

String _$chatToolRuntimeFactoryHash() =>
    r'16cc3aa11f272b364ae60e68aa3267a86e4d4548';

@ProviderFor(chatRunFactory)
final chatRunFactoryProvider = ChatRunFactoryProvider._();

final class ChatRunFactoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<ChatRunFactory>,
          ChatRunFactory,
          FutureOr<ChatRunFactory>
        >
    with $FutureModifier<ChatRunFactory>, $FutureProvider<ChatRunFactory> {
  ChatRunFactoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'chatRunFactoryProvider',
        isAutoDispose: false,
        dependencies: <ProviderOrFamily>[
          chatToolRuntimeFactoryProvider,
          modelCatalogProvider,
        ],
        $allTransitiveDependencies: <ProviderOrFamily>{
          ChatRunFactoryProvider.$allTransitiveDependencies0,
          ChatRunFactoryProvider.$allTransitiveDependencies1,
          ChatRunFactoryProvider.$allTransitiveDependencies2,
          ChatRunFactoryProvider.$allTransitiveDependencies3,
          ChatRunFactoryProvider.$allTransitiveDependencies4,
          ChatRunFactoryProvider.$allTransitiveDependencies5,
        },
      );

  static final $allTransitiveDependencies0 = chatToolRuntimeFactoryProvider;
  static final $allTransitiveDependencies1 =
      ChatToolRuntimeFactoryProvider.$allTransitiveDependencies0;
  static final $allTransitiveDependencies2 =
      ChatToolRuntimeFactoryProvider.$allTransitiveDependencies1;
  static final $allTransitiveDependencies3 =
      ChatToolRuntimeFactoryProvider.$allTransitiveDependencies2;
  static final $allTransitiveDependencies4 = modelCatalogProvider;
  static final $allTransitiveDependencies5 =
      ModelCatalogProvider.$allTransitiveDependencies0;

  @override
  String debugGetCreateSourceHash() => _$chatRunFactoryHash();

  @$internal
  @override
  $FutureProviderElement<ChatRunFactory> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ChatRunFactory> create(Ref ref) {
    return chatRunFactory(ref);
  }
}

String _$chatRunFactoryHash() => r'5cc4f50020e03e1672463a1e61e46ed6366460c7';

@ProviderFor(chatContextCoordinator)
final chatContextCoordinatorProvider = ChatContextCoordinatorProvider._();

final class ChatContextCoordinatorProvider
    extends
        $FunctionalProvider<
          AsyncValue<ChatContextCoordinator>,
          ChatContextCoordinator,
          FutureOr<ChatContextCoordinator>
        >
    with
        $FutureModifier<ChatContextCoordinator>,
        $FutureProvider<ChatContextCoordinator> {
  ChatContextCoordinatorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'chatContextCoordinatorProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$chatContextCoordinatorHash();

  @$internal
  @override
  $FutureProviderElement<ChatContextCoordinator> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ChatContextCoordinator> create(Ref ref) {
    return chatContextCoordinator(ref);
  }
}

String _$chatContextCoordinatorHash() =>
    r'fccbbcf0493edc890c21f3858d9dbba1edaf8475';

@ProviderFor(modelTurnRunnerFactory)
final modelTurnRunnerFactoryProvider = ModelTurnRunnerFactoryProvider._();

final class ModelTurnRunnerFactoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<ModelTurnRunnerFactory>,
          ModelTurnRunnerFactory,
          FutureOr<ModelTurnRunnerFactory>
        >
    with
        $FutureModifier<ModelTurnRunnerFactory>,
        $FutureProvider<ModelTurnRunnerFactory> {
  ModelTurnRunnerFactoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'modelTurnRunnerFactoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$modelTurnRunnerFactoryHash();

  @$internal
  @override
  $FutureProviderElement<ModelTurnRunnerFactory> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ModelTurnRunnerFactory> create(Ref ref) {
    return modelTurnRunnerFactory(ref);
  }
}

String _$modelTurnRunnerFactoryHash() =>
    r'0113352033071a69df1dacebad7bf0eb041c982e';
