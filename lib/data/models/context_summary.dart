import 'chat_message.dart';

enum SummaryStatus { running, completed, failed, cancelled }

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
    this.version = 1,
    this.status = SummaryStatus.running,
    this.text = '',
    this.usage,
  });
  final String id;
  final String conversationId;
  final String runId;
  final String branchEndId;
  final List<String> coveredMessageIds;
  final String fingerprint;
  final String sourceModel;
  final int version;
  final SummaryStatus status;
  final String text;
  final TokenUsage? usage;
  final DateTime createdAt;

  ContextSummary finish(SummaryStatus status, String text, TokenUsage? usage) =>
      ContextSummary(
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
      );
}
