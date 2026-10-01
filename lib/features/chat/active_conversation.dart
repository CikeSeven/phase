import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/error/failure.dart';
import '../../data/models/model_selection.dart' as model;
import '../../data/models/permission_mode.dart';
import 'conversation_providers.dart';
part 'active_conversation.g.dart';

/// 当前会话状态：会话 id 与新会话的助手、显式模型选择。
///
/// 单独成状态：会话选择既影响聊天控制器，也影响助手/模型解析，
/// 由它避免「选择依赖会话、会话依赖选择」的循环。
class ActiveConversationState {
  const ActiveConversationState({
    this.conversationId,
    this.draftAssistantId,
    this.draftModelSelection,
    this.draftPermissions = const PermissionSelection(),
  });

  /// 当前打开的会话；null 表示新会话（尚未落库）。
  final String? conversationId;

  /// 本次会话显式选定的助手，切到其他会话时清空。
  final String? draftAssistantId;

  /// 新会话确认的模型选择；建会话时保存到 modelSelectionOverride。
  final model.ModelSelection? draftModelSelection;
  final PermissionSelection draftPermissions;
}

@Riverpod(keepAlive: true)
class ActiveConversation extends _$ActiveConversation {
  @override
  ActiveConversationState build() => const ActiveConversationState();

  /// 打开某个已有会话；草稿助手不再需要。
  void open(String conversationId) {
    state = ActiveConversationState(conversationId: conversationId);
  }

  /// 回到新会话状态（或开始新的会话）。
  void clear() => state = const ActiveConversationState();

  /// 发送后新会话已有 id：记录它，并保留本次会话选定的助手。
  void adopt(String conversationId) {
    state = ActiveConversationState(
      conversationId: conversationId,
      draftAssistantId: state.draftAssistantId,
    );
  }

  /// 本次会话选定的助手（新会话尚未落库、或刚切换时）。
  void draftAssistant(String assistantId) {
    state = ActiveConversationState(
      conversationId: state.conversationId,
      draftAssistantId: assistantId,
      draftModelSelection: state.draftModelSelection,
      draftPermissions: state.draftPermissions,
    );
  }

  void draftPermissionMode(PermissionMode mode) {
    if (state.conversationId != null) {
      throw StateError('Not a draft conversation');
    }
    state = ActiveConversationState(
      draftAssistantId: state.draftAssistantId,
      draftModelSelection: state.draftModelSelection,
      draftPermissions: state.draftPermissions.select(mode),
    );
  }

  void draftModel(model.ModelSelection selection) {
    state = ActiveConversationState(
      conversationId: state.conversationId,
      draftAssistantId: state.draftAssistantId,
      draftModelSelection: selection,
      draftPermissions: state.draftPermissions,
    );
  }
}

/// UI 的单一模式来源；已有会话加载失败时不能伪装为基础档。
@Riverpod(dependencies: [ActiveConversation, conversationThread])
AsyncValue<PermissionSelection> conversationPermissions(Ref ref) {
  final active = ref.watch(activeConversationProvider);
  final id = active.conversationId;
  if (id == null) return AsyncData(active.draftPermissions);
  return ref.watch(conversationThreadProvider(id)).whenData((thread) {
    if (thread == null) throw const OperationFailure('会话已不存在');
    return thread.conversation.permissions;
  });
}
