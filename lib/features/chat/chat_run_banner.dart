import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/error/failure.dart';
import '../tools/run_recovery_controller.dart';
import '../execution/execution_controller.dart';
import 'chat_controller.dart';
import 'tool_confirmation_host.dart';

/// 切换查看位置后仍能回到根任务；启动失败与中断任务都有可达入口。
class ChatRunBanner extends ConsumerWidget {
  const ChatRunBanner({super.key});

  Future<void> _openRunning(
    BuildContext context,
    WidgetRef ref,
    String id,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(chatControllerProvider.notifier).openConversation(id);
    } catch (error) {
      if (messenger.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(error is Failure ? error.userMessage : '打开运行会话失败'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chat = ref.watch(chatControllerProvider);
    final viewed = ref.watch(activeConversationProvider).conversationId;
    final recovery = ref.watch(runRecoveryControllerProvider);
    final runningElsewhere =
        chat.isGenerating &&
        chat.runningConversationId != null &&
        chat.runningConversationId != viewed;
    final count = recovery.value?.length ?? 0;
    final execution = ref.watch(executionControllerProvider);
    final pending = execution.confirmation;
    final userAction = execution.userAction;
    final reopen = ToolConfirmationHost.reopenOf(context);
    final canConfirm = pending != null && reopen != null;
    final retry = chat.retry;
    if (!runningElsewhere &&
        count == 0 &&
        !recovery.hasError &&
        !canConfirm &&
        userAction == null &&
        retry == null) {
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
                          icon: const Icon(Symbols.play_arrow),
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
              if (runningElsewhere)
                TextButton(
                  key: const ValueKey('return-to-running-chat'),
                  onPressed: () => unawaited(
                    _openRunning(context, ref, chat.runningConversationId!),
                  ),
                  child: const Text('返回运行中的会话'),
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
