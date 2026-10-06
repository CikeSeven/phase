import '../../../data/models/permission_mode.dart';
import '../../../data/models/tool_policy.dart';
import '../../../data/models/tool_permission.dart';
import '../../../data/models/tool_source.dart';
import '../chat/context/read_history_tool.dart';
import '../chat/planning/planning_tools.dart';
import '../execution/platform_tools.dart';
import '../execution/shizuku_display_tool.dart';
import '../execution/visual_tools.dart';
import '../execution/wait_for_user_tool.dart';
import '../memory/memory_tools.dart';
import '../skills/read_skill_tool.dart';
import '../web_search/web_tools.dart';
import '../workspace/install_tool.dart';
import '../workspace/prepare_skill_tool.dart';
import '../workspace/shell_tool.dart';
import '../tasks/task_tools.dart';
import 'file_tools.dart';
import 'http_tool.dart';
import 'search_tools.dart';
import 'tool.dart';

/// 目录和运行快照的默认值；调用参数、显式规则和撤权仍在派发时判定。
ToolPolicy policyForMode(PermissionMode mode, Tool tool) =>
    tool is SubmitPlanTool
    ? (mode == PermissionMode.plan ? ToolPolicy.allow : ToolPolicy.deny)
    : switch (mode) {
        PermissionMode.plan =>
          allowedInPlan(tool) ? ToolPolicy.allow : ToolPolicy.deny,
        PermissionMode.basic => tool.defaultPolicy,
        PermissionMode.fullAccess => ToolPolicy.allow,
      };

Map<String, ToolPolicy> policiesForMode(
  PermissionMode mode,
  Iterable<Tool> tools,
) => {for (final tool in tools) tool.policyKey: policyForMode(mode, tool)};

ToolPermissionRequest permissionRequestFor(
  Tool tool,
  Map<String, dynamic> arguments,
) {
  if (tool.source.kind == ToolSourceKind.mcp) {
    return ToolPermissionRequest(
      action: tool.source.originalName,
      effects: const {ToolEffect.unknown},
    );
  }
  if (tool is ScopedFileTool) {
    return permissionRequestFor(tool.local, arguments);
  }
  final action = tool is HttpRequestTool
      ? switch (arguments['method']) {
          String method => method.toUpperCase(),
          null => 'GET',
          _ => 'unknown',
        }
      : tool is ShizukuDisplayTool
      ? switch (arguments['action']) {
          String action => action,
          _ => 'unknown',
        }
      : tool.name;
  final effect = switch (tool) {
    ReadFileTool() ||
    ListFilesTool() ||
    WorkspaceSearchTool() ||
    ReadSkillTool() => ToolEffect.fileRead,
    WriteFileTool() ||
    EditFileTool() ||
    PrepareSkillTool() => ToolEffect.fileWrite,
    ShellTool() || InstallTool() => ToolEffect.codeExecution,
    TaskTool(:final action) =>
      action == TaskToolAction.stop
          ? ToolEffect.stateWrite
          : ToolEffect.informationRead,
    HttpRequestTool() ||
    WebSearchTool() ||
    WebFetchTool() => ToolEffect.networkRequest,
    SystemInfoTool() || ReadHistoryTool() => ToolEffect.informationRead,
    MemoryTool(:final write) =>
      write ? ToolEffect.stateWrite : ToolEffect.informationRead,
    SubmitPlanTool() => ToolEffect.stateWrite,
    WaitForUserTool() => ToolEffect.userHandoff,
    ApplicationTool() =>
      tool.name == 'list_apps'
          ? ToolEffect.informationRead
          : tool.name == 'inspect_ui'
          ? ToolEffect.deviceObservation
          : ToolEffect.deviceInteraction,
    VisualTool() =>
      tool.name == 'capture_screen'
          ? ToolEffect.deviceObservation
          : ToolEffect.deviceInteraction,
    ShizukuDisplayTool() =>
      action == 'capture'
          ? ToolEffect.deviceObservation
          : ToolEffect.deviceInteraction,
    _ => ToolEffect.unknown,
  };
  return ToolPermissionRequest(
    action: action,
    effects: {effect},
    approvalCategory:
        tool.policyKey == applicationOperationsPolicyKey &&
            (tool is ApplicationTool ||
                tool is VisualTool ||
                tool is ShizukuDisplayTool)
        ? applicationOperationsPolicyKey
        : null,
  );
}

ToolPermissionDecision evaluateToolPermission({
  required PermissionMode mode,
  required Tool tool,
  required Map<String, dynamic> arguments,
  required ToolPolicy snapshotPolicy,
  List<ToolPermissionRule> rules = const [],
}) {
  final request = permissionRequestFor(tool, arguments);
  ToolPermissionDecision decision(
    ToolPolicy policy,
    String reason, {
    String? ruleKey,
  }) => ToolPermissionDecision(
    policy: policy,
    request: request,
    reason: reason,
    ruleKey: ruleKey,
  );
  if (snapshotPolicy == ToolPolicy.deny ||
      tool.defaultPolicy == ToolPolicy.deny ||
      policyForMode(mode, tool) == ToolPolicy.deny) {
    return decision(ToolPolicy.deny, '当前运行范围或权限模式禁止此操作');
  }
  ToolPermissionRule? matched;
  for (final rule in rules) {
    if (rule.matches(tool.source, request) &&
        (matched == null || rule.policy.index > matched.policy.index)) {
      matched = rule;
    }
  }
  if (matched != null) {
    return decision(matched.policy, switch (matched.policy) {
      ToolPolicy.allow => '工具规则允许此操作',
      ToolPolicy.ask => '工具规则要求每次确认此操作',
      ToolPolicy.deny => '工具规则禁止此操作',
    }, ruleKey: matched.key);
  }
  final policy =
      mode == PermissionMode.basic &&
          request.effects.contains(ToolEffect.unknown)
      ? ToolPolicy.ask
      : policyForMode(mode, tool);
  return decision(policy, switch (policy) {
    ToolPolicy.allow =>
      mode == PermissionMode.fullAccess ? '全权限模式默认直接执行' : '宿主默认允许此操作',
    ToolPolicy.ask =>
      request.approvalCategory != null ? '应用操作需要批准本次或本轮范围' : '此操作需要本次确认',
    ToolPolicy.deny => '当前权限模式禁止此操作',
  });
}
