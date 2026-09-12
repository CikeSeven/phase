import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
    final pending = ref.watch(executionControllerProvider).confirmation;
    final reopen = ToolConfirmationHost.reopenOf(context);
    final canConfirm = pending != null && reopen != null;
    if (!runningElsewhere && count == 0 && !recovery.hasError && !canConfirm) {
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
