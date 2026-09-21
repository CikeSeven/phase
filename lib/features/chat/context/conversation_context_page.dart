import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_loading_indicator.dart';
import '../../../../data/models/context_summary.dart';
import '../../../../data/repositories/agent_context_repository.dart';
import '../../../../data/repositories/plan_repository.dart';
import '../chat_controller.dart';
import '../planning/plan_card.dart';

part 'conversation_context_page.g.dart';

@riverpod
Future<List<ContextSummary>> contextSummaries(Ref ref, String id) async =>
    (await ref.watch(agentContextRepositoryProvider.future)).list(id);

class ConversationContextPage extends ConsumerWidget {
  const ConversationContextPage({required this.conversationId, super.key});
  final String conversationId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans = ref.watch(conversationPlansProvider(conversationId));
    final summaries = ref.watch(contextSummariesProvider(conversationId));
    final chat = ref.watch(chatControllerProvider);
    final budget = chat.contextConversationId == conversationId
        ? chat.contextBuild
        : null;
    return AppScaffold(
      title: '计划与上下文',
      actions: [
        IconButton(
          tooltip: '刷新',
          icon: const Icon(Symbols.refresh),
          onPressed: () {
            ref.invalidate(contextSummariesProvider(conversationId));
            ref.invalidate(conversationPlansProvider(conversationId));
          },
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('上下文预算', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            budget == null
                ? '预算按运行中的模型配置计算；未配置窗口时使用本地 32768，输出预留 4096。'
                : '本次输入本地估算 ${budget.estimatedTokens} / ${budget.budget.input} token；'
                      '输出预留 ${budget.budget.output}，窗口 ${budget.budget.window}。${budget.summaryId == null ? '' : '已使用派生摘要。'}',
          ),
          const Text('本地估算不是 API 用量。保留当前任务与上一组完整交互；旧用户约束与工具组不被摘要替换。'),
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
          Text('摘要请求 · 独立用量', style: Theme.of(context).textTheme.titleMedium),
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
                    title: Text(
                      '${s.sourceModel} · ${switch (s.status) {
                        SummaryStatus.completed => '完成',
                        SummaryStatus.failed => '失败',
                        SummaryStatus.cancelled => '已停止',
                        SummaryStatus.running => '未收口',
                      }}',
                    ),
                    subtitle: Text(
                      'API 输入 ${s.usage?.inputTokens ?? '未提供'} / 输出 ${s.usage?.outputTokens ?? '未提供'}',
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: SelectableText(
                          '覆盖 ${s.coveredMessageIds.length} 条消息 · 版本 ${s.version}\n来源运行 ${s.runId}\n分支末端 ${s.branchEndId}\n'
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
