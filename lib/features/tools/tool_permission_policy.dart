import '../../../data/models/permission_mode.dart';
import '../../../data/models/tool_policy.dart';
import '../chat/planning/planning_tools.dart';
import 'tool.dart';

/// 宿主统一解析权限；扩展启用范围、版本和平台能力另行检查。
ToolPolicy policyForMode(PermissionMode mode, Tool tool) => switch (mode) {
  PermissionMode.plan =>
    allowedInPlan(tool) ? ToolPolicy.allow : ToolPolicy.deny,
  PermissionMode.basic => tool.defaultPolicy,
  PermissionMode.fullAccess => ToolPolicy.allow,
};

Map<String, ToolPolicy> policiesForMode(
  PermissionMode mode,
  Iterable<Tool> tools,
) => {for (final tool in tools) tool.policyKey: policyForMode(mode, tool)};
