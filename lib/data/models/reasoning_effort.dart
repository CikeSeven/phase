/// 推理等级（思考强度）。
///
/// 各协议把它映射为各自的请求字段（reasoning_effort / thinking.budget /
/// thinkingBudget 等），模型不支持推理时不下发。
enum ReasoningEffort {
  off('关'),
  low('低'),
  medium('中'),
  high('高');

  const ReasoningEffort(this.label);

  /// 选择器展示文案。
  final String label;

  static ReasoningEffort fromName(String? name) {
    for (final effort in ReasoningEffort.values) {
      if (effort.name == name) {
        return effort;
      }
    }
    return ReasoningEffort.medium;
  }
}
