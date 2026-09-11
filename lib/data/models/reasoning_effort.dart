/// 推理等级（思考强度）。
///
/// 各协议把它映射为各自的请求字段（reasoning_effort / thinking.budget /
/// thinkingBudget 等），模型不支持推理时不下发。
enum ReasoningEffort {
  off('关'),
  low('低'),
  medium('中'),
  high('高'),
  xhigh('超高'),
  max('最高');

  const ReasoningEffort(this.label);

  /// 选择器展示文案。
  final String label;

  /// 可下发的等级（不含 off）；off 始终可选，表示关闭推理。
  static const levels = [
    ReasoningEffort.low,
    ReasoningEffort.medium,
    ReasoningEffort.high,
    ReasoningEffort.xhigh,
    ReasoningEffort.max,
  ];

  static ReasoningEffort fromName(String? name) {
    for (final effort in ReasoningEffort.values) {
      if (effort.name == name) {
        return effort;
      }
    }
    // 默认关：不在请求里夹带网关可能不认识的推理参数（曾有网关因此返回空响应）。
    return ReasoningEffort.off;
  }
}
