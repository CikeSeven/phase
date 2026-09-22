import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failure.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../../data/models/model_request_record.dart';
import '../../../data/models/token_usage.dart';
import '../../../data/repositories/model_request_repository.dart';

String formatTokenCount(int value) => value >= 1000000
    ? '${(value / 1000000).toStringAsFixed(1)}M'
    : value >= 1000
    ? '${(value / 1000).toStringAsFixed(1)}k'
    : '$value';

String cacheRateLabel(double? rate) => rate == null
    ? '不适用'
    : '${(math.min(1000, (rate * 1000).floor()) / 10).toStringAsFixed(1)}%';

String usageFieldLabel(UsageField field) => switch (field) {
  UsageField.promptTokens => '输入总量',
  UsageField.uncachedInputTokens => '普通输入',
  UsageField.cacheReadTokens => '缓存读取',
  UsageField.cacheWriteTokens => '缓存写入',
  UsageField.outputTokens => '输出（含推理）',
  UsageField.reasoningTokens => '推理子项',
  UsageField.totalTokens => '总消耗',
};

String requestPurposeLabel(ModelRequestPurpose purpose) => switch (purpose) {
  ModelRequestPurpose.chat => '主聊天',
  ModelRequestPurpose.contextSummary => '历史摘要',
  ModelRequestPurpose.turnPrefixSummary => '任务前缀摘要',
};

String requestStatusLabel(ModelRequestStatus status) => switch (status) {
  ModelRequestStatus.prepared => '准备中（未请求）',
  ModelRequestStatus.running => '进行中',
  ModelRequestStatus.completed => '完成',
  ModelRequestStatus.failed => '失败',
  ModelRequestStatus.cancelled => '已停止',
  ModelRequestStatus.interrupted => '已中断',
};

class UsagePanel extends ConsumerStatefulWidget {
  const UsagePanel({required this.conversationId, this.runId, super.key});
  final String conversationId;
  final String? runId;
  @override
  ConsumerState<UsagePanel> createState() => _UsagePanelState();
}

class _UsagePanelState extends ConsumerState<UsagePanel> {
  bool _session = false;
  @override
  Widget build(BuildContext context) {
    final records = ref.watch(
      conversationRequestsProvider(widget.conversationId),
    );
    return records.when(
      loading: () => const AppLoadingIndicator(),
      error: (e, _) => Text(e is Failure ? e.userMessage : '读取用量失败'),
      data: (all) {
        final runId =
            widget.runId ??
            all.where((r) => r.isActual && r.runId != null).firstOrNull?.runId;
        final session = _session || runId == null;
        final visible = session
            ? all
            : all.where((r) => r.runId == runId).toList();
        final totals = RequestUsageTotals(visible);
        final summaryCount = totals.requests
            .where((r) => r.purpose != ModelRequestPurpose.chat)
            .length;
        final cacheCount = totals.cacheRequests.length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: Text(widget.runId == null ? '本次运行' : '所属运行'),
                  selected: !session,
                  onSelected: runId == null
                      ? null
                      : (_) => setState(() => _session = false),
                ),
                ChoiceChip(
                  label: const Text('整个会话'),
                  selected: session,
                  onSelected: (_) => setState(() => _session = true),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('已报告用量 · ${totals.requestCount} 次实际请求（摘要 $summaryCount 次）'),
            const Text('仅统计有请求记录的已报告用量；升级前档案与继承记录不计入。不代表当前窗口占用或账单金额。'),
            if (totals.includesPending) const Text('包含进行中请求，统计尚未收口'),
            if (totals.requestCount == 0)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('此范围尚无请求计量记录'),
              ),
            for (final field in UsageField.values)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Builder(
                  builder: (context) {
                    final metric = totals.metric(field);
                    return Text(
                      '${usageFieldLabel(field)}：${metric.knownRequests == 0 ? '未提供' : metric.tokens}'
                      '${metric.unknownRequests == 0 ? '' : ' · ${metric.unknownRequests} 次请求未提供'}',
                    );
                  },
                ),
              ),
            const SizedBox(height: 8),
            Text(
              cacheCount == 0
                  ? '缓存命中率：未提供'
                  : '${totals.completeCacheCoverage ? '缓存命中率' : '已报告请求命中率'}：${cacheRateLabel(totals.cacheHitRate)} · 覆盖 $cacheCount/${totals.requestCount} 次',
            ),
            const SizedBox(height: 12),
            for (final purpose in [
              ModelRequestPurpose.chat,
              ModelRequestPurpose.contextSummary,
              ModelRequestPurpose.turnPrefixSummary,
            ])
              if (totals.requests.any((r) => r.purpose == purpose))
                Text(
                  '${requestPurposeLabel(purpose)}：${totals.requests.where((r) => r.purpose == purpose).length} 次请求',
                ),
            const SizedBox(height: 12),
            for (final record in visible) RequestUsageTile(record: record),
          ],
        );
      },
    );
  }
}

class RequestUsageTile extends StatelessWidget {
  const RequestUsageTile({required this.record, super.key});
  final ModelRequestRecord record;
  @override
  Widget build(BuildContext context) => ExpansionTile(
    key: PageStorageKey('request-${record.id}'),
    title: Text(
      '${requestPurposeLabel(record.purpose)} · ${requestStatusLabel(record.status)}',
    ),
    subtitle: Text(
      '${record.requestedModelId}${record.isInherited ? ' · 继承记录，不计本会话消耗' : ''}',
    ),
    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    expandedCrossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('${record.createdAt.toLocal()} · 尝试 ${record.attemptIndex}'),
      if (record.responseModelId case final model?) Text('服务端模型：$model'),
      for (final field in UsageField.values)
        Text(
          '${usageFieldLabel(field)}：${record.usage?.value(field) ?? '未提供'}'
          '${record.usage?.source(field) == UsageSource.derived ? '（可靠推导）' : ''}'
          '${record.usage?.invalidFields.contains(field) == true ? '（字段异常）' : ''}',
        ),
      Text(
        record.usage?.value(UsageField.promptTokens) == null ||
                record.usage?.value(UsageField.cacheReadTokens) == null
            ? '缓存命中率：未提供'
            : '缓存命中率：${cacheRateLabel(record.usage?.cacheHitRate)}',
      ),
      if (!record.usageComplete) const Text('用量未完整收口；缺失项不视为零消耗'),
      if (record.usage?.hasUnexplainedTotal == true)
        const Text('服务端总数已保留；明细不完整，已知分项不能解释总量'),
      SelectableText(
        '请求 ${record.id}${record.originRequestId == null ? '' : '\n继承来源 ${record.originRequestId}'}',
      ),
    ],
  );
}
