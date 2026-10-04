import 'dart:async';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/error/failure.dart';
import '../../core/utils/id.dart';
import '../../core/utils/logger.dart';
import '../../data/datasources/local/model_catalog_cache.dart';
import '../../data/datasources/local/settings_storage.dart';
import '../../data/models/agent_plan.dart';
import '../../data/models/agent_run.dart';
import '../../data/models/assistant.dart';
import '../../data/models/attachment.dart';
import '../../data/models/chat_message.dart';
import '../../data/models/memory_entry.dart';
import '../../data/models/message_part.dart';
import '../../data/models/model_selection.dart' as model;
import '../../data/models/permission_mode.dart';
import '../../data/repositories/agent_run_repository.dart';
import '../../data/repositories/assistant_repository.dart';
import '../../data/repositories/conversation_repository.dart';
import '../../data/repositories/model_request_repository.dart';
import '../execution/execution_controller.dart';
import '../tools/run_recovery_controller.dart';
import '../tools/tool.dart';
import 'active_conversation.dart';
import 'chat_operation.dart';
import 'chat_providers.dart';
import 'chat_state.dart';
import 'context/context_configuration.dart';
import 'conversation_providers.dart';
import 'model_selection.dart';
import 'runtime/chat_run_driver.dart';
import 'runtime/chat_run_factory.dart';
import 'runtime/chat_run_update.dart';

export 'active_conversation.dart';
export 'chat_state.dart';
export 'chat_projection.dart';
export 'chat_providers.dart';
export 'conversation_providers.dart';

part 'chat_controller.g.dart';

/// 页面操作入口和展示投影；循环、流缓冲及资源生命周期由本次驱动持有。
@Riverpod(
  keepAlive: true,
  dependencies: [
    ModelSelection,
    currentAssistant,
    ActiveConversation,
    settingsStorage,
    modelCatalog,
    chatRunFactory,
    chatToolRuntimeFactory,
  ],
)
class ChatController extends _$ChatController {
  final Set<ChatOperation> _operations = {};
  final Map<String, ChatOperation> _conversationOperations = {};
  final Map<ChatOperation, ChatRunDriver> _drivers = {};
  int _viewRevision = 0;
  bool _busyFor(String? conversationId) =>
      conversationId != null &&
      _conversationOperations.containsKey(conversationId);

  @override
  ChatState build() {
    ref.onDispose(() {
      for (final operation in _operations) {
        operation.cancel();
      }
      for (final driver in _drivers.values) {
        driver.stop();
      }
    });
    return const ChatState();
  }

  Future<void> setPermissionMode(PermissionMode mode) async {
    final active = ref.read(activeConversationProvider);
    if (_busyFor(active.conversationId) ||
        state.isGenerating ||
        state.savingPermissionMode) {
      throw const OperationFailure('请先结束当前操作再切换权限模式');
    }
    if (active.conversationId == null) {
      ref.read(activeConversationProvider.notifier).draftPermissionMode(mode);
      return;
    }
    state = state.updateConversation(
      active.conversationId!,
      (session) => session.copyWith(savingPermissionMode: true),
    );
    try {
      final repository = await ref.read(conversationRepositoryProvider.future);
      await repository.setPermissionMode(active.conversationId!, mode);
      // 只刷新被写入的会话；迟到完成不能回写另一个页面的草稿。
      if (ref.mounted) {
        ref.invalidate(conversationThreadProvider(active.conversationId!));
      }
    } finally {
      if (ref.mounted) {
        state = state.updateConversation(
          active.conversationId!,
          (session) => session.copyWith(savingPermissionMode: false),
        );
      }
    }
  }

  void _checkPermissionSave() {
    if (state.savingPermissionMode) {
      throw const OperationFailure('会话设置正在保存，请稍后重试');
    }
  }

  void startNewConversation() {
    _viewRevision++;
    ref.read(activeConversationProvider.notifier).clear();
    state = state.selectConversation(null);
  }

  /// 切换到某个会话；消息由界面订阅仓储，附件索引进入时读取。
  Future<void> openConversation(String conversationId) async {
    final revision = ++_viewRevision;
    final repository = await ref.read(conversationRepositoryProvider.future);
    final thread = await repository.getThread(conversationId);
    if (thread == null || !ref.mounted || revision != _viewRevision) return;
    final attachments = await _attachmentIndex(conversationId, const []);
    if (!ref.mounted || revision != _viewRevision) return;
    ref.read(activeConversationProvider.notifier).open(conversationId);
    state = state
        .selectConversation(conversationId)
        .copyWith(attachments: attachments);
    // 会话绑定的助手可能不同：刷新派生选择。
    ref.invalidate(modelSelectionProvider);
  }

  /// 为当前会话切换助手；还没有会话时记为草稿，建会话时使用该助手。
  ///
  /// 草稿同时用于「会话内刚切换、尚未落库」的瞬间，保证下一次发送立即生效。
  Future<void> selectAssistant(String assistantId) async {
    final active = ref.read(activeConversationProvider);
    ref.read(activeConversationProvider.notifier).draftAssistant(assistantId);
    final conversationId = active.conversationId;
    if (conversationId == null) {
      ref.invalidate(modelSelectionProvider);
      return;
    }
    final repository = await ref.read(conversationRepositoryProvider.future);
    await repository.setAssistant(conversationId, assistantId);
    ref.invalidate(modelSelectionProvider);
  }

  /// 新建助手（名称必填，其余留空表示未设置）。
  Future<Assistant> createAssistant({
    required String name,
    String systemPrompt = '',
    model.ModelSelection? defaultModelSelection,
    Set<String> mcpServerIds = const {},
    Set<String> skillIds = const {},
    MemoryScope memoryScope = MemoryScope.disabled,
  }) {
    return _guardAssistant('创建助手失败', () async {
      final repository = await ref.read(assistantRepositoryProvider.future);
      final assistant = Assistant(
        id: generateId(),
        name: name.trim(),
        systemPrompt: systemPrompt.trim(),
        defaultModelSelection: defaultModelSelection,
        mcpServerIds: mcpServerIds,
        skillIds: skillIds,
        memoryScope: memoryScope,
        createdAt: DateTime.now(),
      );
      await repository.save(assistant);
      // 新建的助手按列表顺序可能成为当前助手：刷新派生选择。
      ref.invalidate(modelSelectionProvider);
      return assistant;
    });
  }

  /// 更新助手；未传的字段保持不变（含清空默认模型）。
  Future<Assistant> updateAssistant({
    required String id,
    required String name,
    required String systemPrompt,
    model.ModelSelection? defaultModelSelection,
    bool clearDefaultModel = false,
    Set<String>? mcpServerIds,
    Set<String>? skillIds,
    MemoryScope? memoryScope,
  }) {
    return _guardAssistant('保存助手失败', () async {
      final repository = await ref.read(assistantRepositoryProvider.future);
      final existing = await repository.getById(id);
      if (existing == null) {
        throw const UnknownFailure('助手已不存在');
      }
      final updated = Assistant(
        id: existing.id,
        name: name.trim(),
        systemPrompt: systemPrompt.trim(),
        defaultModelSelection: clearDefaultModel
            ? null
            : (defaultModelSelection ?? existing.defaultModelSelection),
        mcpServerIds: mcpServerIds ?? existing.mcpServerIds,
        skillIds: skillIds ?? existing.skillIds,
        memoryScope: memoryScope ?? existing.memoryScope,
        createdAt: existing.createdAt,
      );
      await repository.save(updated);
      ref.invalidate(modelSelectionProvider);
      return updated;
    });
  }

  /// 删除助手；已有会话保留，仅解除与助手的绑定。
  Future<void> deleteAssistant(String id) {
    return _guardAssistant('删除助手失败', () async {
      final repository = await ref.read(assistantRepositoryProvider.future);
      await repository.delete(id);
      ref.invalidate(modelSelectionProvider);
    });
  }

  /// 助手写操作的统一错误收口。
  Future<T> _guardAssistant<T>(
    String message,
    Future<T> Function() action,
  ) async {
    try {
      return await action();
    } on Failure {
      rethrow;
    } on Exception catch (e, st) {
      AppLogger.error(message, e, st);
      throw UnknownFailure(message, cause: e);
    }
  }

  /// 发送一条消息并流式接收回复。
  ///
  /// 前置失败（未选择模型、落库失败）抛出 [Failure] 由 UI 提示；
  /// 流式期间的错误写入助手消息（failed 状态）并保留已收内容。
  Future<void> send(
    String text, {
    List<Attachment> attachments = const [],
  }) async {
    _checkPermissionSave();
    final activeId = ref.read(activeConversationProvider).conversationId;
    if (_busyFor(activeId) || (activeId == null && state.isGenerating)) return;
    final operation = _beginOperation(activeId);
    try {
      await ref.read(runRecoveryControllerProvider.notifier).initialize();
      await _send(text, operation: operation, attachments: attachments);
    } finally {
      _releaseOperation(operation);
    }
  }

  ChatOperation _beginOperation(String? conversationId) {
    if (_busyFor(conversationId)) {
      throw const OperationFailure('此会话已有任务正在运行');
    }
    final operation = ChatOperation();
    _operations.add(operation);
    if (conversationId != null) _reserveOperation(operation, conversationId);
    return operation;
  }

  void _reserveOperation(ChatOperation operation, String conversationId) {
    final current = _conversationOperations[conversationId];
    if (current != null && !identical(current, operation)) {
      throw const OperationFailure('此会话已有任务正在运行');
    }
    operation.bindConversation(conversationId);
    _conversationOperations[conversationId] = operation;
  }

  void _claimOperation(ChatOperation operation, String conversationId) {
    _reserveOperation(operation, conversationId);
    state = state.updateConversation(
      conversationId,
      (session) => session.copyWith(
        isGenerating: true,
        runningConversationId: conversationId,
        clearStreaming: true,
        clearContext: true,
      ),
    );
  }

  void _releaseOperation(ChatOperation operation) {
    try {
      _operations.remove(operation);
      _drivers.remove(operation);
      final conversationId = operation.conversationId;
      if (conversationId != null &&
          identical(_conversationOperations[conversationId], operation)) {
        _conversationOperations.remove(conversationId);
        if (ref.mounted) {
          state = state.updateConversation(
            conversationId,
            (session) => session.copyWith(
              isGenerating: false,
              clearStreaming: true,
              clearRun: true,
            ),
          );
          if (ref.read(activeConversationProvider).conversationId !=
              conversationId) {
            state = state.removeConversation(conversationId);
          }
        }
      }
    } finally {
      operation.settle();
    }
  }

  void _checkPanelCancellation(RunCancellation? cancellation) {
    if (!ref.mounted || cancellation?.isCancelled == true) {
      throw const CancelledFailure('悬浮面板发送已取消');
    }
  }

  /// 面板消息绑定来源会话；旧运行完全收尾后才创建新的独立运行。
  Future<void> _sendFromPanel(
    String sourceRunId,
    String conversationId,
    String text,
    RunCancellation cancellation,
  ) async {
    _checkPanelCancellation(cancellation);
    final sourceOperation = _operations
        .where((operation) => operation.runId == sourceRunId)
        .firstOrNull;
    if (sourceOperation != null) {
      ref.read(executionControllerProvider.notifier).stopRun(sourceRunId);
      _drivers[sourceOperation]?.stop();
      sourceOperation.cancel();
      await Future.any([
        sourceOperation.whenSettled,
        cancellation.whenCancelled,
      ]);
    }
    _checkPanelCancellation(cancellation);
    if (_busyFor(conversationId) || state.savingPermissionMode) {
      throw const OperationFailure('当前操作尚未结束，请稍后重试');
    }
    final operation = _beginOperation(conversationId);
    final accepted = Completer<void>();
    unawaited(
      _sendPanelMessage(
        operation,
        conversationId,
        text,
        cancellation,
        accepted,
      ),
    );
    await accepted.future;
  }

  Future<void> _sendPanelMessage(
    ChatOperation operation,
    String conversationId,
    String text,
    RunCancellation cancellation,
    Completer<void> accepted,
  ) async {
    try {
      await ref.read(runRecoveryControllerProvider.notifier).initialize();
      _checkPanelCancellation(cancellation);
      await openConversation(conversationId);
      _checkPanelCancellation(cancellation);
      if (ref.read(activeConversationProvider).conversationId !=
          conversationId) {
        throw const OperationFailure('原会话已不可用，请返回相月处理');
      }
      await _send(
        text,
        operation: operation,
        panelCancellation: cancellation,
        onPanelAccepted: () {
          if (!accepted.isCompleted) accepted.complete();
        },
      );
      if (!accepted.isCompleted) {
        throw const OperationFailure('消息未发送，请稍后重试');
      }
    } catch (error, stackTrace) {
      final failure = error is Failure
          ? error
          : const OperationFailure('发送失败，请稍后重试');
      if (!accepted.isCompleted) {
        accepted.completeError(failure, stackTrace);
      } else if (ref.mounted) {
        ref
            .read(executionControllerProvider.notifier)
            .reportPanelFailure(failure);
      }
      if (error is! Failure) AppLogger.warning('悬浮面板运行异常');
    } finally {
      _releaseOperation(operation);
    }
  }

  Future<void> _send(
    String text, {
    required ChatOperation operation,
    List<Attachment> attachments = const [],
    RunCancellation? panelCancellation,
    void Function()? onPanelAccepted,
  }) async {
    final trimmed = text.trim();
    final activeId = ref.read(activeConversationProvider).conversationId;
    final owner = activeId == null ? null : _conversationOperations[activeId];
    if ((trimmed.isEmpty && attachments.isEmpty) ||
        (owner != null && !identical(owner, operation))) {
      return;
    }

    // 强刷：刚切换的助手/会话要立刻作用到本次请求，不依赖竞态的重建时机。
    final revision = _viewRevision;
    final selection = await ref.refresh(modelSelectionProvider.future);
    if (selection == null) {
      throw const UnknownFailure('尚未选择服务商与模型');
    }

    final repository = await ref.read(conversationRepositoryProvider.future);

    // 助手列表可能还在首次加载：先把列表与会话线程等就绪，
    // 否则本次请求会丢掉系统提示词与助手默认模型。
    final assistant = await awaitAssistantContext(ref);
    if (revision != _viewRevision) throw const OperationFailure('会话已切换，请重新发送');
    final active = ref.read(activeConversationProvider);
    var conversationId = active.conversationId;
    _checkRecoveredConversation(conversationId);
    final existing = conversationId == null
        ? null
        : await repository.getThread(conversationId);
    if (conversationId != null && existing == null) {
      throw const OperationFailure('会话已不存在');
    }
    final permissions =
        existing?.conversation.permissions ?? active.draftPermissions;
    if (revision != _viewRevision) throw const OperationFailure('会话已切换，请重新发送');
    if (permissions.mode == PermissionMode.plan && !selection.supportsTools) {
      throw const OperationFailure('计划模式需要支持工具调用的模型');
    }
    if (conversationId == null) {
      final conversation = await repository.createConversation(
        permissions: permissions,
        assistantId: assistant?.id,
        modelSelectionOverride: ref
            .read(activeConversationProvider)
            .draftModelSelection,
      );
      conversationId = conversation.id;
      if (revision == _viewRevision) {
        ref.read(activeConversationProvider.notifier).adopt(conversationId);
        state = state.selectConversation(conversationId);
      }
    }
    final thread = await repository.getThread(conversationId);
    if (thread == null) {
      throw const UnknownFailure('会话不存在或已删除');
    }
    final claimed = [
      for (final attachment in attachments)
        attachment.withConversation(conversationId),
    ];
    for (final attachment in claimed) {
      await repository.saveAttachment(attachment);
      // 文档抽取在选择时已完成：结果（文本路径或失败原因）随附件落库。
      if (attachment.isDocument) {
        await repository.updateAttachmentExtraction(
          attachment.id,
          extractedTextPath: attachment.extractedTextPath,
          error: attachment.extractionError,
        );
      }
    }
    // 附件索引带上刚落库的这批，发送后即可在气泡里看到缩略图，
    // 同时用于把历史消息里的附件引用解析成请求内容。
    final attachmentIndex = await _attachmentIndex(conversationId, claimed);
    state = state.updateConversation(
      conversationId,
      (session) => session.copyWith(attachments: attachmentIndex),
    );

    final parentId = thread.currentMessageId;
    if (panelCancellation != null) _checkPanelCancellation(panelCancellation);
    final userMessage = ChatMessage(
      id: generateId(),
      conversationId: conversationId,
      parentId: parentId,
      role: ChatRole.user,
      status: MessageStatus.completed,
      parts: [
        for (final attachment in claimed)
          if (attachment.isImage)
            ImagePart(attachmentId: attachment.id)
          else
            DocumentPart(attachmentId: attachment.id),
        if (trimmed.isNotEmpty) TextPart(text: trimmed),
      ],
      createdAt: DateTime.now(),
    );
    await repository.appendMessage(userMessage, updateTitle: parentId == null);

    _claimOperation(operation, conversationId);
    await _startRun(
      operation: operation,
      repository: repository,
      conversationId: conversationId,
      inputMessageId: userMessage.id,
      selection: selection,
      assistant: assistant,
      mode: permissions.mode,
      planExecutionMode: permissions.lastExecutionMode,
      panelCancellation: panelCancellation,
      onPanelAccepted: onPanelAccepted,
    );
  }

  /// 从最近一条用户消息重新生成整轮回答。
  ///
  /// 原运行的所有回答、思考、调用与结果退出当前分支，保留在历史消息树；
  /// 新运行不继承这些内容，也不重放旧调用，工具仍由模型重新提出并授权。
  Future<void> regenerate() async {
    _checkPermissionSave();
    final conversationId = ref.read(activeConversationProvider).conversationId;
    if (conversationId == null || _busyFor(conversationId)) return;
    final operation = _beginOperation(conversationId);
    try {
      await ref.read(runRecoveryControllerProvider.notifier).initialize();
      await _regenerate(operation);
    } finally {
      _releaseOperation(operation);
    }
  }

  Future<void> _regenerate(ChatOperation operation) async {
    final revision = _viewRevision;
    final conversationId = operation.conversationId;
    if (conversationId == null) return;
    _checkRecoveredConversation(conversationId);

    final repository = await ref.read(conversationRepositoryProvider.future);
    final thread = await repository.getThread(conversationId);
    if (thread == null || thread.branch.isEmpty) return;
    final permissions = thread.conversation.permissions;

    // 找到最近一条用户消息：它就是本轮要重新回答的输入。
    final index = thread.branch.lastIndexWhere(
      (message) => message.role == ChatRole.user,
    );
    if (index < 0) return;
    final userMessage = thread.branch[index];

    final selection = await ref.refresh(modelSelectionProvider.future);
    if (selection == null) {
      throw const UnknownFailure('尚未选择服务商与模型');
    }
    final assistant = await awaitAssistantContext(ref);

    if (revision != _viewRevision) throw const OperationFailure('会话已切换，请重新生成');

    // 回到整轮的原始输入，不把其中任一工具轮留在新运行上下文中。
    _claimOperation(operation, conversationId);
    await repository.setCurrentMessage(conversationId, userMessage.id);

    await _startRun(
      operation: operation,
      repository: repository,
      conversationId: conversationId,
      inputMessageId: userMessage.id,
      selection: selection,
      assistant: assistant,
      mode: permissions.mode,
      planExecutionMode: permissions.lastExecutionMode,
    );
  }

  /// 复制指定会话：副本带同样的助手、模型覆盖与全部消息/分支结构，
  /// 并切换到副本；原会话不受影响。
  Future<String> duplicateFrom(String conversationId) async {
    final repository = await ref.read(conversationRepositoryProvider.future);
    final copy = await repository.duplicateConversation(conversationId);
    await openConversation(copy.id);
    return copy.id;
  }

  Future<void> approvePlan(AgentPlan plan) async {
    _checkPermissionSave();
    if (_busyFor(plan.conversationId)) {
      throw const OperationFailure('此会话已有任务正在运行');
    }
    final operation = _beginOperation(plan.conversationId);
    try {
      await ref.read(runRecoveryControllerProvider.notifier).initialize();
      _checkRecoveredConversation(plan.conversationId);
      if (ref.read(activeConversationProvider).conversationId !=
          plan.conversationId) {
        throw const OperationFailure('请返回计划所属会话后批准');
      }
      final revision = _viewRevision;
      final selection = await ref.refresh(modelSelectionProvider.future);
      final assistant = await awaitAssistantContext(ref);
      if (selection == null) throw const OperationFailure('尚未选择模型');
      if (revision != _viewRevision) throw const OperationFailure('会话已切换');
      final source = await (await ref.read(agentRunRepositoryProvider.future))
          .getById(plan.sourceRunId);
      if (source == null ||
          source.configuration.mode != PermissionMode.plan ||
          source.configuration.planExecutionMode == PermissionMode.plan) {
        throw const OperationFailure('计划来源执行档位无效，请重新规划');
      }
      if (revision != _viewRevision) throw const OperationFailure('会话已切换');
      final plannedThread = await (await ref.read(
        conversationRepositoryProvider.future,
      )).getThread(plan.conversationId);
      if (plannedThread == null ||
          plannedThread.conversation.workspaceId !=
              source.configuration.workspace?.id) {
        throw const OperationFailure('会话工作区与计划记录不一致，请重新规划');
      }
      _claimOperation(operation, plan.conversationId);
      await _startRun(
        operation: operation,
        repository: await ref.read(conversationRepositoryProvider.future),
        conversationId: plan.conversationId,
        inputMessageId: generateId(),
        selection: selection,
        assistant: assistant,
        approvedPlan: plan,
        mode: source.configuration.planExecutionMode,
        planExecutionMode: source.configuration.planExecutionMode,
      );
    } finally {
      _releaseOperation(operation);
    }
  }

  /// 空闲规划只读取目录与历史，不创建会话或运行。
  Future<PreparedContext?> prepareContext(String conversationId) async {
    if (ref.read(activeConversationProvider).conversationId != conversationId) {
      return null;
    }
    final repository = await ref.read(conversationRepositoryProvider.future);
    final thread = await repository.getThread(conversationId);
    final selection = await ref.read(modelSelectionProvider.future);
    if (thread?.currentMessageId == null || selection == null) return null;
    final assistant = await awaitAssistantContext(ref);
    final factory = await ref.read(chatRunFactoryProvider.future);
    final preview = await factory.preview(
      thread: thread!,
      selection: selection,
      assistant: assistant,
    );
    if (!ref.mounted ||
        ref.read(activeConversationProvider).conversationId != conversationId) {
      return null;
    }
    final contexts = await ref.read(chatContextCoordinatorProvider.future);
    return contexts.prepare(
      thread: thread,
      selection: selection,
      assistantId: assistant?.id,
      preview: preview,
    );
  }

  Future<String> compactContext(String conversationId) async {
    _checkPermissionSave();
    if (_busyFor(conversationId)) {
      throw const OperationFailure('此会话已有任务正在运行');
    }
    final operation = _beginOperation(conversationId);
    final cancellation = operation.beginCancellation();
    final revision = _viewRevision;
    _claimOperation(operation, conversationId);
    state = state.updateConversation(
      conversationId,
      (session) => session.copyWith(summarizing: true, clearContext: true),
    );
    try {
      await ref.read(runRecoveryControllerProvider.notifier).initialize();
      _checkRecoveredConversation(conversationId);
      final prepared = await prepareContext(conversationId);
      if (prepared == null) throw const OperationFailure('请选择模型并打开已有会话');
      if (cancellation.isCancelled) return '已停止整理';
      if (revision != _viewRevision) {
        throw const OperationFailure('会话已切换，请重新整理');
      }
      final result = await (await ref.read(
        chatContextCoordinatorProvider.future,
      )).compact(prepared, cancellation);
      if (ref.mounted && revision == _viewRevision) {
        state = state.updateConversation(
          conversationId,
          (session) => session.copyWith(
            contextBuild: result,
            contextConversationId: conversationId,
          ),
        );
      }
      return cancellation.isCancelled
          ? '已停止整理'
          : result.compactionNotice ?? '上下文整理完成';
    } finally {
      cancellation.cancel();
      _releaseOperation(operation);
    }
  }

  /// 配置固定后创建一次独立驱动；租约释放完成后才解除操作互斥。
  Future<void> _startRun({
    required ChatOperation operation,
    required ConversationRepository repository,
    required String conversationId,
    required String inputMessageId,
    required ChatModelSelection selection,
    required Assistant? assistant,
    required PermissionMode mode,
    required PermissionMode planExecutionMode,
    AgentPlan? approvedPlan,
    RunCancellation? panelCancellation,
    void Function()? onPanelAccepted,
  }) async {
    final runs = await ref.read(agentRunRepositoryProvider.future);
    final factory = await ref.read(chatRunFactoryProvider.future);
    final prepared = await factory.create(
      conversationId: conversationId,
      inputMessageId: inputMessageId,
      selection: selection,
      assistant: assistant,
      mode: mode,
      planExecutionMode: planExecutionMode,
      approvedPlan: approvedPlan,
      operation: operation,
      checkCurrent: () {
        if (!ref.mounted) throw const CancelledFailure('创建运行前已退出');
        if (panelCancellation != null) {
          _checkPanelCancellation(panelCancellation);
        }
      },
    );
    final run = prepared.run;
    try {
      try {
        await _driveRun(
          operation: operation,
          run: run,
          repository: repository,
          selection: selection,
          panelCancellation: panelCancellation,
          onPanelAccepted: onPanelAccepted,
        );
      } catch (error, stackTrace) {
        // 驱动装配失败也提交终态；清理不能覆盖原始异常。
        await operation.cleanup(() async {
          final stored = await runs.getById(run.id);
          if (stored?.status == RunStatus.running && stored?.turnCount == 0) {
            final cancelled =
                error is CancelledFailure ||
                panelCancellation?.isCancelled == true;
            await runs.finish(
              run.id,
              status: cancelled ? RunStatus.stopped : RunStatus.failed,
              finishReason: cancelled
                  ? RunFinishReason.cancelled
                  : error is StorageFailure
                  ? RunFinishReason.storageError
                  : RunFinishReason.executionError,
            );
          }
        }, failureMessage: '运行初始化终态未能保存，启动时需核对');
        if (error is Failure) rethrow;
        AppLogger.error('运行初始化异常：${error.runtimeType}', null, stackTrace);
        throw UnknownFailure('运行初始化失败', cause: error);
      }
    } finally {
      await prepared.close(operation);
    }
    operation.throwIfCleanupFailed();
  }

  Future<void> _driveRun({
    required ChatOperation operation,
    required AgentRun run,
    required ConversationRepository repository,
    required ChatModelSelection selection,
    bool resuming = false,
    RunCancellation? panelCancellation,
    void Function()? onPanelAccepted,
  }) async {
    final runs = await ref.read(agentRunRepositoryProvider.future);
    final requests = await ref.read(modelRequestRepositoryProvider.future);
    final storage = await ref.read(artifactStorageProvider.future);
    final tools = await ref.read(chatToolRuntimeFactoryProvider.future);
    final models = await ref.read(modelTurnRunnerFactoryProvider.future);
    final contexts = await ref.read(chatContextCoordinatorProvider.future);
    final execution = ref.read(executionControllerProvider.notifier);
    final recovery = ref.read(runRecoveryControllerProvider.notifier);
    if (!ref.mounted) throw const CancelledFailure('启动运行前已退出');
    final driver = ChatRunDriver(
      run: run,
      selection: selection,
      operation: operation,
      conversations: repository,
      runs: runs,
      requests: requests,
      storage: storage,
      tools: tools,
      models: models,
      contexts: contexts,
      execution: execution,
      observe: (update) => _onRunUpdate(operation, update),
      runStarted: recovery.runStarted,
      refreshRecovery: () async {
        if (ref.mounted) await recovery.runFinished(run.id);
      },
      sendFromPanel: _sendFromPanel,
      darkTheme: switch (ref.read(settingsStorageProvider).readThemeMode()) {
        ThemeMode.light => false,
        ThemeMode.dark => true,
        ThemeMode.system => null,
      },
    );
    _drivers[operation] = driver;
    try {
      await driver.run(
        resuming: resuming,
        panelCancellation: panelCancellation,
        onPanelAccepted: onPanelAccepted,
      );
    } finally {
      if (identical(_drivers[operation], driver)) _drivers.remove(operation);
    }
  }

  /// 展示更新不提交业务数据；旧驱动与其他会话不能回写当前页面附件。
  void _onRunUpdate(ChatOperation operation, ChatRunUpdate update) {
    if (!ref.mounted ||
        !_operations.contains(operation) ||
        operation.runId != update.runId) {
      return;
    }
    state = state.updateConversation(update.conversationId, (session) {
      return switch (update) {
        ChatRunStarted(:final attachments) => session.copyWith(
          isGenerating: true,
          runningConversationId: update.conversationId,
          clearContext: true,
          clearStreaming: true,
          attachments: attachments,
        ),
        ChatStreamingStarted(:final messageId) => session.copyWith(
          streamingParts: const [],
          streamingMessageId: messageId,
        ),
        ChatStreamingChanged(:final parts) => session.copyWith(
          streamingParts: parts,
        ),
        ChatStreamingFinished() => session.copyWith(clearStreaming: true),
        ChatRetryChanged(:final retry) => session.copyWith(
          retry: retry,
          clearRetry: retry == null,
        ),
        ChatContextMeasured(:final context) => session.copyWith(
          contextBuild: context,
          contextConversationId: update.conversationId,
        ),
        ChatSummarizingChanged(:final value) => session.copyWith(
          summarizing: value,
        ),
        ChatAttachmentsChanged(:final attachments) => session.copyWith(
          attachments: attachments,
        ),
      };
    });
  }

  /// 用户继续已保存的位置；连接、能力与工具范围来自原运行快照。
  Future<void> resumeRun(String runId) async {
    if (_operations.any((operation) => operation.runId == runId)) return;
    ChatOperation? operation;
    try {
      final recovery = ref.read(runRecoveryControllerProvider.notifier);
      await recovery.refresh();
      final entry = (ref.read(runRecoveryControllerProvider).value ?? [])
          .where((entry) => entry.run.id == runId)
          .firstOrNull;
      if (entry == null) throw const OperationFailure('此任务已结束');
      final run = entry.run;
      if (_busyFor(run.conversationId)) {
        throw const OperationFailure('此会话已有任务正在运行');
      }
      operation = _beginOperation(run.conversationId);
      final selection = selectionForRun(run);
      await openConversation(run.conversationId);
      _claimOperation(operation, run.conversationId);
      final repository = await ref.read(conversationRepositoryProvider.future);
      await _driveRun(
        operation: operation,
        run: run,
        repository: repository,
        selection: selection,
        resuming: true,
      );
      operation.throwIfCleanupFailed();
    } finally {
      if (operation != null) _releaseOperation(operation);
    }
  }

  void stop() {
    final conversationId = ref.read(activeConversationProvider).conversationId;
    if (conversationId != null) stopConversation(conversationId);
  }

  void stopConversation(String conversationId) {
    final operation = _conversationOperations[conversationId];
    if (operation == null) return;
    operation.cancel();
    _drivers[operation]?.stop();
    final runId = operation.runId;
    if (runId != null) {
      ref.read(executionControllerProvider.notifier).stopRun(runId);
    }
  }

  void _checkRecoveredConversation(String? id) {
    final recovery = ref.read(runRecoveryControllerProvider);
    if (recovery.hasError) throw const OperationFailure('请先重试读取中断任务');
    if (id != null &&
        (recovery.value ?? []).any((entry) => entry.run.conversationId == id)) {
      throw const OperationFailure('请先继续或停止此会话的中断任务');
    }
  }

  Future<Map<String, Attachment>> _attachmentIndex(
    String conversationId,
    List<Attachment> justAdded,
  ) async {
    final repository = await ref.read(conversationRepositoryProvider.future);
    final stored = await repository.attachmentsFor(conversationId);
    return {
      for (final attachment in stored) attachment.id: attachment,
      for (final attachment in justAdded) attachment.id: attachment,
    };
  }
}
