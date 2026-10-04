import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../tools/run_recovery_controller.dart';
import '../execution/execution_controller.dart';
import 'chat_controller.dart';
import 'tool_confirmation_host.dart';

/// 切换查看位置后仍能回到根任务；启动失败与中断任务都有可达入口。
class ChatRunBanner extends ConsumerWidget {
  const ChatRunBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chat = ref.watch(
      chatControllerProvider.select(
        (state) => (retry: state.retry, summarizing: state.summarizing),
      ),
    );
    final recovery = ref.watch(runRecoveryControllerProvider);
    final count = recovery.value?.length ?? 0;
    final execution = ref.watch(
      executionControllerProvider.select(
        (state) =>
            (confirmation: state.confirmation, userAction: state.userAction),
      ),
    );
    final pending = execution.confirmation;
    final userAction = execution.userAction;
    final reopen = ToolConfirmationHost.reopenOf(context);
    final canConfirm = pending != null && reopen != null;
    final retry = chat.retry;
    if (count == 0 &&
        !recovery.hasError &&
        !canConfirm &&
        userAction == null &&
        retry == null &&
        !chat.summarizing) {
      return const SizedBox.shrink();
    }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 840),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
          child: Wrap(
            spacing: AppSpacing.s,
            runSpacing: AppSpacing.xs,
            children: [
              if (chat.summarizing) const Text('正在整理上下文摘要 · 可停止'),
              if (userAction != null)
                Semantics(
                  liveRegion: true,
                  child: Container(
                    key: const ValueKey('waiting-for-user'),
                    padding: const EdgeInsets.all(AppSpacing.s),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('等待你操作 · AI 已暂停'),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 96),
                          child: SingleChildScrollView(
                            child: Text(userAction.prompt),
                          ),
                        ),
                        TextButton.icon(
                          key: const ValueKey('continue-user-action'),
                          icon: const Icon(LucideIcons.play),
                          label: const Text('继续，让 AI 接管'),
                          onPressed: () => ref
                              .read(executionControllerProvider.notifier)
                              .continueRun(
                                userAction.runId,
                                userAction.toolCallId,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (retry != null)
                Semantics(
                  liveRegion: true,
                  child: Text(
                    '自动重试 ${retry.attempt}/${retry.maxRetries} · 等待 ${retry.delay.inSeconds} 秒',
                    key: const ValueKey('model-retry-status'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              if (canConfirm)
                TextButton(
                  key: const ValueKey('reopen-tool-confirmation'),
                  onPressed: reopen,
                  child: const Text('查看待确认动作'),
                ),
              if (recovery.hasError)
                TextButton(
                  onPressed: () => context.push('/tasks'),
                  child: const Text('中断任务读取失败 · 重试'),
                )
              else if (count > 0)
                TextButton(
                  key: const ValueKey('open-recovered-runs'),
                  onPressed: () => context.push('/tasks'),
                  child: Text('查看中断任务（$count）'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
