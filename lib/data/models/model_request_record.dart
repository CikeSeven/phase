import 'token_usage.dart';

enum ModelRequestPurpose { chat, contextSummary, turnPrefixSummary }

enum ModelRequestStatus {
  prepared,
  running,
  completed,
  failed,
  cancelled,
  interrupted,
}

class ModelRequestRecord {
  const ModelRequestRecord({
    required this.id,
    required this.conversationId,
    required this.profileId,
    required this.protocol,
    required this.requestedModelId,
    required this.createdAt,
    this.runId,
    this.logicalTurn = 0,
    this.attemptIndex = 1,
    this.purpose = ModelRequestPurpose.chat,
    this.status = ModelRequestStatus.prepared,
    this.assistantMessageId,
    this.summaryId,
    this.summaryJobId,
    this.responseModelId,
    this.usage,
    this.usageRevision = 0,
    this.usageComplete = false,
    this.contextSnapshot = const {},
    this.originRequestId,
    this.isInherited = false,
    this.startedAt,
    this.finishedAt,
    this.errorCode,
  });
  final String id;
  final String conversationId;
  final String? runId;
  final int logicalTurn;
  final int attemptIndex;
  final ModelRequestPurpose purpose;
  final ModelRequestStatus status;
  final String profileId;
  final String protocol;
  final String requestedModelId;
  final String? responseModelId;
  final String? assistantMessageId;
  final String? summaryId;
  final String? summaryJobId;
  final TokenUsage? usage;
  final int usageRevision;
  final bool usageComplete;

  /// 只保存估算、指纹与覆盖 ID；不复制正文或连接凭据。
  final Map<String, dynamic> contextSnapshot;
  final String? originRequestId;
  final bool isInherited;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final String? errorCode;
  bool get isActual => !isInherited && startedAt != null;
  bool get isPending =>
      status == ModelRequestStatus.running ||
      status == ModelRequestStatus.prepared;
}

class UsageMetricTotal {
  const UsageMetricTotal(this.tokens, this.knownRequests, this.requestCount);
  final int tokens;
  final int knownRequests;
  final int requestCount;
  int get unknownRequests => requestCount - knownRequests;
}

/// 对稳定请求 ID 的最新快照求和，不对 usage 事件求和。
class RequestUsageTotals {
  RequestUsageTotals(Iterable<ModelRequestRecord> source)
    : requests = {
        for (final r in source)
          if (r.isActual) r.id: r,
      }.values.toList();
  final List<ModelRequestRecord> requests;
  int get requestCount => requests.length;
  bool get includesPending => requests.any((r) => r.isPending);
  UsageMetricTotal metric(UsageField field) {
    final values = requests.map((r) => r.usage?.value(field)).nonNulls;
    return UsageMetricTotal(
      values.fold(0, (a, b) => a + b),
      values.length,
      requestCount,
    );
  }

  List<ModelRequestRecord> get cacheRequests => requests
      .where(
        (r) =>
            r.usage?.value(UsageField.promptTokens) != null &&
            r.usage?.value(UsageField.cacheReadTokens) != null,
      )
      .toList();
  double? get cacheHitRate {
    final paired = cacheRequests;
    final input = paired.fold(0, (n, r) => n + r.usage!.promptTokens!);
    if (input == 0) return null;
    return paired.fold(0, (n, r) => n + r.usage!.cacheReadTokens!) / input;
  }

  bool get completeCacheCoverage =>
      requestCount > 0 &&
      !includesPending &&
      cacheRequests.length == requestCount;
}
