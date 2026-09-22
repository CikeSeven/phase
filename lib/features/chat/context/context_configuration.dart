import '../../../data/models/agent_plan.dart';
import '../../../data/models/agent_run.dart';
import '../../../data/models/chat_request.dart';
import '../../../data/models/provider_profile.dart';
import '../../../data/models/tool_policy.dart';
import '../../../data/models/tool_source.dart';
import '../../execution/platform_tools.dart';
import '../../skills/read_skill_tool.dart';
import '../../workspace/workspace_files.dart';
import '../planning/planning_tools.dart';

String contextSystemPrompt(RunConfiguration config) =>
    '${config.systemPrompt}'
    '${skillDiscoveryPrompt(config.skills, linuxAvailable: config.workspace?.linuxAvailable == true)}'
    '${workspacePrompt(config.workspace)}'
    '${executionScopePrompt(config.executionScope, toolExecution: config.enabledTools.isNotEmpty, applicationOperations: config.enabledTools.any(applicationOperationTools.contains))}'
    '${config.mode == AgentMode.plan ? planModePrompt : ''}';

/// 手动整理/空闲测量的独立配置，不伪造 AgentRun。
class PreparedContext {
  const PreparedContext({
    required this.conversationId,
    required this.branchHeadId,
    required this.profile,
    required this.configuration,
    required this.request,
    required this.protectedIds,
    required this.reloadMessages,
    this.assistantId,
  });
  final String conversationId;
  final String branchHeadId;
  final ProviderProfile profile;
  final RunConfiguration configuration;
  final ChatRequest request;
  final Set<String> protectedIds;
  final Future<List<ResolvedMessage>> Function() reloadMessages;
  final String? assistantId;
  bool get canReadHistory => request.tools.any((t) => t.name == 'read_history');
}

/// 只用于规划负载，不能执行；运行仍由 ToolRegistry 注册真实工具。
class SnapshotToolDefinition implements ToolDefinition {
  const SnapshotToolDefinition(this.snapshot);
  final ToolSnapshot snapshot;
  @override
  String get name => snapshot.name;
  @override
  String get description => snapshot.description;
  @override
  Map<String, dynamic> get inputSchema => snapshot.inputSchema;
  @override
  Set<String> get requiredCapabilities => const {};
  @override
  ToolPolicy get defaultPolicy => ToolPolicy.ask;
  @override
  String describeAction(Map<String, dynamic> arguments) => name;
}
