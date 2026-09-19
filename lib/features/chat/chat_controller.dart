import '../../../data/repositories/workspace_repository.dart';
import '../workspace/workspace_files.dart';
import '../workspace/shell_tool.dart';
import '../workspace/install_tool.dart';
import '../workspace/prepare_skill_tool.dart';
import '../workspace/process_driver.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/error/failure.dart';
import '../../../core/error/provider_error.dart';
import '../../../core/utils/id.dart';
import '../../../core/utils/logger.dart';
import '../../../data/datasources/local/artifact_storage.dart';
import '../../../data/datasources/local/attachment_storage.dart';
import '../../../data/datasources/local/secure_key_storage.dart';
import '../../../data/models/agent_run.dart';
import '../../../data/models/assistant.dart';
import '../../../data/models/attachment.dart';
import '../../../data/models/chat_chunk.dart';
import '../../../data/models/chat_message.dart';
import '../../../data/models/chat_request.dart';
import '../../../data/models/conversation.dart';
import '../../../data/models/message_part.dart';
import '../../../data/models/model_selection.dart' as model;
import '../../../data/models/reasoning_effort.dart';
import '../../../data/models/tool_call_record.dart';
import '../../../data/models/tool_policy.dart';
import '../../../data/models/tool_source.dart';
import '../../../data/repositories/mcp_server_repository.dart';
import '../mcp/mcp_connections.dart';
import '../mcp/mcp_runtime.dart';
import '../../../data/models/api_protocol.dart';
import '../../../data/models/profile_model.dart';
import '../../../data/models/provider_profile.dart';
import '../../../data/repositories/agent_run_repository.dart';
import '../../../data/repositories/assistant_repository.dart';
import '../../../data/repositories/conversation_repository.dart';
import '../../../data/repositories/tool_call_repository.dart';
import '../../../providers/ai_provider.dart';
import '../../../providers/dio_failure_mapper.dart';
import '../../../providers/provider_factory.dart';
import '../tools/agent_loop.dart';
import '../skills/read_skill_tool.dart';
import '../../../data/repositories/skill_repository.dart';
import '../tools/http_transport.dart';
import '../tools/run_recovery_controller.dart';
import '../tools/tool.dart';
import '../tools/tool_executor.dart';
import '../tools/tool_registry.dart';
import '../execution/execution_controller.dart';
import '../../../data/datasources/local/settings_storage.dart';
import '../execution/platform_tools.dart';
import '../execution/channel_driver.dart';
import 'model_selection.dart';
import 'model_retry.dart';

part 'chat_controller.g.dart';

/// 聊天页状态：当前会话、附件索引与流式中的内容块。
///
/// 持久化消息以 repository 的 watch 流为准；[streamingParts] 只服务
/// 流式期间尚未落库的最后一条回答。
class ChatState {
  const ChatState({
    this.streamingParts = const [],
    this.attachments = const {},
    this.isGenerating = false,
    this.runningConversationId,
    this.streamingMessageId,
    this.retry,
  });

  /// 正在生成的回答内容块（按 Part 顺序）。
  final List<MessagePart> streamingParts;

  /// 当前会话的附件索引，用于把 Part 里的附件引用还原成文件。
  final Map<String, Attachment> attachments;

  final bool isGenerating;
  final String? runningConversationId;
  final String? streamingMessageId;
  final ModelRetryState? retry;

  ChatState copyWith({
    List<MessagePart>? streamingParts,
    Map<String, Attachment>? attachments,
    bool? isGenerating,
    String? runningConversationId,
    String? streamingMessageId,
    bool clearStreaming = false,
    bool clearRun = false,
    ModelRetryState? retry,
    bool clearRetry = false,
  }) {
    return ChatState(
      retry: clearRetry || clearRun ? null : retry ?? this.retry,
      streamingParts: clearStreaming
          ? const []
          : streamingParts ?? this.streamingParts,
      attachments: attachments ?? this.attachments,
      isGenerating: isGenerating ?? this.isGenerating,
      runningConversationId: clearRun
          ? null
          : runningConversationId ?? this.runningConversationId,
      streamingMessageId: clearStreaming
          ? null
          : streamingMessageId ?? this.streamingMessageId,
    );
  }
}

/// 聊天状态在应用生命周期内保留：切到设置页再回来不应丢失当前会话与流式状态。
@Riverpod(
  keepAlive: true,
  dependencies: [
    ModelSelection,
    currentAssistant,
    ActiveConversation,
    settingsStorage,
  ],
)
class ChatController extends _$ChatController implements AgentLoopHost {
  /// 仅在环境就绪时注入的内置工具。
  static const _environmentTools = {'shell', 'install_packages'};

  /// 流式增量写库的节流间隔：SSE chunk 远密于屏幕刷新。
  static const _flushInterval = Duration(milliseconds: 100);

  /// 流式内容发布到界面的间隔：正文与思考都走这个节拍合批。
  ///
  /// 每个 chunk 都刷 UI，等于让整段内容按帧重排——实测每千字约 0.55ms/帧，
  /// 几万字的思考就是每帧几十毫秒。合批之后刷新频率与内容长度无关
  /// （kelivo 50ms、Operit 200ms 是同款做法）。
  static const _publishInterval = Duration(milliseconds: 50);

  /// 回填给模型的工具结果上限（字节）；超出时截断并附截断标记。
  static const _maxToolResultBytes = 8 * 1024;

  StreamSubscription<ChatChunk>? _subscription;
  Completer<void>? _doneCompleter;
  Timer? _flushTimer;
  Timer? _publishTimer;
  String? _streamingMessageId;

  ProviderError? _streamError;
  bool _acceptingChunks = false;

  /// 流式期间的块缓冲：partId → 已累积内容。
  final List<_LivePart> _liveParts = [];

  bool _stoppedManually = false;

  /// 当前运行：一次发送（或重新生成）对应一个 AgentRun，配置在开始时固定。
  AgentRun? _run;

  /// 运行内的模型选择快照：连接、能力与推理等级全程取它，不看中途改动。
  ChatModelSelection? _selection;
  ConversationRepository? _repository;
  AgentRunRepository? _runs;
  ArtifactStorage? _storage;
  ToolRegistry? _registry;
  ToolExecutor? _executor;
  RunCancellation? _cancellation;

  /// 本轮助手的最终内容块；工具引用在响应收口时与整轮记录一起保存。
  List<MessagePart> _turnParts = const [];
  TokenUsage? _turnUsage;

  /// 本轮思考耗时；恢复已知工具结果时沿用原消息的值。
  int? _turnThinkingDurationMs;

  /// 本轮分支末尾的消息：下一轮助手消息与运行位置都指向它。
  String? _turnTailId;

  /// 本轮以错误或空回复收场时，运行结束原因取它。
  RunFinishReason? _turnFailure;
  bool _runFinished = false;
  bool _busy = false;
  int _viewRevision = 0;
  bool _responseComplete = false;
  Map<String, Attachment> _runAttachments = const {};
  Future<void> _pendingFlush = Future.value();
  Failure? _flushFailure;

  @override
  ChatState build() {
    ref.onDispose(() {
      _flushTimer?.cancel();
      _publishTimer?.cancel();
      _cancellation?.cancel();
      _acceptingChunks = false;
      _completeRequest();
    });
    return const ChatState();
  }

  void startNewConversation() {
    _viewRevision++;
    ref.read(activeConversationProvider.notifier).clear();
    state = state.copyWith(attachments: const {});
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
    state = state.copyWith(attachments: attachments);
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
    final thread = await repository.getThread(conversationId);
    if (thread == null) return;
    await repository.updateConversation(
      thread.conversation.copyWith(assistantId: assistantId),
    );
    ref.invalidate(modelSelectionProvider);
  }

  /// 新建助手（名称必填，其余留空表示未设置）。
  Future<Assistant> createAssistant({
    required String name,
    String systemPrompt = '',
    model.ModelSelection? defaultModelSelection,
    ToolPolicyConfig toolPolicy = defaultToolPolicyConfig,
    Set<String> skillIds = const {},
  }) {
    return _guardAssistant('创建助手失败', () async {
      final repository = await ref.read(assistantRepositoryProvider.future);
      final assistant = Assistant(
        id: generateId(),
        name: name.trim(),
        systemPrompt: systemPrompt.trim(),
        defaultModelSelection: defaultModelSelection,
        toolPolicy: toolPolicy,
        skillIds: skillIds,
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
    ToolPolicyConfig? toolPolicy,
    Set<String>? skillIds,
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
        toolPolicy: toolPolicy ?? existing.toolPolicy,
        skillIds: skillIds ?? existing.skillIds,
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
    if (_busy) return;
    _busy = true;
    try {
      await ref.read(runRecoveryControllerProvider.notifier).initialize();
      await _send(text, attachments: attachments);
    } finally {
      _busy = false;
    }
  }

  Future<void> _send(
    String text, {
    List<Attachment> attachments = const [],
  }) async {
    final trimmed = text.trim();
    if ((trimmed.isEmpty && attachments.isEmpty) || state.isGenerating) {
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
    var conversationId = ref.read(activeConversationProvider).conversationId;
    _checkRecoveredConversation(conversationId);
    if (conversationId == null) {
      final conversation = await repository.createConversation(
        assistantId: assistant?.id,
        modelSelectionOverride: ref
            .read(activeConversationProvider)
            .draftModelSelection,
      );
      conversationId = conversation.id;
      if (revision == _viewRevision) {
        ref.read(activeConversationProvider.notifier).adopt(conversationId);
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
    if (ref.read(activeConversationProvider).conversationId == conversationId) {
      state = state.copyWith(attachments: attachmentIndex);
    }

    final parentId = thread.currentMessageId;
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

    await _startRun(
      repository: repository,
      conversationId: conversationId,
      inputMessageId: userMessage.id,
      selection: selection,
      assistant: assistant,
    );
  }

  /// 重新生成当前分支的最后一条回答。
  ///
  /// 新建一条回答挂在同一条用户消息下，旧回答保留在消息树里不覆盖；
  /// 有工具执行历史时不自动重做动作（S3 起生效）。
  Future<void> regenerate() async {
    if (_busy) return;
    _busy = true;
    try {
      await ref.read(runRecoveryControllerProvider.notifier).initialize();
      await _regenerate();
    } finally {
      _busy = false;
    }
  }

  Future<void> _regenerate() async {
    if (state.isGenerating) return;
    final conversationId = ref.read(activeConversationProvider).conversationId;
    if (conversationId == null) return;
    _checkRecoveredConversation(conversationId);

    final repository = await ref.read(conversationRepositoryProvider.future);
    final thread = await repository.getThread(conversationId);
    if (thread == null || thread.branch.isEmpty) return;

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

    // 只重做最后的模型回答；已有动作与结果留在新分支的上下文中。
    // 即使停止时缺少结果消息，也保留调用，由上下文装配补齐实际错误。
    final toolHistory = thread.branch
        .skip(index + 1)
        .where(
          (message) => message.parts.any(
            (part) => part is ToolCallPart || part is ToolResultPart,
          ),
        );
    final parentId = toolHistory.lastOrNull?.id ?? userMessage.id;
    await repository.setCurrentMessage(conversationId, parentId);

    await _startRun(
      repository: repository,
      conversationId: conversationId,
      inputMessageId: userMessage.id,
      selection: selection,
      assistant: assistant,
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

  // --- AgentLoopHost：循环只决定顺序，真实 IO 都在控制器里 ---

  @override
  bool get isCancelled => _cancellation?.isCancelled ?? false;

  /// 一次运行的完整过程：创建 AgentRun（固定配置）→ 交给 [AgentLoop] 驱动。
  ///
  /// 循环里每一步的真实 IO 由本控制器实现（[AgentLoopHost]）：一轮模型请求、
  /// 一次工具执行、结果回填与运行收口；中途改助手或模型只影响下一次运行。
  Future<void> _startRun({
    required ConversationRepository repository,
    required String conversationId,
    required String inputMessageId,
    required ChatModelSelection selection,
    required Assistant? assistant,
  }) async {
    final runs = await ref.read(agentRunRepositoryProvider.future);
    final modelConfig = selection.profile.models
        .where((m) => m.id == selection.model)
        .firstOrNull;

    final baseRegistry = ref.read(toolRegistryProvider);
    final enabled = selection.supportsTools
        ? assistant?.toolPolicy.enabledTools ?? <String>{}
        : <String>{};
    // 仅助手选择了 MCP 时访问目录；普通聊天没有扩展连接前置。
    final mcpEntries = enabled.any((name) => name.startsWith('mcp_'))
        ? await (await ref.read(mcpServerRepositoryProvider.future)).list()
        : const [];
    final skillLease =
        selection.supportsTools && (assistant?.skillIds.isNotEmpty ?? false)
        ? await (await ref.read(skillRepositoryProvider.future))
              .acquire(assistant!.skillIds)
        : null;
    WorkspaceLease? workspaceLease;
    try {
      final thread = await repository.getThread(conversationId);
      final workspaceId = thread?.conversation.workspaceId;
      if (workspaceId != null) {
        workspaceLease = await (await ref.read(
          workspaceRepositoryProvider.future,
        )).acquire(workspaceId);
      }
      final workspace = workspaceLease?.snapshot;
      final skills = skillLease?.skills ?? const [];
      final skillTool = skills.isEmpty
          ? null
          : ReadSkillTool(
              skills: skills,
              repository: await ref.read(skillRepositoryProvider.future),
              assistants: await ref.read(assistantRepositoryProvider.future),
              assistantId: assistant?.id,
              linuxAvailable: workspace?.linuxAvailable == true,
            );
      final prepareSkill =
          skillTool == null || workspace?.linuxAvailable != true
          ? null
          : PrepareSkillTool(
              skillTool,
              workspace!,
              WorkspaceFiles(
                await ref.read(workspaceRepositoryProvider.future),
              ),
            );
      final snapshots = <ToolSnapshot>[
        if (skillTool != null) skillTool.snapshot,
        if (prepareSkill != null) prepareSkill.snapshot,
        for (final tool in baseRegistry.tools)
          if (enabled.contains(tool.name) &&
              (!_environmentTools.contains(tool.name) ||
                  workspace?.linuxAvailable == true))
            tool.snapshot,
        for (final entry in mcpEntries)
          if (entry.profile.enabled && !entry.profile.deleting)
            for (final tool in entry.tools)
              if (enabled.contains(tool.name)) tool,
      ];

      // 连接快照只存服务商 id、协议与地址，密钥按 id 在调用时读取。
      final run = await runs.create(
        AgentRun(
          id: generateId(),
          conversationId: conversationId,
          assistantId: assistant?.id,
          inputMessageId: inputMessageId,
          configuration: RunConfiguration(
            connection: RunConnection(
              profileId: selection.profile.id,
              protocol: selection.profile.protocol.name,
              baseUrl: selection.profile.baseUrl,
              requiresKey: selection.profile.requiresKey,
            ),
            modelSelection: model.ModelSelection(
              profileId: selection.profile.id,
              modelId: selection.model,
              reasoningEffort: selection.effort,
              temperature: modelConfig?.temperature,
              maxOutputTokens: modelConfig?.maxOutputTokens,
            ),
            systemPrompt: assistant?.systemPrompt ?? '',
            toolSnapshots: snapshots,
            skills: skills,
            workspace: workspace,
            mcpServers: [
              for (final entry in mcpEntries)
                if (snapshots.any(
                  (tool) =>
                      tool.source.kind == ToolSourceKind.mcp &&
                      tool.source.id == entry.profile.id,
                ))
                  entry.profile,
            ],
            executionScope: ref
                .read(settingsStorageProvider)
                .readExecutionScope(),
            enabledTools: selection.supportsTools
                ? {
                    if (skills.isNotEmpty) 'read_skill',
                    if (prepareSkill != null) 'prepare_skill',
                    for (final name
                        in assistant?.toolPolicy.enabledTools ?? <String>{})
                      if ((selection.supportsImages ||
                              name != 'capture_screen') &&
                          (!_environmentTools.contains(name) ||
                              workspace?.linuxAvailable == true))
                        name,
                  }
                : const {},
            toolPolicies: selection.supportsTools
                ? assistant?.toolPolicy.overrides ?? const {}
                : const {},
            supportsReasoning: selection.supportsReasoning,
            supportsImages: selection.supportsImages,
            supportsTools: selection.supportsTools,
            compatOverrides: selection.profile.compatOverrides,
          ),
          createdAt: DateTime.now(),
        ),
      );

      try {
        await _driveRun(run, repository, selection);
      } on Failure {
        final stored = await runs.getById(run.id);
        if (stored?.status == RunStatus.running && stored?.turnCount == 0) {
          await runs.finish(
            run.id,
            status: RunStatus.failed,
            finishReason: RunFinishReason.storageError,
          );
        }
        rethrow;
      }
    } finally {
      workspaceLease?.close();
      await skillLease?.close();
    }
  }

  Future<void> _driveRun(
    AgentRun run,
    ConversationRepository repository,
    ChatModelSelection selection, {
    bool resuming = false,
  }) async {
    final runs = await ref.read(agentRunRepositoryProvider.future);
    final toolCalls = await ref.read(toolCallRepositoryProvider.future);
    final storage = await ref.read(artifactStorageProvider.future);
    final recovery = ref.read(runRecoveryControllerProvider.notifier);

    final mcp = run.configuration.mcpServers.isEmpty
        ? null
        : McpRunRuntime(
            run: run,
            repository: await ref.read(mcpServerRepositoryProvider.future),
            assistants: await ref.read(assistantRepositoryProvider.future),
            connections: ref.read(mcpConnectionsProvider),
          );
    final base = ref.read(toolRegistryProvider);
    final skillTool = run.configuration.skills.isEmpty
        ? null
        : ReadSkillTool(
            skills: run.configuration.skills,
            repository: await ref.read(skillRepositoryProvider.future),
            assistants: await ref.read(assistantRepositoryProvider.future),
            assistantId: run.assistantId,
            linuxAvailable: run.configuration.workspace?.linuxAvailable == true,
          );
    final binding = run.configuration.workspace;
    final workspaceRepository = binding == null
        ? null
        : await ref.read(workspaceRepositoryProvider.future);
    final workspaceFiles = workspaceRepository == null
        ? null
        : WorkspaceFiles(workspaceRepository);
    final processDriver = binding?.linuxAvailable != true
        ? null
        : ref.read(processDriverProvider);
    final registry = ToolRegistry([
      for (final tool in base.tools)
        if (!_environmentTools.contains(tool.name)) tool,
      if (binding?.linuxAvailable == true)
        ShellTool(
          workspace: binding,
          driver: processDriver,
          files: workspaceFiles,
        ),
      if (binding?.linuxAvailable == true)
        InstallTool(
          workspace: binding,
          repository: workspaceRepository,
          driver: processDriver,
        ),
      if (binding?.linuxAvailable == true && skillTool != null)
        PrepareSkillTool(skillTool, binding!, workspaceFiles!),
      ...?mcp?.tools(),
      ?skillTool,
    ]);
    final execution = ref.read(executionControllerProvider.notifier);
    final executor = ToolExecutor(
      registry: registry,
      toolCalls: toolCalls,
      runs: runs,
      currentPolicy: (tool) async {
        if (tool is ReadSkillTool) return tool.currentPolicy();
        if (tool is PrepareSkillTool) return tool.currentPolicy();
        if (tool is ShellTool) {
          final assistant = run.assistantId == null
              ? null
              : await (await ref.read(assistantRepositoryProvider.future))
                    .getById(run.assistantId!);
          return assistant?.toolPolicy.overrides['shell'] ?? ToolPolicy.deny;
        }
        if (tool.source.kind != ToolSourceKind.mcp) {
          return registry.policyFor(
            tool,
            run.configuration.enabledTools,
            run.configuration.toolPolicies,
          );
        }
        await mcp!.checkAvailable(tool.snapshot);
        return mcp.currentPolicy(tool.snapshot);
      },
      prepareChannel: (tool, arguments) async {
        if (tool is ShellTool) await processDriver!.beginTask(run.id, '工作区命令');
        if (tool.usesPlatform(arguments)) {
          await execution.ensureDeviceHost(
            run.id,
            deviceTask: tool.channel != ExecutionChannel.app,
          );
        }
      },
    );
    executor.onConfirmationRequired = _confirmToolCall;

    _run = run;
    _selection = selection;
    _repository = repository;
    _runs = runs;
    _storage = storage;
    _registry = registry;
    _executor = executor;
    _cancellation = RunCancellation();
    _runFinished = false;
    _turnFailure = null;
    _turnTailId = null;
    recovery.runStarted(run.id);
    WorkspaceLease? resumedWorkspace;
    final processStops = processDriver?.stops.listen((owner) {
      if (owner == run.id) stop();
    });
    try {
      if (resuming && binding != null) {
        resumedWorkspace = await workspaceRepository!.acquire(
          binding.id,
          expected: binding,
        );
      }
      execution.beginRun(
        run.id,
        stop: stop,
        scope: run.configuration.executionScope,
        readCurrentAppPolicy: () =>
            ref.read(settingsStorageProvider).readExecutionScope().appPolicy,
      );
      _runAttachments = await _attachmentIndex(run.conversationId, const []);
      state = state.copyWith(
        isGenerating: true,
        clearStreaming: true,
        runningConversationId: run.conversationId,
        attachments:
            ref.read(activeConversationProvider).conversationId ==
                run.conversationId
            ? _runAttachments
            : null,
      );

      if (resuming && !await _restorePendingTools()) return;
      await AgentLoop(this, maxTurns: run.maxTurns - run.turnCount).run();
    } on StorageFailure {
      // 落库失败：运行按存储失败收口后再交给界面提示，不留永远 running 的运行。
      try {
        await _finishRun(RunStatus.failed, RunFinishReason.storageError);
      } on Failure {
        AppLogger.error('运行终态未能保存，启动时需核对');
      }
      rethrow;
    } on Failure {
      await _finishUnexpectedRun();
      rethrow;
    } catch (error, stackTrace) {
      AppLogger.error('运行异常：${error.runtimeType}', null, stackTrace);
      await _finishUnexpectedRun();
      throw UnknownFailure('运行执行失败', cause: error);
    } finally {
      _acceptingChunks = false;
      _flushTimer?.cancel();
      _flushTimer = null;
      _publishTimer?.cancel();
      _publishTimer = null;
      _streamingMessageId = null;
      _cancellation?.cancel();
      await mcp?.close();
      try {
        if (processDriver != null) await processDriver.endTask(run.id);
      } on Failure {
        AppLogger.warning('Linux 任务服务未确认结束');
      }
      await processStops?.cancel();
      resumedWorkspace?.close();
      try {
        await execution.endRun(run.id);
      } on Failure {
        // 控制器保留可见错误；不让服务清理失败跳过本地资源与运行收尾。
        AppLogger.warning('Android 任务服务未确认结束');
      }
      await _subscription?.cancel();
      _subscription = null;
      _doneCompleter = null;
      _run = null;
      _selection = null;
      _cancellation = null;
      _executor = null;
      if (ref.mounted) {
        // 清理与恢复索引刷新完成后才解锁发送，避免两个根任务交错写入。
        await recovery.runFinished().catchError((Object _) {});
      }
      if (ref.mounted) {
        state = state.copyWith(
          isGenerating: false,
          clearStreaming: true,
          clearRun: true,
        );
      }
    }
  }

  Future<void> _finishUnexpectedRun() async {
    try {
      await _finishRun(
        isCancelled ? RunStatus.stopped : RunStatus.failed,
        isCancelled
            ? RunFinishReason.cancelled
            : RunFinishReason.executionError,
      );
    } on Failure {
      AppLogger.error('运行终态未能保存，启动时需核对');
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

  /// 用户主动继续已保存的位置；配置取运行快照，不重新执行已知结果。
  Future<void> resumeRun(String runId) async {
    if (_busy) return;
    _busy = true;
    try {
      final recovery = ref.read(runRecoveryControllerProvider.notifier);
      await recovery.refresh();
      final entry = (ref.read(runRecoveryControllerProvider).value ?? [])
          .where((entry) => entry.run.id == runId)
          .firstOrNull;
      if (entry == null) throw const OperationFailure('此任务已结束');
      final run = entry.run;
      final config = run.configuration;
      final modelConfig = config.modelSelection;
      final protocol = ApiProtocol.values
          .where((p) => p.name == config.connection.protocol)
          .firstOrNull;
      if (protocol == null) throw const OperationFailure('运行的协议配置无效');
      final profile = ProviderProfile(
        id: config.connection.profileId,
        name: '运行配置',
        protocol: protocol,
        baseUrl: config.connection.baseUrl,
        requiresKey: config.connection.requiresKey,
        compatOverrides: config.compatOverrides,
        createdAt: run.createdAt,
        models: [
          ProfileModel(
            id: modelConfig.modelId,
            supportsReasoning: config.supportsReasoning,
            supportsImages: config.supportsImages,
            supportsTools: config.supportsTools,
            temperature: modelConfig.temperature,
            maxOutputTokens: modelConfig.maxOutputTokens,
          ),
        ],
      );
      await openConversation(run.conversationId);
      final repository = await ref.read(conversationRepositoryProvider.future);
      await _driveRun(
        run,
        repository,
        ChatModelSelection(
          profile: profile,
          model: modelConfig.modelId,
          supportsReasoning: config.supportsReasoning,
          supportsImages: config.supportsImages,
          supportsTools: config.supportsTools,
          effort: modelConfig.reasoningEffort,
        ),
        resuming: true,
      );
    } finally {
      _busy = false;
    }
  }

  Future<bool> _restorePendingTools() async {
    final run = _run!;
    final thread = await _repository!.getThread(run.conversationId);
    if (thread == null) throw const OperationFailure('会话已不存在');
    _run = await _runs!.resume(run.id);
    _turnTailId = thread.currentMessageId;
    final records = await _recordsFor(thread.branch);
    for (final message in thread.branch.where(
      (m) => m.runId == run.id && m.role == ChatRole.assistant,
    )) {
      _turnParts = message.parts;
      _turnUsage = message.usage;
      _turnThinkingDurationMs = message.thinkingDurationMs;
      final turn = StreamedTurn(
        messageId: message.id,
        parts: message.parts,
        toolCalls: const [],
      );
      for (final part in message.parts.whereType<ToolCallPart>()) {
        final record = records[part.toolCallId];
        if (record == null) throw const OperationFailure('中断任务的工具记录不完整');
        if (record.resultMessageId != null) continue;
        final providerCallId = record.providerCallId;
        if (providerCallId == null) {
          throw const OperationFailure('中断调用缺少协议标识，无法继续');
        }
        if (isCancelled) {
          await finish(AgentFinishReason.cancelled);
          return false;
        }
        await executeTool(
          ToolCall(
            callId: providerCallId,
            toolName: record.toolName,
            arguments: record.arguments,
            providerData: record.providerData,
            recordId: record.id,
          ),
          turn,
        );
      }
    }
    return true;
  }

  /// 一轮模型请求：装配上下文 → 创建助手消息 → 流式累积 → 收口落库。
  @override
  Future<StreamedTurn> streamTurn() async {
    final run = _run!;
    final repository = _repository!;
    final selection = _selection!;

    final thread = await repository.getThread(run.conversationId);
    if (thread == null) {
      throw const UnknownFailure('会话不存在或已删除');
    }
    // 轮次在本轮模型调用前 +1；每次真实请求（含重试）另计尝试数。
    _run = await _runs!.beginTurn(run.id);
    final messages = await _resolveHistory(
      thread.branch,
      _runAttachments,
      currentModelId: selection.model,
    );

    return _requestWithRetry(
      selection,
      messages,
      parentId: thread.currentMessageId,
    );
  }

  /// 一次模型尝试保存为独立消息；失败尝试保留在同一父节点的历史分支。
  Future<StreamedTurn> _streamAttempt(
    AiProvider provider,
    ChatRequest request, {
    required String? parentId,
  }) async {
    final run = _run!;
    final repository = _repository!;
    final selection = _selection!;
    final assistantMessage = ChatMessage(
      id: generateId(),
      conversationId: run.conversationId,
      parentId: parentId,
      runId: run.id,
      role: ChatRole.assistant,
      status: MessageStatus.streaming,
      parts: const [],
      modelLabel: selection.model,
      createdAt: DateTime.now(),
    );
    await repository.appendMessage(assistantMessage);

    _liveParts.clear();
    _streamingMessageId = assistantMessage.id;
    _streamError = null;
    _stoppedManually = isCancelled;
    _responseComplete = false;
    _flushFailure = null;
    _turnThinkingDurationMs = null;
    _turnParts = const [];
    _turnUsage = null;
    _turnFailure = null;
    _turnTailId = assistantMessage.id;
    state = state.copyWith(
      streamingParts: const [],
      streamingMessageId: assistantMessage.id,
    );

    try {
      if (!isCancelled) {
        _run = await _runs!.countModelAttempt(run.id);
        await _consume(provider, request);
      }
    } finally {
      _finishThinking();
      _flushTimer?.cancel();
      _flushTimer = null;
      await _pendingFlush;
      _publishImmediately();
      if (ref.mounted) state = state.copyWith(clearStreaming: true);
      _streamingMessageId = null;
    }
    if (_flushFailure case final error?) throw error;

    final parts = _partsFromLive(_liveParts);
    final toolCalls = _toolCallsFromLive();
    final failure =
        _streamError ??
        (!_responseComplete &&
                !isCancelled &&
                (parts.isNotEmpty || toolCalls.isNotEmpty)
            ? const ProviderError(
                ProviderErrorCategory.incompleteResponse,
                'incomplete response',
              )
            : null);
    _streamError = failure;
    _turnThinkingDurationMs = _currentThinkingDurationMs;

    if (_stoppedManually || isCancelled) {
      // 停止保留已收内容；未执行的调用不再进入调度。
      _turnParts = parts;
      await repository.updateMessage(
        messageId: assistantMessage.id,
        parts: parts,
        status: MessageStatus.cancelled,
        usage: _turnUsage,
        thinkingDurationMs: _turnThinkingDurationMs,
      );
      return StreamedTurn(
        messageId: assistantMessage.id,
        parts: _turnParts,
        toolCalls: const [],
        cancelled: true,
      );
    }

    if (failure != null) {
      // 流内错误与连接错误都保留已收内容，按失败收口。
      _turnFailure = RunFinishReason.modelError;
      _turnParts = [...parts, TextPart(text: failure.userMessage)];
      await repository.updateMessage(
        messageId: assistantMessage.id,
        parts: _turnParts,
        status: MessageStatus.failed,
        usage: _turnUsage,
        thinkingDurationMs: _turnThinkingDurationMs,
      );
      return StreamedTurn(
        messageId: assistantMessage.id,
        parts: _turnParts,
        toolCalls: const [],
        failed: true,
      );
    }

    if (parts.isEmpty && toolCalls.isEmpty) {
      // 网关用非 SSE 错误体（HTTP 200 + JSON）时会空跑结束，明确报错。
      _turnFailure = RunFinishReason.emptyResponse;
      _turnParts = const [TextPart(text: '服务商返回了空响应，请检查模型名称与推理等级设置')];
      await repository.updateMessage(
        messageId: assistantMessage.id,
        parts: _turnParts,
        status: MessageStatus.failed,
      );
      return StreamedTurn(
        messageId: assistantMessage.id,
        parts: _turnParts,
        toolCalls: const [],
        failed: true,
      );
    }

    final records = [
      for (final call in toolCalls)
        ToolCallRecord(
          id: call.recordId!,
          runId: run.id,
          assistantMessageId: assistantMessage.id,
          providerCallId: call.callId,
          toolName: call.toolName,
          source: _registry!.byName(call.toolName)?.source,
          arguments: call.arguments,
          providerData: call.providerData,
          target: _registry!
              .byName(call.toolName)
              ?.describeAction(call.arguments),
          channel:
              _registry!.byName(call.toolName)?.channel ?? ExecutionChannel.app,
          defaultPolicy:
              _registry!.byName(call.toolName)?.defaultPolicy ??
              ToolPolicy.deny,
          status: call.argumentsError == null
              ? ToolCallStatus.prepared
              : ToolCallStatus.failed,
          result: call.argumentsError,
          errorCode: call.argumentsError == null ? null : 'invalidArguments',
          createdAt: DateTime.now(),
          finishedAt: call.argumentsError == null ? null : DateTime.now(),
        ),
    ];
    var callIndex = 0;
    _turnParts = [
      for (final part in _liveParts)
        if (part.kind == PartKind.toolCall)
          ToolCallPart(
            toolCallId: records[callIndex++].id,
            providerData: part.providerData,
          )
        else if (part.kind != PartKind.provider &&
            (part.buffer.isNotEmpty || part.providerData != null))
          part.toPart(),
    ];
    await repository.completeToolTurn(
      messageId: assistantMessage.id,
      runId: run.id,
      parts: _turnParts,
      calls: records,
      usage: _turnUsage,
      thinkingDurationMs: _turnThinkingDurationMs,
    );
    return StreamedTurn(
      messageId: assistantMessage.id,
      parts: _turnParts,
      toolCalls: toolCalls,
    );
  }

  /// 执行一次工具调用：记录 → 结果消息 → 结果进入下一轮上下文。
  @override
  Future<ExecutedTool> executeTool(ToolCall call, StreamedTurn turn) async {
    final run = _run!;
    final cancellation = _cancellation!;
    final repository = _repository!;

    if (call.recordId == null) throw const OperationFailure('调用尚未持久化，不能执行');
    final channel =
        _registry!.byName(call.toolName)?.channel ?? ExecutionChannel.app;
    final executed = await _executor!.execute(
      ToolExecutionRequest(
        runId: run.id,
        assistantMessageId: turn.messageId,
        toolName: call.toolName,
        arguments: call.arguments,
        channel: channel,
        conversationId: run.conversationId,
        attachments: await _storage!.attachments(run.conversationId),
        workspaceDirectory: run.configuration.workspace?.rootPath ?? '',
        storage: _storage!,
        enabledTools: run.configuration.enabledTools,
        toolPolicies: run.configuration.toolPolicies,
        providerCallId: call.callId,
        providerData: call.providerData,
        recordId: call.recordId,
      ),
      cancellation,
    );
    final record = executed.record;
    if (record.status == ToolCallStatus.succeeded ||
        record.artifacts.isNotEmpty) {
      await _registerArtifacts(
        run.conversationId,
        toolReported: record.artifacts.isNotEmpty,
      );
    }

    final content = _resultText(record);
    // 结果消息接在本轮末尾之后：多个结果按执行顺序串成同一条分支。
    final message = ChatMessage(
      id: generateId(),
      conversationId: run.conversationId,
      parentId: _turnTailId ?? turn.messageId,
      runId: run.id,
      role: ChatRole.tool,
      status: MessageStatus.completed,
      parts: [
        ToolResultPart(toolCallId: record.id),
        TextPart(text: content),
      ],
      createdAt: DateTime.now(),
    );
    // 结果记录与结果消息在同一事务提交（design 第五部分 §3.3）。
    final saved = await repository.saveToolResult(
      toolCallId: record.id,
      message: message,
    );
    _turnTailId = message.id;
    return ExecutedTool(
      callId: call.callId,
      content: content,
      isError: saved.status != ToolCallStatus.succeeded,
      record: saved,
      messageId: message.id,
    );
  }

  /// 本轮工具结果已回填：记录分支位置并清空待处理调用。
  @override
  Future<void> finishTurn(StreamedTurn turn) async {
    final run = _run;
    if (run == null) return;
    _run = await _runs!.finishTurn(
      run.id,
      currentMessageId: _turnTailId ?? turn.messageId,
    );
  }

  /// 运行终态：按原因写状态与结束原因（design 第二部分 §4）。
  @override
  Future<void> finish(AgentFinishReason reason) {
    final (RunStatus, RunFinishReason?) result = switch (reason) {
      // 本轮以错误或空回复收场时，运行按具体原因失败。
      AgentFinishReason.completed =>
        _turnFailure == null
            ? (RunStatus.completed, RunFinishReason.completed)
            : (RunStatus.failed, _turnFailure),
      AgentFinishReason.cancelled => (
        RunStatus.stopped,
        RunFinishReason.cancelled,
      ),
      AgentFinishReason.turnLimit => (
        RunStatus.failed,
        RunFinishReason.turnLimit,
      ),
    };
    return _finishRun(result.$1, result.$2);
  }

  /// 运行终态只写一次：循环收口与异常收尾共用。
  Future<void> _finishRun(
    RunStatus status,
    RunFinishReason? finishReason,
  ) async {
    final run = _run;
    if (run == null || _runFinished) return;
    _run = await _runs!.finish(
      run.id,
      status: status,
      finishReason: finishReason,
      currentMessageId: _turnTailId,
    );
    _runFinished = true;
  }

  /// 请求用户确认：等待期间运行记 awaitingConfirmation 与待确认调用。
  ///
  /// 应用级控制器持有待确认请求；页面销毁/移交不改变决定或原期限。
  /// 到期按拒绝，停止由执行器按取消收口。
  Future<ToolDecision> _confirmToolCall(ToolConfirmationRequest request) async {
    final run = _run;
    if (run != null) {
      _run = await _runs!.awaitConfirmation(run.id, request.record.id);
    }
    final cancellation = _cancellation;
    if (cancellation == null) return ToolDecision.expired;
    return ref
        .read(executionControllerProvider.notifier)
        .confirm(request, cancellation);
  }

  /// 停止生成：结束本轮模型请求与正在进行的工具执行。
  ///
  /// 等待确认中停止不执行动作（记录 cancelled）；执行中停止请求工具取消，
  /// 工具实际返回的结果如实记录（design 第二部分 §6）。
  void stop() {
    if (_cancellation == null) return;
    _finishThinking();
    _stoppedManually = true;
    _cancellation?.cancel();
    _acceptingChunks = false;
    _completeRequest();
  }

  void _completeRequest() {
    final done = _doneCompleter;
    if (done != null && !done.isCompleted) done.complete();
  }

  /// 重试当前模型轮：请求上下文固定，先保存失败尝试再退避，不重放工具。
  Future<StreamedTurn> _requestWithRetry(
    ChatModelSelection selection,
    List<ResolvedMessage> messages, {
    required String? parentId,
  }) async {
    final apiKey = selection.profile.requiresKey
        ? await ref.read(secureKeyStorageProvider).read(selection.profile.id) ??
              ''
        : '';
    final provider = ref.read(aiProviderFactoryProvider)(
      selection.profile,
      apiKey,
    );
    // 模型参数来自该模型的配置；未设置时不下发，由服务端默认决定。
    final modelConfig = selection.profile.models
        .where((model) => model.id == selection.model)
        .firstOrNull;
    final request = ChatRequest(
      modelId: selection.model,
      systemPrompt:
          '${_run?.configuration.systemPrompt ?? ''}${skillDiscoveryPrompt(_run!.configuration.skills, linuxAvailable: _run!.configuration.workspace?.linuxAvailable == true)}${workspacePrompt(_run!.configuration.workspace)}${executionScopePrompt(_run!.configuration.executionScope, toolExecution: _run!.configuration.enabledTools.isNotEmpty, applicationOperations: _run!.configuration.enabledTools.any(applicationOperationTools.contains))}',
      messages: messages,
      tools: _toolDefinitions(),
      // 模型不支持推理时不下发任何推理字段。
      reasoningEffort: selection.supportsReasoning
          ? selection.effort
          : ReasoningEffort.off,
      temperature: modelConfig?.temperature,
      maxOutputTokens: modelConfig?.maxOutputTokens,
    );

    final policy = ref.read(modelRetryPolicyProvider);
    for (var attempt = 0; ; attempt++) {
      final turn = await _streamAttempt(provider, request, parentId: parentId);
      if (isCancelled || turn.cancelled) return turn;
      final error = _streamError;
      if (error == null) return turn;
      final delay = policy.delayFor(error, attempt + 1);
      if (delay == null) return turn;
      if (ref.mounted) {
        state = state.copyWith(
          retry: ModelRetryState(
            attempt: attempt + 1,
            maxRetries: policy.maxRetries,
            delay: delay,
          ),
        );
      }
      await waitForModelRetry(delay, _cancellation!);
      if (ref.mounted) state = state.copyWith(clearRetry: true);
      if (isCancelled) return turn;
    }
  }

  /// 订阅一次请求的事件流，直到结束、出错或被停止。
  Future<void> _consume(AiProvider provider, ChatRequest request) async {
    if (isCancelled) return;
    final done = Completer<void>();
    StreamSubscription<ChatChunk>? subscription;
    _doneCompleter = done;
    _acceptingChunks = true;
    try {
      subscription = provider
          .streamChat(request)
          .listen(
            (chunk) {
              if (identical(_doneCompleter, done)) _onChunk(chunk);
            },
            onError: (Object error, StackTrace stackTrace) {
              if (!_acceptingChunks || !identical(_doneCompleter, done)) return;
              _acceptingChunks = false;
              _finishThinking();
              if (error is StorageFailure) {
                if (!done.isCompleted) done.completeError(error, stackTrace);
              } else {
                _streamError = mapProviderException(error);
                if (!done.isCompleted) done.complete();
              }
            },
            onDone: () {
              _finishThinking();
              if (!done.isCompleted) done.complete();
            },
            cancelOnError: true,
          );
      _subscription = subscription;
      await done.future;
    } on StorageFailure {
      rethrow;
    } catch (error) {
      _streamError = mapProviderException(error);
    } finally {
      _acceptingChunks = false;
      _finishThinking();
      try {
        await subscription?.cancel();
      } catch (error) {
        if (!isCancelled && !_responseComplete) {
          _streamError ??= mapProviderException(error);
        }
        AppLogger.warning('模型流清理失败');
      }
      if (identical(_subscription, subscription)) _subscription = null;
      if (identical(_doneCompleter, done)) _doneCompleter = null;
    }
  }

  /// 本次运行下发的工具定义：助手策略与模型工具能力都满足才下发。
  List<ToolDefinition> _toolDefinitions() {
    final selection = _selection;
    final run = _run;
    final registry = _registry;
    if (selection == null || run == null || registry == null) return const [];
    if (!selection.supportsTools) return const [];
    return registry.definitionsFor(
      run.configuration.enabledTools,
      run.configuration.toolPolicies,
    );
  }

  /// 本轮的工具调用：完整响应结束后才解析参数片段。
  List<ToolCall> _toolCallsFromLive() {
    final calls = <ToolCall>[];
    for (final part in _liveParts) {
      if (part.kind != PartKind.toolCall) continue;
      final parsed = _parseToolArguments(part.buffer.toString());
      calls.add(
        ToolCall(
          callId: part.callId ?? part.partId,
          toolName: part.toolName ?? '',
          arguments: parsed.arguments,
          argumentsError: parsed.error,
          providerData: part.providerData,
          recordId: generateId(),
        ),
      );
    }
    return calls;
  }

  /// 解析工具参数：不完整或不是 JSON 对象的片段如实报错，
  /// 不从正文里提取命令「就近执行」。
  ({Map<String, dynamic> arguments, String? error}) _parseToolArguments(
    String fragment,
  ) {
    final text = fragment.trim();
    // 无参数的工具不会给出参数片段。
    if (text.isEmpty) return (arguments: const {}, error: null);
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      return (arguments: const {}, error: '工具参数不是完整的 JSON，本次调用未执行；请重新给出完整参数');
    }
    if (decoded is Map<String, dynamic>) {
      return (arguments: decoded, error: null);
    }
    return (arguments: const {}, error: '工具参数必须是 JSON 对象，本次调用未执行');
  }

  /// 产物登记与附件索引刷新：写文件产生的产物要出现在会话附件里。
  ///
  /// [toolReported] 表示工具自己已登记并引用了产物（不会出现在待登记扫描里），
  /// 索引同样要刷新，否则卡片与气泡查不到这份文件。
  Future<void> _registerArtifacts(
    String conversationId, {
    bool toolReported = false,
  }) async {
    final storage = _storage;
    if (storage == null) return;
    try {
      final registered = await storage.registerPendingArtifacts(conversationId);
      if (registered.isEmpty && !toolReported) return;
      _runAttachments = await _attachmentIndex(conversationId, const []);
      if (ref.read(activeConversationProvider).conversationId ==
          conversationId) {
        state = state.copyWith(attachments: _runAttachments);
      }
    } on Failure {
      rethrow;
    } on Exception {
      throw const OperationFailure('产物登记失败，请处理后再继续任务');
    }
  }

  /// 回填给模型与结果消息的文本；记录里没有结果时按状态给出说明。
  String _resultText(ToolCallRecord record) => _truncateResult(
    record.result ?? _statusText(record.status),
    limit: _toolResultLimit(record),
  );

  int _toolResultLimit(ToolCallRecord record) =>
      const {'read_file', 'list_files'}.contains(record.toolName)
      ? 128 * 1024
      : record.channel == ExecutionChannel.accessibility ||
            record.toolName == 'list_apps'
      ? 64 * 1024
      : _maxToolResultBytes;

  String _statusText(ToolCallStatus status) => switch (status) {
    ToolCallStatus.rejected => '用户拒绝了本次动作，没有执行。',
    ToolCallStatus.cancelled => '本次调用已取消，没有取得结果。',
    ToolCallStatus.prepared ||
    ToolCallStatus.awaitingConfirmation ||
    ToolCallStatus.executing => '本次调用没有返回内容。',
    ToolCallStatus.succeeded => '工具执行完成，但没有返回内容。',
    ToolCallStatus.failed => '工具执行失败，没有返回内容。',
  };

  /// 结果按上限截断：超出时附截断标记，不把整段输出塞进上下文。
  String _truncateResult(String text, {int limit = _maxToolResultBytes}) {
    final bytes = utf8.encode(text);
    if (bytes.length <= limit) return text;
    final head = utf8.decode(bytes.sublist(0, limit), allowMalformed: true);
    return '$head\n【结果已截断：超过 ${limit ~/ 1024}KB】';
  }

  void _onChunk(ChatChunk chunk) {
    if (!_acceptingChunks || isCancelled || !ref.mounted) return;
    switch (chunk) {
      case PartStart():
        if (chunk.kind == PartKind.toolCall) {
          _finishThinking();
          _liveParts.add(_LivePart.toolCall(chunk.partId));
        } else if (chunk.kind == PartKind.provider) {
          _liveParts.add(_LivePart.provider(chunk.partId));
        } else {
          final part = _LivePart(chunk.partId, chunk.kind);
          if (chunk.initialContent?.isNotEmpty == true) {
            part.buffer.write(chunk.initialContent);
            _markProgress(part);
          }
          _liveParts.add(part);
        }
      case TextDelta():
        _livePart(chunk.partId, PartKind.text).buffer.write(chunk.text);
        if (chunk.text.isNotEmpty) _finishThinking();
      case ReasoningDelta():
        final part = _livePart(chunk.partId, PartKind.reasoning);
        part.buffer.write(chunk.text);
        if (chunk.text.isNotEmpty) _markProgress(part);
      case ToolCallDelta():
        _finishThinking();
        final part = _livePart(chunk.partId, PartKind.toolCall);
        part.callId = chunk.callId ?? part.callId;
        part.toolName = chunk.toolName ?? part.toolName;
        // 参数片段只累积；完整响应结束后才解析，不逐段解析。
        if (chunk.argumentsFragment != null) {
          part.buffer.write(chunk.argumentsFragment);
        }
      case PartEnd():
        final part = _liveParts.where((entry) => entry.partId == chunk.partId);
        if (part.isEmpty) break;
        // 完整块以协议收口结果为准。
        switch (chunk.part) {
          case TextPart(:final text):
            part.first.buffer
              ..clear()
              ..write(text);
            if (text.isNotEmpty) _finishThinking();
          case ReasoningPart(:final publicText, :final providerData):
            part.first.buffer
              ..clear()
              ..write(publicText);
            part.first.providerData = providerData ?? part.first.providerData;
            if (publicText.isNotEmpty) _markProgress(part.first);
            part.first.finishThinking();
          case ToolCallPart(:final toolCallId, :final providerData):
            // 协议收口的调用 id 是回填配对的依据。
            part.first.callId = toolCallId;
            part.first.providerData = providerData ?? part.first.providerData;
          default:
            break;
        }
      case UsageChunk(:final usage):
        _turnUsage = usage;
      case ResponseEnd(:final complete):
        _finishThinking();
        _responseComplete = complete;
        if (!complete) {
          _streamError = const ProviderError(
            ProviderErrorCategory.incompleteResponse,
            'response ended before completion',
          );
        }
        _acceptingChunks = false;
        _completeRequest();
      case ResponseError(:final error):
        _finishThinking();
        // 流内错误即本次响应结束：保留已收内容，按失败收口。
        _streamError = error;
        _acceptingChunks = false;
        _completeRequest();
    }
    _scheduleFlush();
  }

  _LivePart _livePart(String partId, PartKind kind) {
    for (final part in _liveParts) {
      if (part.partId == partId) return part;
    }
    final part = _LivePart(partId, kind);
    _liveParts.add(part);
    return part;
  }

  void _markProgress(_LivePart part) {
    switch (part.kind) {
      case PartKind.reasoning:
        if (part.thinkingStartedAt != null) return;
        _finishThinking();
        part.thinkingStartedAt = DateTime.now();
      case PartKind.text:
        _finishThinking();
      default:
        break;
    }
  }

  void _finishThinking() {
    for (final part in _liveParts) {
      part.finishThinking();
    }
  }

  int? get _currentThinkingDurationMs {
    int? total;
    for (final part in _liveParts) {
      final duration = part.currentThinkingDurationMs;
      if (duration != null) total = (total ?? 0) + duration;
    }
    return total;
  }

  void _scheduleFlush() {
    _publishTimer ??= Timer(_publishInterval, _publishNow);
    _flushTimer ??= Timer(_flushInterval, _flushNow);
  }

  /// 把累积的流式内容合批发布到界面；定时器停在这里，下一次增量再起。
  void _publishNow() {
    _publishTimer = null;
    if (_liveParts.isEmpty || !ref.mounted) return;
    state = state.copyWith(streamingParts: _partsFromLive(_liveParts));
  }

  /// 收口前把最后一批增量立即发布，界面不会停在半句话上。
  void _publishImmediately() {
    _publishTimer?.cancel();
    _publishTimer = null;
    _publishNow();
  }

  void _flushNow() {
    _flushTimer = null;
    final messageId = _streamingMessageId;
    if (messageId == null) return;
    final parts = _partsFromLive(_liveParts);
    final thinkingDuration = _currentThinkingDurationMs;
    _pendingFlush = _pendingFlush.then((_) async {
      if (_flushFailure != null) return;
      try {
        await _repository!.updateMessage(
          messageId: messageId,
          parts: parts,
          status: MessageStatus.streaming,
          thinkingDurationMs: thinkingDuration,
        );
      } on Failure catch (error) {
        _flushFailure = error;
        _acceptingChunks = false;
        _completeRequest();
      }
    });
  }

  /// 当前分支 + 工具记录 → 一次请求的内容（design 第二部分 §3）。
  ///
  /// 工具调用与结果按记录成组保留：调用引用的记录与结果消息都存在才进入
  /// 请求，缺少结果消息时按已知记录补回错误，不留下孤立调用。
  Future<List<ResolvedMessage>> _resolveHistory(
    List<ChatMessage> messages,
    Map<String, Attachment> attachments, {
    required String currentModelId,
  }) async {
    final records = await _recordsFor(messages);
    final latestVisualRecord = messages
        .expand((message) => message.parts)
        .whereType<ToolResultPart>()
        .map((part) => records[part.toolCallId])
        .where(
          (record) =>
              record != null && visualOperationTools.contains(record.toolName),
        )
        .lastOrNull;
    // 结果文本以结果消息为准：拒绝等状态只写进结果消息，记录里可能没有。
    final results = <String, ResolvedToolResult>{};
    for (final message in messages) {
      for (final part in message.parts) {
        if (part is! ToolResultPart) continue;
        final record = records[part.toolCallId];
        final callId = record?.providerCallId;
        if (record == null || callId == null) continue;
        results[part.toolCallId] = ResolvedToolResult(
          callId: callId,
          images:
              record.id == latestVisualRecord?.id ||
                  record.source?.kind == ToolSourceKind.mcp
              ? [
                  for (final id in record.artifacts)
                    if (attachments[id]?.isImage == true) attachments[id]!,
                ]
              : const [],
          content: _truncateResult(
            message.text.isNotEmpty
                ? message.text
                : (record.result ?? _statusText(record.status)),
            limit: _toolResultLimit(record),
          ),
          isError: record.status != ToolCallStatus.succeeded,
        );
      }
    }

    final resolved = <ResolvedMessage>[];
    final sourceRuns = <String, AgentRun?>{_run!.id: _run};
    for (final message in messages) {
      // 被中断（停止生成）或出错收场的那一轮：已经产出的正文、已经执行的调用与
      // 结果照常进上下文——用户看到的和模型知道的要对得上，否则模型不知道文件
      // 已经写过、请求已经发过，下一轮可能重做一遍。
      final interrupted =
          message.role == ChatRole.assistant && _isInterrupted(message);
      final parts = <ResolvedPart>[];
      // 有调用却没有结果的调用：补一条合成结果，而不是把调用删掉
      // （pi transform-messages 规则 5）。删掉会让模型以为自己没调用过，
      // 补上它才知道那次调用没有得到结果。
      final missingResults = <ResolvedToolCall, ToolCallRecord>{};
      for (final part in message.parts) {
        switch (part) {
          case TextPart(:final text):
            if (message.role != ChatRole.tool && text.isNotEmpty) {
              parts.add(ResolvedText(text));
            }
          case ReasoningPart(:final publicText, :final providerData):
            // 中断那一轮的思考是半截的：回放给模型会把它带回被打断的思路，
            // 而半截思考既没有完整签名也不该当正文发回去。
            if (interrupted) break;
            // 只有协议状态的块（redacted thinking、只带回加密载荷的推理）也要
            // 带上：它们没有可展示文本，但缺了下一轮请求会被判为配对缺失。
            if (publicText.isNotEmpty || providerData != null) {
              parts.add(
                ResolvedReasoning(publicText, providerData: providerData),
              );
            }
          case ImagePart(:final attachmentId):
            final attachment = attachments[attachmentId];
            if (attachment != null) parts.add(ResolvedImage(attachment));
          case DocumentPart(:final attachmentId):
            final text = _readExtractedText(attachments[attachmentId]);
            if (text != null) parts.add(ResolvedText(text));
          case ToolCallPart(:final toolCallId):
            final record = records[toolCallId];
            final callId = record?.providerCallId;
            // 记录缺失（调用没落库）的调用不进入请求：没有 id 就没法配对。
            if (record == null || callId == null) break;
            final call = ResolvedToolCall(
              callId: callId,
              toolName: record.toolName,
              arguments: record.arguments,
              providerData: record.providerData,
            );
            parts.add(call);
            if (!results.containsKey(toolCallId)) missingResults[call] = record;
          case ToolResultPart(:final toolCallId):
            // 结果由所在消息自己回填（协议要求它与调用分属不同角色）。
            final result = results[toolCallId];
            if (result != null) parts.add(result);
          case ProviderPart():
            // 协议块不进入请求。
            break;
        }
      }
      if (parts.isEmpty) continue;
      var sameModel = message.modelLabel == currentModelId;
      if (sameModel && message.runId != null) {
        final sourceId = message.runId!;
        if (!sourceRuns.containsKey(sourceId)) {
          sourceRuns[sourceId] = await _runs!.getById(sourceId);
        }
        final source = sourceRuns[sourceId]?.configuration;
        sameModel =
            source != null &&
            source.connection.profileId == _selection!.profile.id &&
            source.connection.protocol == _selection!.profile.protocol.name &&
            source.connection.baseUrl == _selection!.profile.baseUrl &&
            source.modelSelection.modelId == currentModelId;
      } else if (message.runId == null) {
        sameModel = false;
      }
      resolved.add(
        ResolvedMessage(
          role: message.role,
          parts: parts,
          // 协议状态绑定配置、协议与模型；名称相同不代表签名可以跨端点回放。
          sameModel: sameModel,
        ),
      );
      if (missingResults.isNotEmpty) {
        resolved.add(
          ResolvedMessage(
            role: ChatRole.tool,
            sameModel: sameModel,
            parts: [
              for (final entry in missingResults.entries)
                ResolvedToolResult(
                  callId: entry.key.callId,
                  content: _truncateResult(
                    entry.value.result ?? _noResultText,
                    limit: _toolResultLimit(entry.value),
                  ),
                  isError: entry.value.status != ToolCallStatus.succeeded,
                ),
            ],
          ),
        );
      }
    }
    return resolved;
  }

  /// 调用没有得到结果时的合成回执：如实说明，不假装成功。
  static const _noResultText = '调用没有返回完整结果（尚未执行或运行已中断）。需要时先读取当前状态，不要直接重复提交动作。';

  /// 这一轮是否被中途打断（用户停止或出错收场）：它的思考块不完整，
  /// 不进上下文；已产出的正文与已执行的调用照常保留。
  static bool _isInterrupted(ChatMessage message) =>
      message.status == MessageStatus.failed ||
      message.status == MessageStatus.cancelled;

  /// 分支里引用到的工具记录：消息只存记录 id，参数与结果按 id 读回。
  Future<Map<String, ToolCallRecord>> _recordsFor(
    List<ChatMessage> messages,
  ) async {
    final ids = <String>{};
    for (final message in messages) {
      for (final part in message.parts) {
        switch (part) {
          case ToolCallPart(:final toolCallId):
          case ToolResultPart(:final toolCallId):
            ids.add(toolCallId);
          default:
            break;
        }
      }
    }
    if (ids.isEmpty) return const {};
    return _repository!.toolCallsByIds(ids);
  }

  /// 读取附件的文本内容。
  ///
  /// 文档用抽取结果（PDF/DOCX 在导入时抽取），文本文件直接读原文件；
  /// 抽取失败时把失败原因作为内容交给模型，让它知道这份文档没有文字，
  /// 而不是让请求里凭空少一份附件。
  String? _readExtractedText(Attachment? attachment) {
    if (attachment == null) return null;
    final error = attachment.extractionError;
    if (error != null) {
      return '【附件「${attachment.name}」未能提取文字：$error】';
    }
    final path = attachment.extractedTextPath ?? attachment.localPath;
    try {
      return File(path).readAsStringSync();
    } on FileSystemException {
      return null;
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

/// 流式期间的块缓冲；落库时转换成正式 Part。
class _LivePart {
  _LivePart(this.partId, this.kind);

  _LivePart.toolCall(this.partId)
    : kind = PartKind.toolCall,
      callId = null,
      toolName = null;

  _LivePart.provider(this.partId) : kind = PartKind.provider;

  final String partId;
  final PartKind kind;
  final StringBuffer buffer = StringBuffer();
  String? callId;
  String? toolName;
  DateTime? thinkingStartedAt;
  int? thinkingDurationMs;

  int? get currentThinkingDurationMs {
    final started = thinkingStartedAt;
    if (started == null) return null;
    final elapsed = DateTime.now().difference(started).inMilliseconds;
    return thinkingDurationMs ?? (elapsed < 0 ? 0 : elapsed);
  }

  void finishThinking() {
    thinkingDurationMs ??= currentThinkingDurationMs;
  }

  /// 协议块收口时带回来的状态：思考签名、加密推理、工具签名等。
  /// 它必须落在消息里，否则下一轮无法原样回传（design 第五部分 §4.3）。
  Map<String, dynamic>? providerData;

  MessagePart toPart() {
    final text = buffer.toString();
    return switch (kind) {
      PartKind.text => TextPart(text: text, partId: partId),
      PartKind.reasoning => ReasoningPart(
        publicText: text,
        partId: partId,
        providerData: providerData,
        startedAt: thinkingStartedAt,
        durationMs: thinkingDurationMs,
      ),
      // 工具调用以 ToolCallPart（引用记录 id）补进消息，协议块不落库。
      PartKind.toolCall ||
      PartKind.provider => TextPart(text: '', partId: partId),
    };
  }
}

/// 把流式缓冲转成消息内容块；空块不进入结果。
///
/// 只有协议状态的块（redacted thinking、只带回加密载荷的推理）也算内容：
/// 它们没有可展示的文本，但缺了就没法回传。
List<MessagePart> _partsFromLive(List<_LivePart> liveParts) {
  return [
    for (final part in liveParts)
      if (part.kind != PartKind.toolCall &&
          part.kind != PartKind.provider &&
          (part.buffer.isNotEmpty || part.providerData != null))
        part.toPart(),
  ];
}

/// 内置工具集：文件工具只访问应用私有目录，HTTP 工具走独立的 Dio 实例。
///
/// 单独开注入点是为了让测试能替换工具集（记录调用的假工具、替代网络实现），
/// 与 [aiProviderFactoryProvider] 同样的理由。
@Riverpod(keepAlive: true)
ToolRegistry toolRegistry(Ref ref) {
  final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 15)));
  ref.onDispose(() => dio.close(force: true));
  return buildBuiltInRegistry(
    platform: () => ref.read(channelDriverProvider),
    httpFetch: (request) => fetchToolHttp(dio, request),
  );
}

/// 单一重试预算，协议传输不再叠加第二层自动重试。
@Riverpod(keepAlive: true)
ModelRetryPolicy modelRetryPolicy(Ref ref) => const ModelRetryPolicy();

/// 工具运行的存储能力：会话附件、按会话隔离的产物目录与产物登记。
///
/// 附件索引由仓储注入：数据源只依赖模型与文件系统。
@Riverpod(keepAlive: true)
Future<ArtifactStorage> artifactStorage(Ref ref) async {
  final attachments = await ref.watch(attachmentStorageProvider.future);
  final repository = await ref.watch(conversationRepositoryProvider.future);
  return ArtifactStorage(
    root: attachments.root,
    loadAttachments: repository.attachmentsFor,
    saveAttachment: repository.saveAttachment,
  );
}

/// 会话列表流（置顶优先、按更新时间倒序）。
@riverpod
Stream<List<Conversation>> conversations(Ref ref) async* {
  final repository = await ref.watch(conversationRepositoryProvider.future);
  yield* repository.watchConversations();
}

/// 某会话的当前分支视图。
@riverpod
Stream<ConversationThread?> conversationThread(
  Ref ref,
  String conversationId,
) async* {
  final repository = await ref.watch(conversationRepositoryProvider.future);
  yield* repository.watchThread(conversationId);
}

/// 视图展示的消息：当前分支 + 流式中的最后一条回答，同一次运行合并为回答区。
///
/// [thread] 来自 repository 的 watch 流，是持久化事实；
/// [state] 只提供尚未落库的流式内容。
///
/// 工具结果消息（role: tool）是回填给模型的上下文，不作为对话正文展示：
/// 调用与结果由助手消息里的 [ToolCallPart] 引用记录、以工具卡片渲染，
/// 模型提出的调用与执行结果不冒充助手回答。
///
/// 工具循环每轮落一条助手消息（数据层如此，协议回填依赖它），这里把属于
/// 同一次运行的连续助手消息合并成一个回答区：用户看到一次发送产生一个连贯
/// 回答，工具卡片留在回答区里（按 Part 顺序渲染）。合并只发生在视图层，
/// 不改写任何落库内容。
List<ChatMessage> visibleMessages(ConversationThread thread, ChatState state) {
  // 流式内容覆盖的是当前分支末尾那条助手消息（本次运行正在写入的行）。
  // 分支末尾是隐藏的结果消息时不覆盖：那时流式内容属于上一轮，覆盖已落库的
  // 助手消息会把它的工具卡片抹掉。
  final streaming = state.isGenerating && state.streamingParts.isNotEmpty;
  final tail = thread.branch.length - 1;
  final visible = <ChatMessage>[];
  for (var index = 0; index <= tail; index++) {
    final message = thread.branch[index];
    if (message.role == ChatRole.tool) continue;
    final live =
        streaming &&
        index == tail &&
        message.role == ChatRole.assistant &&
        message.id == state.streamingMessageId;
    visible.add(
      live
          ? message.copyWith(
              parts: state.streamingParts,
              status: MessageStatus.streaming,
            )
          : message,
    );
  }
  return _mergeAnswerRuns(visible);
}

/// 合并工具轮之前，把仅含一个公开思考块的消息总耗时归还给该块。
/// 多块且没有逐块计时的记录无法拆分，不把整轮耗时冒充任一段的时间。
ChatMessage _withRecordedThinkingDuration(ChatMessage message) {
  final duration = message.thinkingDurationMs;
  if (duration == null || message.status == MessageStatus.streaming) {
    return message;
  }
  final reasoning = message.parts
      .whereType<ReasoningPart>()
      .where((part) => part.publicText.isNotEmpty)
      .toList();
  if (reasoning.length != 1 || reasoning.single.durationMs != null) {
    return message;
  }
  final part = reasoning.single;
  return message.copyWith(
    parts: [
      for (final entry in message.parts)
        if (identical(entry, part))
          ReasoningPart(
            publicText: part.publicText,
            partId: part.partId,
            providerData: part.providerData,
            startedAt: part.startedAt,
            durationMs: duration,
          )
        else
          entry,
    ],
  );
}

/// 把同一次运行的连续助手消息合并为一个回答区。
///
/// 只看相邻两条：中间夹着用户消息（另一次运行的输入）或 runId 不同
/// （重新生成产生的新回答与旧回答）都不合并；runId 为 null 的老消息
/// 彼此相邻时按同一次运行处理。
List<ChatMessage> _mergeAnswerRuns(List<ChatMessage> messages) {
  final merged = <ChatMessage>[];
  for (final message in messages) {
    final previous = merged.isEmpty ? null : merged.last;
    if (previous != null &&
        previous.role == ChatRole.assistant &&
        message.role == ChatRole.assistant &&
        previous.runId == message.runId) {
      merged[merged.length - 1] = _mergeAnswers(previous, message);
      continue;
    }
    merged.add(message);
  }
  return merged;
}

/// 两条同一次运行的助手消息合并成一条渲染用消息。
///
/// 身份沿用首条：流式期间新增一轮不会重建气泡，阅读位置与思考面板的
/// 手动展开状态都保留。状态取最后一次终态，任一还在流式则按流式展示
/// （生成光标留在回答区末尾）；用量取最后一次有值的；思考耗时按各轮合计。
ChatMessage _mergeAnswers(ChatMessage head, ChatMessage tail) {
  head = _withRecordedThinkingDuration(head);
  tail = _withRecordedThinkingDuration(tail);
  final headThinking = head.thinkingDurationMs;
  final tailThinking = tail.thinkingDurationMs;
  return ChatMessage(
    id: head.id,
    conversationId: head.conversationId,
    parentId: head.parentId,
    runId: head.runId,
    role: head.role,
    status: head.status == MessageStatus.streaming
        ? MessageStatus.streaming
        : tail.status,
    parts: _mergeAnswerParts(head, tail),
    // 一次运行内模型不会更换：模型名取第一条有值的。
    modelLabel: head.modelLabel ?? tail.modelLabel,
    usage: tail.usage ?? head.usage,
    thinkingDurationMs: headThinking == null
        ? tailThinking
        : (tailThinking == null ? headThinking : headThinking + tailThinking),
    createdAt: head.createdAt,
  );
}

/// 拼接两条消息的内容块，保持各自的 Part 顺序。
///
/// 只在正文接正文时补一个空行：两轮正文直接相连会被渲染成一段。思考不补——
/// 每轮思考各自成区，工具调用或正文天然把它们隔开。
List<MessagePart> _mergeAnswerParts(ChatMessage head, ChatMessage tail) {
  final parts = [...head.parts];
  if (tail.parts.isNotEmpty &&
      parts.isNotEmpty &&
      parts.last is TextPart &&
      tail.parts.first is TextPart) {
    parts.add(const TextPart(text: '\n\n'));
  }
  return [...parts, ...tail.parts];
}

/// 助手列表；先确保内置助手存在再发出。
@Riverpod(keepAlive: true)
Stream<List<Assistant>> assistants(Ref ref) async* {
  if (!ref.mounted) return;
  final repository = await ref.watch(assistantRepositoryProvider.future);
  if (!ref.mounted) return;
  await repository.ensureDefault();
  if (!ref.mounted) return;
  yield* repository.watchAssistants();
}

/// 当前生效的助手。
///
/// 已打开的会话用会话绑定的助手；新会话用草稿助手；两者都没有、
/// 或绑定的助手已被删除时回退到列表第一个（内置助手）。
///
/// 只读内存中的列表与线程：调用方先 await 好这两路数据（见
/// [awaitAssistantContext]），避免把「尚未加载」误判成「没有助手」。
@Riverpod(keepAlive: true, dependencies: [assistants, conversationThread])
Assistant? currentAssistant(Ref ref, ActiveConversationState active) {
  final assistants = ref.watch(assistantsProvider).value ?? const <Assistant>[];
  final conversationId = active.conversationId;
  final bound = conversationId == null
      ? null
      : ref
            .watch(conversationThreadProvider(conversationId))
            .value
            ?.conversation
            .assistantId;
  return resolveAssistant(
    assistants,
    draftAssistantId: active.draftAssistantId,
    boundAssistantId: bound,
  );
}

/// 从助手列表里解析当前助手。
///
/// 优先级：本次会话显式选择（草稿）→ 会话绑定的助手 → 列表第一个。
/// 草稿在会话建立后继续代表「用户刚为这个会话选定的助手」，因此排在绑定的
/// 助手之前；下发到会话的绑定关系由 [ChatController.selectAssistant] 落库。
///
/// 发送（[awaitAssistantContext]）与模型选择共用这一处规则。
Assistant? resolveAssistant(
  List<Assistant> assistants, {
  String? draftAssistantId,
  String? boundAssistantId,
}) {
  if (assistants.isEmpty) return null;
  final wanted = draftAssistantId ?? boundAssistantId;
  if (wanted != null) {
    for (final assistant in assistants) {
      if (assistant.id == wanted) return assistant;
    }
  }
  return assistants.first;
}

/// 发送前的助手解析：先把列表等就绪，再按当前会话/草稿取助手。
///
/// 供 [ChatController.send] 使用；不使用 provider 的 `.value`，那样在流式
/// provider 已就绪时也可能读到 null。
Future<Assistant?> awaitAssistantContext(Ref ref) async {
  final assistants = await ref.read(assistantsProvider.future);
  if (assistants.isEmpty) return null;
  final active = ref.read(activeConversationProvider);
  var boundId = active.draftAssistantId;
  final conversationId = active.conversationId;
  if (conversationId != null) {
    final repository = await ref.read(conversationRepositoryProvider.future);
    final thread = await repository.getThread(conversationId);
    boundId = thread?.conversation.assistantId ?? boundId;
  }
  return resolveAssistant(
    assistants,
    draftAssistantId: active.draftAssistantId,
    boundAssistantId: boundId,
  );
}

/// 当前会话状态：会话 id 与新会话的助手、显式模型选择。
///
/// 单独成状态：会话选择既影响聊天控制器，也影响助手/模型解析，
/// 由它避免「选择依赖会话、会话依赖选择」的循环。
class ActiveConversationState {
  const ActiveConversationState({
    this.conversationId,
    this.draftAssistantId,
    this.draftModelSelection,
  });

  /// 当前打开的会话；null 表示新会话（尚未落库）。
  final String? conversationId;

  /// 本次会话显式选定的助手，切到其他会话时清空。
  final String? draftAssistantId;

  /// 新会话确认的模型选择；建会话时保存到 modelSelectionOverride。
  final model.ModelSelection? draftModelSelection;
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
    );
  }

  void draftModel(model.ModelSelection selection) {
    state = ActiveConversationState(
      conversationId: state.conversationId,
      draftAssistantId: state.draftAssistantId,
      draftModelSelection: selection,
    );
  }
}
