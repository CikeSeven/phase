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
        dependencies: <ProviderOrFamily>[modelSelectionProvider],
        $allTransitiveDependencies: <ProviderOrFamily>{
          ChatControllerProvider.$allTransitiveDependencies0,
          ChatControllerProvider.$allTransitiveDependencies1,
          ChatControllerProvider.$allTransitiveDependencies2,
          ChatControllerProvider.$allTransitiveDependencies3,
          ChatControllerProvider.$allTransitiveDependencies4,
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

String _$chatControllerHash() => r'59040cf56efa4224b8fca62667ae28fbe7de0b2d';

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
