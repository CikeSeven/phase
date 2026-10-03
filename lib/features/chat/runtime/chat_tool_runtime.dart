import 'dart:async';

import '../../../data/datasources/local/settings_storage.dart';
import '../../../data/models/agent_run.dart';
import '../../../data/models/command_channel.dart';
import '../../../data/models/mcp_server_profile.dart';
import '../../../data/models/memory_entry.dart';
import '../../../data/models/permission_mode.dart';
import '../../../data/models/skill_installation.dart';
import '../../../data/models/tool_call_record.dart';
import '../../../data/models/tool_policy.dart';
import '../../../data/models/tool_source.dart';
import '../../../data/models/workspace.dart';
import '../../../data/repositories/agent_run_repository.dart';
import '../../../data/repositories/assistant_repository.dart';
import '../../../data/repositories/conversation_repository.dart';
import '../../../data/repositories/mcp_server_repository.dart';
import '../../../data/repositories/memory_repository.dart';
import '../../../data/repositories/plan_repository.dart';
import '../../../data/repositories/skill_repository.dart';
import '../../../data/repositories/tool_call_repository.dart';
import '../../../data/repositories/workspace_repository.dart';
import '../context/context_configuration.dart';
import '../context/read_history_tool.dart';
import '../chat_operation.dart';
import '../planning/planning_tools.dart';
import '../../commands/command_channel_driver.dart';
import '../../commands/system_channel_tools.dart';
import '../../execution/channel_driver.dart';
import '../../execution/execution_controller.dart';
import '../../execution/execution_api.g.dart';
import '../../execution/shizuku_display_tool.dart';
import '../../execution/task_activity.dart';
import '../../execution/wait_for_user_tool.dart';
import '../../mcp/mcp_connections.dart';
import '../../mcp/mcp_runtime.dart';
import '../../memory/memory_tools.dart';
import '../../skills/read_skill_tool.dart';
import '../../tools/tool.dart';
import '../../tools/tool_executor.dart';
import '../../tools/tool_permission_policy.dart';
import '../../tools/tool_presentation.dart';
import '../../workspace/install_tool.dart';
import '../../workspace/prepare_skill_tool.dart';
import '../../workspace/process_driver.dart';
import '../../workspace/shell_tool.dart';
import '../../workspace/workspace_files.dart';
import '../../workspace/workspace_transfer_tool.dart';
import '../../../data/models/chat_request.dart';

const _environmentTools = {'shell', 'install_packages'};

bool workspaceToolAvailable(String name, WorkspaceSnapshot? workspace) =>
    name == 'install_packages'
    ? workspace?.primaryEnvironment == PrimaryEnvironment.ubuntu &&
          workspace?.linuxAvailable == true
    : workspace?.executable == true;

String toolActivity(Tool tool, Map<String, dynamic> arguments) =>
    isCommandToolName(tool.name)
    ? '\$ ${panelExcerpt(arguments['command'] as String? ?? '', limit: 300)}'
    : panelExcerpt(tool.describeAction(arguments), limit: 300);

/// 目录只描述可见定义，不建立 MCP 会话或启动执行宿主。
class ChatToolCatalog {
  const ChatToolCatalog({
    required this.registry,
    required this.snapshots,
    required this.enabledTools,
    required this.policies,
    required this.mcpServers,
  });
  final ToolRegistry registry;
  final List<ToolSnapshot> snapshots;
  final Set<String> enabledTools;
  final Map<String, ToolPolicy> policies;
  final List<McpServerProfile> mcpServers;

  List<ToolDefinition> get definitions => [
    ...registry.definitionsFor(enabledTools, policies, includeDenied: true),
    for (final snapshot in snapshots)
      if (snapshot.source.kind == ToolSourceKind.mcp)
        SnapshotToolDefinition(snapshot),
  ]..sort((a, b) => a.name.compareTo(b.name));
}

/// 配置与运行复用同一目录规则；执行资源仍按每次驱动独立创建。
class ChatToolRuntimeFactory {
  const ChatToolRuntimeFactory({
    required this.builtIns,
    required this.conversations,
    required this.runs,
    required this.calls,
    required this.assistants,
    required this.plans,
    required this.memories,
    required this.loadWorkspaces,
    required this.loadSkills,
    required this.loadMcpServers,
    required this.settings,
    required this.platform,
    required this.commands,
    required this.processes,
    required this.connections,
    required this.commandSnapshots,
  });
  final ToolRegistry builtIns;
  final ConversationRepository conversations;
  final AgentRunRepository runs;
  final ToolCallRepository calls;
  final AssistantRepository assistants;
  final PlanRepository plans;
  final MemoryRepository memories;
  final Future<WorkspaceRepository> Function() loadWorkspaces;
  final Future<SkillRepository> Function() loadSkills;
  final Future<McpServerRepository> Function() loadMcpServers;
  final SettingsStorage settings;
  final ChannelDriver Function() platform;
  final CommandChannelDriver Function() commands;
  final ProcessDriver Function() processes;
  final McpConnections Function() connections;
  final Future<List<CommandChannelSnapshot>> Function() commandSnapshots;

  List<Tool> _agentTools({
    required String? assistantId,
    required MemoryScope scope,
    required String inputMessageId,
  }) => [
    ReadHistoryTool(conversations, calls),
    SubmitPlanTool(plans),
    if (scope != MemoryScope.disabled)
      for (final write in [false, true])
        MemoryTool(
          repository: memories,
          assistants: assistants,
          assistantId: assistantId,
          scope: scope,
          sourceMessageId: inputMessageId,
          write: write,
        ),
  ];

  Future<ReadSkillTool?> _skillTool(
    List<SkillSnapshot> snapshots,
    String? assistantId,
    WorkspaceSnapshot? workspace,
  ) async {
    if (snapshots.isEmpty) return null;
    return ReadSkillTool(
      skills: snapshots,
      repository: await loadSkills(),
      assistants: assistants,
      assistantId: assistantId,
      linuxAvailable: workspace?.executable == true,
    );
  }

  List<Tool> _channelTools(
    List<CommandChannelSnapshot> channels,
    WorkspaceSnapshot? workspace,
    WorkspaceRepository? workspaces,
  ) => [
    if (workspace?.termux != null)
      WorkspaceTransferTool(workspace!, WorkspaceFiles(workspaces!)),
    for (final channel in channels) ...[
      if (channel.channel == ExecutionChannel.shizuku)
        ShizukuDisplayTool(channel, platform),
      if (channel.channel == ExecutionChannel.termux && workspace != null)
        ChannelTransferTool(channel, commands(), workspace, workspaces!),
    ],
  ];

  Future<ChatToolCatalog> catalog({
    required String? assistantId,
    required String inputMessageId,
    required MemoryScope memoryScope,
    required PermissionMode mode,
    required bool supportsTools,
    required bool supportsImages,
    required Set<String> mcpServerIds,
    required List<SkillSnapshot> skillSnapshots,
    required WorkspaceSnapshot? workspace,
    required List<CommandChannelSnapshot> channels,
  }) async {
    final workspaces = workspace == null ? null : await loadWorkspaces();
    final skill = supportsTools
        ? await _skillTool(skillSnapshots, assistantId, workspace)
        : null;
    final registry = ToolRegistry([
      if (supportsTools)
        ..._agentTools(
          assistantId: assistantId,
          scope: memoryScope,
          inputMessageId: inputMessageId,
        ),
      if (supportsTools) ..._channelTools(channels, workspace, workspaces),
      for (final tool in builtIns.tools)
        if (tool is ShellTool) ShellTool(workspace: workspace) else tool,
      ?skill,
      if (skill != null && workspace?.executable == true)
        PrepareSkillTool(skill, workspace!, WorkspaceFiles(workspaces!)),
    ]);
    final enabled = supportsTools
        ? {for (final tool in registry.tools) tool.name}
        : <String>{};
    enabled.removeWhere(
      (name) =>
          (_environmentTools.contains(name) &&
              !workspaceToolAvailable(name, workspace)) ||
          (!supportsImages &&
              const {'capture_screen', 'shizuku_display'}.contains(name)),
    );
    final entries = supportsTools && mcpServerIds.isNotEmpty
        ? await (await loadMcpServers()).list()
        : const <McpServerEntry>[];
    final snapshots = <ToolSnapshot>[
      for (final tool in registry.tools)
        if (enabled.contains(tool.name)) tool.snapshot,
      for (final entry in entries)
        if (mcpServerIds.contains(entry.profile.id) &&
            entry.profile.enabled &&
            !entry.profile.deleting)
          ...entry.tools,
    ];
    final fixedEnabled = {for (final snapshot in snapshots) snapshot.name};
    return ChatToolCatalog(
      registry: registry,
      snapshots: snapshots,
      enabledTools: fixedEnabled,
      policies: supportsTools
          ? {
              ...policiesForMode(mode, registry.tools),
              for (final snapshot in snapshots)
                if (snapshot.source.kind == ToolSourceKind.mcp)
                  snapshot.name: mode == PermissionMode.plan
                      ? ToolPolicy.deny
                      : ToolPolicy.allow,
            }
          : const {},
      mcpServers: [
        for (final entry in entries)
          if (snapshots.any(
            (tool) =>
                tool.source.kind == ToolSourceKind.mcp &&
                tool.source.id == entry.profile.id,
          ))
            entry.profile,
      ],
    );
  }

  Future<ChatToolRuntime> create({
    required AgentRun run,
    required ExecutionController execution,
    required RunCancellation cancellation,
    required Future<ToolDecision> Function(ToolConfirmationRequest) confirm,
    required Future<void> Function(ToolContext, String, RunCancellation)
    waitForUser,
  }) async {
    final config = run.configuration;
    final mcp = config.mcpServers.isEmpty
        ? null
        : McpRunRuntime(
            run: run,
            repository: await loadMcpServers(),
            assistants: assistants,
            connections: connections(),
          );
    final binding = config.workspace;
    final workspaces = binding == null ? null : await loadWorkspaces();
    final files = workspaces == null ? null : WorkspaceFiles(workspaces);
    final skill = await _skillTool(config.skills, run.assistantId, binding);
    final commandDriver =
        config.commandChannels.isEmpty && binding?.termux == null
        ? null
        : commands();
    if (commandDriver != null) {
      await commandDriver.setEnabled(settings.readCommandChannels().channels);
    }
    final processDriver = binding?.executable != true && commandDriver == null
        ? null
        : processes();
    final registry = ToolRegistry([
      if (config.supportsTools)
        ..._agentTools(
          assistantId: run.assistantId,
          scope: config.memoryScope,
          inputMessageId: run.inputMessageId,
        ),
      ..._channelTools(config.commandChannels, binding, workspaces),
      for (final tool in builtIns.tools)
        if (!_environmentTools.contains(tool.name))
          if (tool is WaitForUserTool) WaitForUserTool(waitForUser) else tool,
      if (binding?.executable == true)
        ShellTool(
          workspace: binding,
          driver: processDriver,
          files: files,
          commandDriver: commandDriver,
        ),
      if (binding?.primaryEnvironment == PrimaryEnvironment.ubuntu &&
          binding?.linuxAvailable == true)
        InstallTool(
          workspace: binding,
          repository: workspaces,
          driver: processDriver,
        ),
      if (binding?.executable == true && skill != null)
        PrepareSkillTool(skill, binding!, files!),
      ...?mcp?.tools(),
      ?skill,
    ]);
    final executor = ToolExecutor(
      registry: registry,
      toolCalls: calls,
      runs: runs,
      onConfirmationRequired: confirm,
      onExecuting: (tool, arguments, callId) {
        if (cancellation.isCancelled) return;
        execution.updateActivity(
          run.id,
          execution.activity
              .copyWith(
                phase: TaskPanelPhase.executingTool,
                status: '正在${ToolPresentation.toolLabel(tool.name)}',
              )
              .upsert(
                TaskMessage(
                  id: 'tool/$callId',
                  kind: TaskPanelMessageKind.tool,
                  label: '正在${ToolPresentation.toolLabel(tool.name)}',
                  text: toolActivity(tool, arguments),
                ),
              ),
        );
      },
      currentPolicy: (tool) async {
        if ((tool is SystemChannelTool || tool is ShizukuDisplayTool) &&
            !settings.readCommandChannels().enabled(tool.channel)) {
          return ToolPolicy.deny;
        }
        if (config.mode == PermissionMode.plan && !allowedInPlan(tool)) {
          return ToolPolicy.deny;
        }
        if (tool is MemoryTool &&
            await tool.currentPolicy() == ToolPolicy.deny) {
          return ToolPolicy.deny;
        }
        if (tool is ReadSkillTool &&
            await tool.currentPolicy() == ToolPolicy.deny) {
          return ToolPolicy.deny;
        }
        if (tool is PrepareSkillTool &&
            await tool.currentPolicy() == ToolPolicy.deny) {
          return ToolPolicy.deny;
        }
        if (tool.source.kind != ToolSourceKind.mcp) {
          return policyForMode(config.mode, tool);
        }
        await mcp!.checkAvailable(tool.snapshot);
        return mcp.currentPolicy(tool.snapshot);
      },
      prepareChannel: (tool, arguments) async {
        execution.updateActivity(
          run.id,
          execution.activity.copyWith(
            phase: TaskPanelPhase.preparingTool,
            status: '准备${ToolPresentation.toolLabel(tool.name)}',
          ),
        );
        if (tool is ShellTool ||
            tool is SystemChannelTool ||
            tool is ShizukuDisplayTool) {
          await processDriver!.beginTask(
            run.id,
            tool is ShizukuDisplayTool
                ? '虚拟屏控制'
                : tool is ShellTool
                ? '工作区命令'
                : '系统命令',
          );
          if (tool is! ShizukuDisplayTool) {
            await execution.showAvailablePanel(run.id);
          }
        }
        if (tool.usesPlatform(arguments)) {
          await execution.ensureDeviceHost(
            run.id,
            deviceTask: tool.channel == ExecutionChannel.accessibility,
          );
        }
      },
    );
    return ChatToolRuntime(
      run,
      registry,
      executor,
      mcp,
      commandDriver,
      processDriver,
      workspaces,
    );
  }
}

/// 每次驱动独立持有连接、停止监听及执行器；批准不会跨驱动继承。
class ChatToolRuntime {
  ChatToolRuntime(
    this.run,
    this.registry,
    this.executor,
    this.mcp,
    this.commandDriver,
    this.processDriver,
    this.workspaces,
  );
  final AgentRun run;
  final ToolRegistry registry;
  final ToolExecutor executor;
  final McpRunRuntime? mcp;
  final CommandChannelDriver? commandDriver;
  final ProcessDriver? processDriver;
  final WorkspaceRepository? workspaces;
  StreamSubscription<String>? _commandStops;
  StreamSubscription<String>? _processStops;

  List<ToolDefinition> get definitions => run.configuration.supportsTools
      ? registry.definitionsFor(
          run.configuration.enabledTools,
          run.configuration.toolPolicies,
          includeDenied: true,
        )
      : const [];

  void listenStops(void Function() stop) {
    _commandStops = commandDriver?.stops.listen((owner) {
      if (owner == run.id) stop();
    });
    _processStops = processDriver?.stops.listen((owner) {
      if (owner == run.id) stop();
    });
  }

  ExecutionChannel channelFor(String name, Map<String, dynamic> arguments) {
    if (run.configuration.workspace?.primaryEnvironment ==
            PrimaryEnvironment.termux &&
        const {
          'read_file',
          'list_files',
          'write_file',
          'edit_file',
          'prepare_skill',
          'workspace_transfer',
        }.contains(name) &&
        !(arguments['path'] is String &&
            (arguments['path'] as String).startsWith('content://')) &&
        !arguments.containsKey('directory') &&
        !(arguments['path'] is String &&
            (arguments['path'] as String).startsWith('attachment:'))) {
      return ExecutionChannel.termux;
    }
    return registry.byName(name)?.channel ?? ExecutionChannel.app;
  }

  Future<void> close(ChatOperation operation) async {
    await operation.cleanup(
      () async => mcp?.close(),
      failureMessage: 'MCP 连接未能完整关闭',
    );
    await operation.cleanup(
      () async => commandDriver?.endOwner(run.id),
      failureMessage: '系统命令任务未收到完整结束回执',
    );
    await operation.cleanup(
      () async => _commandStops?.cancel(),
      failureMessage: '系统命令停止监听未能释放',
    );
    await operation.cleanup(
      () async => processDriver?.endTask(run.id),
      failureMessage: 'Linux 任务服务未确认结束',
    );
    await operation.cleanup(
      () async => _processStops?.cancel(),
      failureMessage: 'Linux 停止监听未能释放',
    );
    _commandStops = null;
    _processStops = null;
  }
}
