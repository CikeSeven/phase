import '../../../data/models/permission_mode.dart';
import '../../../data/models/agent_run.dart';
import '../../../data/models/chat_request.dart';
import '../../../data/models/chat_message.dart';
import '../../../data/models/message_part.dart';
import '../../../data/models/provider_profile.dart';
import '../../../data/models/tool_policy.dart';
import '../../../data/models/tool_source.dart';
import '../../execution/platform_tools.dart';
import '../../skills/read_skill_tool.dart';
import '../../workspace/workspace_files.dart';
import '../planning/planning_tools.dart';

String contextSystemPrompt(RunConfiguration config) {
  final custom = config.systemPrompt.trim();
  if (custom.isNotEmpty) return custom;
  return '相月（Phase）是一个多模型聊天与设备执行助手。回答保持简明扼要。';
}

/// 动态状态分区独立发布；字面文本随消息落库，重开会话不重写旧提示词。
List<RuntimeContextPart> contextRuntimeParts(RunConfiguration config) {
  final skills = [...config.skills]..sort((a, b) => a.id.compareTo(b.id));
  RuntimeContextPart section(String name, String text) => RuntimeContextPart(
    section: name,
    text:
        '<phase_runtime_context section="$name">\n$text\n</phase_runtime_context>',
  );
  return [
    section('tools', toolUsagePrompt(config)),
    section('permissions', switch (config.mode) {
      PermissionMode.plan => planModePrompt,
      PermissionMode.basic => '当前为基础模式：写入、编辑、命令及敏感操作默认需用户确认。',
      PermissionMode.fullAccess => '当前为全权限模式：已开放工具默认直接执行。',
    }),
    section(
      'environment',
      '${config.workspace == null ? '当前没有会话工作区。' : workspacePrompt(config.workspace)}'
          '${config.enabledTools.contains('shizuku_display') ? '\n已启用 Shizuku 虚拟屏控制。' : '\n未开放 Shizuku 虚拟屏控制。'}'
          '${executionScopePrompt(config.executionScope, toolExecution: config.enabledTools.isNotEmpty, applicationOperations: config.enabledTools.any(applicationOperationTools.contains))}',
    ),
    section(
      'skills',
      skills.isEmpty
          ? '当前未启用任何 Skill。'
          : skillDiscoveryPrompt(
              skills,
              linuxAvailable: config.workspace?.executable == true,
            ),
    ),
  ];
}

String toolUsagePrompt(RunConfiguration config) {
  final tools = [
    for (final tool in config.toolSnapshots)
      if (config.enabledTools.contains(tool.name)) tool,
  ]..sort((a, b) => a.name.compareTo(b.name));
  final snippets = [
    for (final tool in tools)
      if (tool.promptSnippet case final snippet?) '- ${tool.name}: $snippet',
  ];
  final guidelines = {for (final tool in tools) ...tool.promptGuidelines};
  return [
    '可用工具：',
    ...snippets,
    if (guidelines.isNotEmpty) '\n使用规则：',
    for (final guideline in guidelines) '- $guideline',
  ].join('\n');
}

/// 空闲预览只投影尚未发送的状态；真正请求前才在分支末尾持久化。
List<ResolvedMessage> previewRuntimeContext(
  List<ResolvedMessage> messages,
  List<ChatMessage> history,
  RunConfiguration configuration,
) {
  final changed = RuntimeContextPart.changes(
    history.where((m) => m.role == ChatRole.system).expand((m) => m.parts),
    contextRuntimeParts(configuration),
  );
  return [
    ...messages,
    if (changed.isNotEmpty)
      ResolvedMessage(
        role: ChatRole.system,
        runtimeContextSections: {for (final part in changed) part.section},
        parts: [for (final part in changed) ResolvedText(part.text)],
      ),
  ];
}

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
  ToolPolicy get defaultPolicy => snapshot.source.kind == ToolSourceKind.mcp
      ? ToolPolicy.ask
      : ToolPolicy.allow;
  @override
  String describeAction(Map<String, dynamic> arguments) => name;
}
