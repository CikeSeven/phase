/// 工具策略三档（design 第一部分 §5.2）。
///
/// allow 在已授权范围内直接执行，ask 需要用户确认，deny 不向模型开放。
enum ToolPolicy { allow, ask, deny }

ToolPolicy toolPolicyFromName(String? name) {
  for (final policy in ToolPolicy.values) {
    if (policy.name == name) return policy;
  }
  // 未明确配置的能力默认询问，而不是直接放行。
  return ToolPolicy.ask;
}
