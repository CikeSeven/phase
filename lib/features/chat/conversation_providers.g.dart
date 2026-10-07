// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'conversation_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
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

@ProviderFor(standaloneConversations)
final standaloneConversationsProvider = StandaloneConversationsProvider._();

final class StandaloneConversationsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Conversation>>,
          List<Conversation>,
          Stream<List<Conversation>>
        >
    with
        $FutureModifier<List<Conversation>>,
        $StreamProvider<List<Conversation>> {
  StandaloneConversationsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'standaloneConversationsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$standaloneConversationsHash();

  @$internal
  @override
  $StreamProviderElement<List<Conversation>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Conversation>> create(Ref ref) {
    return standaloneConversations(ref);
  }
}

String _$standaloneConversationsHash() =>
    r'5db89aeadb63d1157a73ee488a64412f3a9626c2';

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
