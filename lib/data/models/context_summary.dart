import 'token_usage.dart';

enum SummaryStatus { running, completed, failed, cancelled }

enum SummaryAdoption { pending, applied, noGain, tooLarge, stale }

class ContextSummary {
  const ContextSummary({
    required this.id,
    required this.conversationId,
    required this.runId,
    required this.branchEndId,
    required this.coveredMessageIds,
    required this.fingerprint,
    required this.sourceModel,
    required this.createdAt,
    this.version = 2,
    this.status = SummaryStatus.running,
    this.text = '',
    this.usage,
    this.parentSummaryId,
    this.jobId,
    this.firstKeptMessageId,
    this.sourceGeneration = 'original',
    this.resultingGeneration,
    this.adoption = SummaryAdoption.pending,
    this.beforeTokens,
    this.afterTokens,
    this.targetTokens,
    this.reason,
  });
  final String id;
  final String conversationId;
  final String? runId;
  final String branchEndId;

  /// 仅本阶段新增覆盖；累计覆盖由父检查点链求得。
  final List<String> coveredMessageIds;
  final String fingerprint;
  final String sourceModel;
  final int version;
  final SummaryStatus status;
  final String text;

  /// 来自请求表的只读投影。
  final TokenUsage? usage;
  final DateTime createdAt;
  final String? parentSummaryId;
  final String? jobId;
  String get summaryJobId => jobId ?? id;
  final String? firstKeptMessageId;
  final String sourceGeneration;
  final String? resultingGeneration;
  final SummaryAdoption adoption;
  final int? beforeTokens;
  final int? afterTokens;
  final int? targetTokens;
  final String? reason;

  ContextSummary finish(
    SummaryStatus status,
    String text, {
    SummaryAdoption? adoption,
    int? afterTokens,
    String? reason,
  }) => ContextSummary(
    id: id,
    conversationId: conversationId,
    runId: runId,
    branchEndId: branchEndId,
    coveredMessageIds: coveredMessageIds,
    fingerprint: fingerprint,
    sourceModel: sourceModel,
    createdAt: createdAt,
    version: version,
    status: status,
    text: text,
    usage: usage,
    parentSummaryId: parentSummaryId,
    jobId: jobId,
    firstKeptMessageId: firstKeptMessageId,
    sourceGeneration: sourceGeneration,
    resultingGeneration: adoption == SummaryAdoption.applied
        ? id
        : resultingGeneration,
    adoption: adoption ?? this.adoption,
    beforeTokens: beforeTokens,
    afterTokens: afterTokens ?? this.afterTokens,
    targetTokens: targetTokens,
    reason: reason ?? this.reason,
  );

  Map<String, dynamic> get checkpoint => {
    'parentSummaryId': parentSummaryId,
    'summaryJobId': summaryJobId,
    'firstKeptMessageId': firstKeptMessageId,
    'sourceGeneration': sourceGeneration,
    'resultingGeneration': resultingGeneration,
    'adoption': adoption.name,
    'beforeTokens': beforeTokens,
    'afterTokens': afterTokens,
    'targetTokens': targetTokens,
    'reason': reason,
  };
}
