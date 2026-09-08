// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ChatController)
final chatControllerProvider = ChatControllerProvider._();

final class ChatControllerProvider
    extends $NotifierProvider<ChatController, ChatState> {
  ChatControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'chatControllerProvider',
        isAutoDispose: true,
        dependencies: <ProviderOrFamily>[modelSelectionProvider],
        $allTransitiveDependencies: <ProviderOrFamily>[
          ChatControllerProvider.$allTransitiveDependencies0,
          ChatControllerProvider.$allTransitiveDependencies1,
          ChatControllerProvider.$allTransitiveDependencies2,
        ],
      );

  static final $allTransitiveDependencies0 = modelSelectionProvider;
  static final $allTransitiveDependencies1 =
      ModelSelectionProvider.$allTransitiveDependencies0;
  static final $allTransitiveDependencies2 =
      ModelSelectionProvider.$allTransitiveDependencies1;

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

String _$chatControllerHash() => r'417bde592696fe2af9b5805c267847ac32a1ebb6';

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

String _$conversationsHash() => r'95b0a110c705b6c6c85e78e5d7914b280b7dd821';

/// 某会话的消息流。

@ProviderFor(chatMessages)
final chatMessagesProvider = ChatMessagesFamily._();

/// 某会话的消息流。

final class ChatMessagesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ChatMessage>>,
          List<ChatMessage>,
          Stream<List<ChatMessage>>
        >
    with
        $FutureModifier<List<ChatMessage>>,
        $StreamProvider<List<ChatMessage>> {
  /// 某会话的消息流。
  ChatMessagesProvider._({
    required ChatMessagesFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'chatMessagesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$chatMessagesHash();

  @override
  String toString() {
    return r'chatMessagesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<ChatMessage>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<ChatMessage>> create(Ref ref) {
    final argument = this.argument as String;
    return chatMessages(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ChatMessagesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$chatMessagesHash() => r'5148edb42d127c56359e5d0f165df93f9e19944d';

/// 某会话的消息流。

final class ChatMessagesFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<ChatMessage>>, String> {
  ChatMessagesFamily._()
    : super(
        retry: null,
        name: r'chatMessagesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 某会话的消息流。

  ChatMessagesProvider call(String conversationId) =>
      ChatMessagesProvider._(argument: conversationId, from: this);

  @override
  String toString() => r'chatMessagesProvider';
}
