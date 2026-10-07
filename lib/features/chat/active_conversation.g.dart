// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'active_conversation.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

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
    r'9142b8021293a98e741e2cb45741608f500435f6';

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

/// UI 的单一模式来源；已有会话加载失败时不能伪装为基础档。

@ProviderFor(conversationPermissions)
final conversationPermissionsProvider = ConversationPermissionsProvider._();

/// UI 的单一模式来源；已有会话加载失败时不能伪装为基础档。

final class ConversationPermissionsProvider
    extends
        $FunctionalProvider<
          AsyncValue<PermissionSelection>,
          AsyncValue<PermissionSelection>,
          AsyncValue<PermissionSelection>
        >
    with $Provider<AsyncValue<PermissionSelection>> {
  /// UI 的单一模式来源；已有会话加载失败时不能伪装为基础档。
  ConversationPermissionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'conversationPermissionsProvider',
        isAutoDispose: true,
        dependencies: <ProviderOrFamily>[
          activeConversationProvider,
          conversationThreadProvider,
        ],
        $allTransitiveDependencies: <ProviderOrFamily>[
          ConversationPermissionsProvider.$allTransitiveDependencies0,
          ConversationPermissionsProvider.$allTransitiveDependencies1,
        ],
      );

  static final $allTransitiveDependencies0 = activeConversationProvider;
  static final $allTransitiveDependencies1 = conversationThreadProvider;

  @override
  String debugGetCreateSourceHash() => _$conversationPermissionsHash();

  @$internal
  @override
  $ProviderElement<AsyncValue<PermissionSelection>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AsyncValue<PermissionSelection> create(Ref ref) {
    return conversationPermissions(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<PermissionSelection> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<PermissionSelection>>(
        value,
      ),
    );
  }
}

String _$conversationPermissionsHash() =>
    r'f79ee9206cd83542dee2de186105e178b3cfb169';
