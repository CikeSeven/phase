import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/error/failure.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../../data/models/context_summary.dart';
import '../../../data/repositories/agent_context_repository.dart';
import '../../../data/repositories/plan_repository.dart';
import '../../../data/repositories/model_request_repository.dart';
import '../chat_controller.dart';
import '../planning/plan_card.dart';
import '../usage/usage_panel.dart';
import 'context_preview.dart';

part 'conversation_context_page.g.dart';

@riverpod
Stream<List<ContextSummary>> contextSummaries(Ref ref, String id) async* {
  yield* (await ref.watch(agentContextRepositoryProvider.future)).watch(id);
}

class ConversationContextPage extends ConsumerWidget {
  const ConversationContextPage({
    required this.conversationId,
    this.runId,
    super.key,
  });
  final String conversationId;
  final String? runId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans = ref.watch(conversationPlansProvider(conversationId));
    final summaries = ref.watch(contextSummariesProvider(conversationId));
    final chat = ref.watch(chatControllerProvider);
    final preview = ref.watch(contextPreviewProvider(conversationId));
    return AppScaffold(
      title: '计划与上下文',
      actions: [
        IconButton(
          tooltip: '刷新',
          icon: const Icon(Symbols.refresh),
          onPressed: () {
            ref.invalidate(contextSummariesProvider(conversationId));
            ref.invalidate(conversationPlansProvider(conversationId));
            ref.invalidate(contextPreviewProvider(conversationId));
            ref.invalidate(conversationRequestsProvider(conversationId));
          },
        ),
      ],
      body: ListView(
        key: PageStorageKey('context-$conversationId'),
        padding: const EdgeInsets.all(16),
        children: [
          Text('上下文预算', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          preview.when(
            skipLoadingOnReload: false,
            skipLoadingOnRefresh: false,
            loading: () => const Text('上下文待估算'),
            error: (e, _) => Text(e is Failure ? e.userMessage : '上下文估算失败'),
            data: (build) {
              final m = build?.measurement;
              if (m == null) return const Text('当前上下文待估算');
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${chat.isGenerating ? '运行请求' : '下一请求'}预计输入 ≈${m.estimatedInputTokens} / ${m.windowTokens} token',
                  ),
                  Text(
                    '${m.defaultWindow ? '本地默认窗口' : '用户配置窗口'} · 可用输入预算 ${m.inputBudget}',
                  ),
                  Text(
                    '输出预留 ${m.outputReserveTokens}${m.outputLimitUnknown ? '（本地预留，服务端上限未知）' : '（协议实际参数）'} · 协议余量 ${m.marginTokens}',
                  ),
                  Text('自动整理阈值 ≈${m.triggerTokens} · 目标 ≈${m.targetTokens}'),
                  Text(
                    m.anchorRequestId != null
                        ? '来源：服务端输入基准 + 本地增量估算'
                        : build!.summaryId != null
                        ? '来源：压缩后本地估算'
                        : '来源：本地请求投影估算',
                  ),
                  Text('测量时间 ${m.measuredAt.toLocal()}'),
                  ExpansionTile(
                    title: const Text('组成估算'),
                    children: [
                      Text(
                        '系统 ≈${m.systemTokens} · 工具 ≈${m.toolTokens}\n消息 ≈${m.messageTokens} · 图片 ≈${m.imageTokens}',
                      ),
                      const Text('组成是本地估算，可能不等于 usage 校准后的总数。'),
                    ],
                  ),
                  if (build?.compactionNotice case final notice?) Text(notice),
                ],
              );
            },
          ),
          const Text('当前会话；不含未发送草稿。原始历史保留，外部动作与未完成工具组不会被摘要淘汰。'),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: Icon(chat.isGenerating ? Symbols.stop : Symbols.compress),
              label: Text(chat.isGenerating ? '停止当前任务' : '整理上下文'),
              onPressed: chat.isGenerating
                  ? () => ref.read(chatControllerProvider.notifier).stop()
                  : ref.watch(activeConversationProvider).conversationId ==
                        conversationId
                  ? () async {
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        final result = await ref
                            .read(chatControllerProvider.notifier)
                            .compactContext(conversationId);
                        if (context.mounted) {
                          messenger.showSnackBar(
                            SnackBar(content: Text(result)),
                          );
                        }
                      } on Failure catch (e) {
                        if (context.mounted) {
                          messenger.showSnackBar(
                            SnackBar(content: Text(e.userMessage)),
                          );
                        }
                      } finally {
                        if (ref.context.mounted) {
                          ref.invalidate(
                            contextPreviewProvider(conversationId),
                          );
                        }
                      }
                    }
                  : null,
            ),
          ),
          const SizedBox(height: 24),
          Text('用量', style: Theme.of(context).textTheme.titleMedium),
          UsagePanel(conversationId: conversationId, runId: runId),
          const SizedBox(height: 24),
          Text('计划', style: Theme.of(context).textTheme.titleMedium),
          plans.when(
            data: (items) => Column(
              children: [
                if (items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('暂无提交的计划'),
                  ),
                for (final p in items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: PlanCard(plan: p),
                  ),
              ],
            ),
            loading: () => const AppLoadingIndicator(),
            error: (e, _) => Text(e is Failure ? e.userMessage : '读取计划失败'),
          ),
          const SizedBox(height: 24),
          Text('摘要检查点', style: Theme.of(context).textTheme.titleMedium),
          summaries.when(
            data: (items) => Column(
              children: [
                if (items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('尚未请求摘要，原始历史保留'),
                  ),
                for (final s in items)
                  ExpansionTile(
                    key: PageStorageKey('summary-${s.id}'),
                    title: Text(
                      '${s.sourceModel} · ${switch (s.status) {
                        SummaryStatus.completed => '完成',
                        SummaryStatus.failed => '失败',
                        SummaryStatus.cancelled => '已停止',
                        SummaryStatus.running => '未收口',
                      }}',
                    ),
                    subtitle: Text(
                      '${switch (s.adoption) {
                        SummaryAdoption.applied => '已采用',
                        SummaryAdoption.noGain => '未采用：无收益',
                        SummaryAdoption.tooLarge => '未采用：仍超预算',
                        SummaryAdoption.stale => '未采用：来源已变化',
                        SummaryAdoption.pending => '未采用',
                      }} · API 输入 ${s.usage?.promptTokens ?? '未提供'} / 输出 ${s.usage?.outputTokens ?? '未提供'}',
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: SelectableText(
                          '新增覆盖 ${s.coveredMessageIds.length} 条消息 · 版本 ${s.version}\n${s.runId == null ? '手动整理' : '来源运行 ${s.runId}'}\n分支末端 ${s.branchEndId}\n'
                          '前后本地估算 ≈${s.beforeTokens ?? '未测量'} → ≈${s.afterTokens ?? '未测量'}\n'
                          '${s.parentSummaryId == null ? '' : '父摘要 ${s.parentSummaryId}\n'}${s.reason ?? ''}\n'
                          '${s.createdAt.toLocal()}\n${s.text}',
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            loading: () => const AppLoadingIndicator(),
            error: (e, _) => Text(e is Failure ? e.userMessage : '读取摘要失败'),
          ),
        ],
      ),
    );
  }
}
