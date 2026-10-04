import '../../../core/error/failure.dart';
import '../../../core/utils/id.dart';
import '../../../data/models/agent_plan.dart';
import '../../../data/models/agent_run.dart';
import '../../../data/models/api_protocol.dart';
import '../../../data/models/assistant.dart';
import '../../../data/models/command_channel.dart';
import '../../../data/models/memory_entry.dart';
import '../../../data/models/model_catalog.dart';
import '../../../data/models/model_selection.dart' as model;
import '../../../data/models/permission_mode.dart';
import '../../../data/models/profile_model.dart';
import '../../../data/models/provider_profile.dart';
import '../../../data/models/skill_installation.dart';
import '../../../data/models/workspace.dart';
import '../../../data/repositories/agent_run_repository.dart';
import '../../../data/repositories/conversation_repository.dart';
import '../../../data/repositories/plan_repository.dart';
import '../../../data/repositories/skill_repository.dart';
import '../../../data/repositories/workspace_repository.dart';
import '../chat_model_selection.dart';
import '../chat_operation.dart';
import 'chat_tool_runtime.dart';

/// 创建成功后租约交给调用者，覆盖整个驱动及其完整收尾。
class PreparedChatRun {
  const PreparedChatRun(this.run, this.workspaceLease, this.skillLease);
  final AgentRun run;
  final WorkspaceLease? workspaceLease;
  final SkillLease? skillLease;

  Future<void> close(ChatOperation operation) async {
    await operation.cleanup(
      () => workspaceLease?.close(),
      failureMessage: '会话工作区租约未能释放',
    );
    await operation.cleanup(
      () async => skillLease?.close(),
      failureMessage: 'Skill 租约未能释放',
    );
  }
}

class ChatRunPreview {
  const ChatRunPreview(this.configuration, this.catalog);
  final RunConfiguration configuration;
  final ChatToolCatalog catalog;
}

/// 新运行和空闲预览共用配置规则；预览不取得租约、不创建运行或建立扩展连接。
class ChatRunFactory {
  const ChatRunFactory({
    required this.conversations,
    required this.runs,
    required this.plans,
    required this.modelCatalog,
    required this.tools,
  });
  final ConversationRepository conversations;
  final AgentRunRepository runs;
  final PlanRepository plans;
  final ModelCatalog modelCatalog;
  final ChatToolRuntimeFactory tools;

  Future<ChatRunPreview> _configure({
    required String inputMessageId,
    required ChatModelSelection selection,
    required Assistant? assistant,
    required PermissionMode mode,
    required PermissionMode planExecutionMode,
    required WorkspaceSnapshot? workspace,
    required List<SkillSnapshot> skillSnapshots,
    AgentPlan? approvedPlan,
  }) async {
    final config = selection.profile.models
        .where((m) => m.id == selection.model)
        .firstOrNull;
    final limits = resolveContextLimits(
      presetId: selection.profile.presetId,
      modelId: selection.model,
      userContextWindow: config?.contextWindow,
      userMaxOutputTokens: config?.maxOutputTokens,
      catalog: modelCatalog,
    );
    final channels = selection.supportsTools
        ? await tools.commandSnapshots()
        : const <CommandChannelSnapshot>[];
    final catalog = await tools.catalog(
      assistantId: assistant?.id,
      inputMessageId: inputMessageId,
      memoryScope: assistant?.memoryScope ?? MemoryScope.disabled,
      mode: mode,
      supportsTools: selection.supportsTools,
      supportsImages: selection.supportsImages,
      mcpServerIds: assistant?.mcpServerIds ?? const {},
      skillSnapshots: skillSnapshots,
      workspace: workspace,
      channels: channels,
    );
    return ChatRunPreview(
      RunConfiguration(
        mode: mode,
        planExecutionMode: planExecutionMode,
        contextWindow: limits.contextWindow,
        contextWindowSource: limits.source.name,
        catalogMaxOutputTokens: limits.catalogMaxOutputTokens,
        memoryScope: assistant?.memoryScope ?? MemoryScope.disabled,
        planId: approvedPlan?.id,
        planRevision: approvedPlan?.revision,
        approvedPlan: approvedPlan?.text,
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
          temperature: config?.temperature,
          maxOutputTokens: config?.maxOutputTokens,
        ),
        systemPrompt: assistant?.systemPrompt ?? '',
        toolSnapshots: catalog.snapshots,
        skills: skillSnapshots,
        workspace: workspace,
        commandChannels: channels,
        mcpServers: catalog.mcpServers,
        executionScope: tools.settings.readExecutionScope(),
        webSearch: catalog.webSearch,
        enabledTools: catalog.enabledTools,
        toolPolicies: catalog.policies,
        supportsReasoning: selection.supportsReasoning,
        supportsImages: selection.supportsImages,
        supportsTools: selection.supportsTools,
        compatOverrides: selection.profile.compatOverrides,
      ),
      catalog,
    );
  }

  Future<PreparedChatRun> create({
    required String conversationId,
    required String inputMessageId,
    required ChatModelSelection selection,
    required Assistant? assistant,
    required PermissionMode mode,
    required PermissionMode planExecutionMode,
    required ChatOperation operation,
    AgentPlan? approvedPlan,
    void Function()? checkCurrent,
  }) async {
    if (mode == PermissionMode.plan && !selection.supportsTools) {
      throw const OperationFailure('计划模式需要支持工具调用的模型');
    }
    SkillLease? skillLease;
    WorkspaceLease? workspaceLease;
    try {
      if (selection.supportsTools &&
          (assistant?.skillIds.isNotEmpty ?? false)) {
        skillLease = await (await tools.loadSkills()).acquire(
          assistant!.skillIds,
        );
      }
      final thread = await conversations.getThread(conversationId);
      if (thread == null) throw const OperationFailure('会话已不存在');
      final workspaceId = thread.conversation.workspaceId;
      if (workspaceId != null) {
        workspaceLease = await (await tools.loadWorkspaces()).acquire(
          workspaceId,
        );
      }
      final prepared = await _configure(
        inputMessageId: inputMessageId,
        selection: selection,
        assistant: assistant,
        mode: mode,
        planExecutionMode: planExecutionMode,
        workspace: workspaceLease?.snapshot,
        skillSnapshots: skillLease?.skills ?? const [],
        approvedPlan: approvedPlan,
      );
      checkCurrent?.call();
      final candidate = AgentRun(
        id: generateId(),
        conversationId: conversationId,
        assistantId: assistant?.id,
        inputMessageId: inputMessageId,
        configuration: prepared.configuration,
        createdAt: DateTime.now(),
      );
      final run = approvedPlan == null
          ? await runs.create(candidate)
          : await plans.approveAndCreate(approvedPlan, candidate);
      return PreparedChatRun(run, workspaceLease, skillLease);
    } catch (_) {
      await operation.cleanup(
        () => workspaceLease?.close(),
        failureMessage: '会话工作区租约未能释放',
      );
      await operation.cleanup(
        () async => skillLease?.close(),
        failureMessage: 'Skill 租约未能释放',
      );
      rethrow;
    }
  }

  Future<ChatRunPreview> preview({
    required ConversationThread thread,
    required ChatModelSelection selection,
    required Assistant? assistant,
  }) async {
    final workspaceId = thread.conversation.workspaceId;
    final workspace = workspaceId == null
        ? null
        : await (await tools.loadWorkspaces()).snapshot(workspaceId);
    final installed =
        selection.supportsTools && (assistant?.skillIds.isNotEmpty ?? false)
        ? await (await tools.loadSkills()).list()
        : const <SkillInstallation>[];
    return _configure(
      inputMessageId: thread.currentMessageId!,
      selection: selection,
      assistant: assistant,
      mode: thread.conversation.permissions.mode,
      planExecutionMode: thread.conversation.permissions.lastExecutionMode,
      workspace: workspace,
      skillSnapshots: [
        for (final item in installed)
          if (item.enabled &&
              !item.deleting &&
              assistant!.skillIds.contains(item.id))
            item.snapshot,
      ],
    );
  }
}

/// 恢复只读取持久化连接、能力和模型快照，不重选当前配置。
ChatModelSelection selectionForRun(AgentRun run) {
  final config = run.configuration;
  final model = config.modelSelection;
  final protocol = ApiProtocol.values
      .where((p) => p.name == config.connection.protocol)
      .firstOrNull;
  if (protocol == null) throw const OperationFailure('运行的协议配置无效');
  return ChatModelSelection(
    profile: ProviderProfile(
      id: config.connection.profileId,
      name: '运行配置',
      protocol: protocol,
      baseUrl: config.connection.baseUrl,
      requiresKey: config.connection.requiresKey,
      compatOverrides: config.compatOverrides,
      createdAt: run.createdAt,
      models: [
        ProfileModel(
          id: model.modelId,
          supportsReasoning: config.supportsReasoning,
          supportsImages: config.supportsImages,
          supportsTools: config.supportsTools,
          temperature: model.temperature,
          maxOutputTokens: model.maxOutputTokens,
          contextWindow: config.contextWindow,
        ),
      ],
    ),
    model: model.modelId,
    supportsReasoning: config.supportsReasoning,
    supportsImages: config.supportsImages,
    supportsTools: config.supportsTools,
    effort: model.reasoningEffort,
  );
}
