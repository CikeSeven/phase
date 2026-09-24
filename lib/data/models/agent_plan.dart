enum PlanStatus { draft, approved, cancelled }

/// 每次编辑创建新修订；批准仅属于这一修订。
class AgentPlan {
  const AgentPlan({
    required this.id,
    required this.revision,
    required this.conversationId,
    required this.sourceRunId,
    required this.sourceMessageId,
    required this.title,
    required this.steps,
    required this.createdAt,
    this.status = PlanStatus.draft,
    this.executionRunId,
  });
  final String id;
  final int revision;
  final String conversationId;
  final String sourceRunId;
  final String sourceMessageId;
  final String title;
  final List<String> steps;
  final PlanStatus status;
  final String? executionRunId;
  final DateTime createdAt;

  String get text =>
      '$title\n${steps.indexed.map((s) => '${s.$1 + 1}. ${s.$2}').join('\n')}';
}
