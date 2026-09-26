import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/error/failure.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../data/repositories/agent_run_repository.dart';
import '../chat/chat_controller.dart';
import 'run_recovery_controller.dart';
import 'resolved_tool_card.dart';

class RunRecoveryPage extends ConsumerStatefulWidget {
  const RunRecoveryPage({super.key});

  @override
  ConsumerState<RunRecoveryPage> createState() => _RunRecoveryPageState();
}

class _RunRecoveryPageState extends ConsumerState<RunRecoveryPage> {
  bool _working = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        ref
            .read(runRecoveryControllerProvider.notifier)
            .initialize()
            .catchError((Object _) {}),
      );
    });
  }

  Future<void> _stop(String id) async {
    if (_working) return;
    setState(() => _working = true);
    try {
      await ref.read(runRecoveryControllerProvider.notifier).stop(id);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          buildAppSnackBar(
            content: Text(error is Failure ? error.userMessage : '停止任务失败'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _resume(RecoveredRun entry) {
    if (_working) return;
    setState(() => _working = true);
    final messenger = ScaffoldMessenger.of(context);
    final future = ref
        .read(chatControllerProvider.notifier)
        .resumeRun(entry.run.id);
    context.pop();
    unawaited(
      future.catchError((Object error) {
        if (messenger.mounted) {
          messenger.showSnackBar(
            buildAppSnackBar(
              content: Text(error is Failure ? error.userMessage : '继续任务失败'),
            ),
          );
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(runRecoveryControllerProvider);
    return AppScaffold(
      title: '中断任务',
      body: entries.when(
        loading: () => const Center(child: AppLoadingIndicator()),
        error: (error, _) => AppEmptyState(
          icon: Symbols.error,
          title: '无法读取中断任务',
          message: error is Failure ? error.userMessage : '请重试，暂不继续执行动作。',
          action: TextButton(
            onPressed: () => unawaited(
              ref
                  .read(runRecoveryControllerProvider.notifier)
                  .refresh()
                  .catchError((Object _) {}),
            ),
            child: const Text('重试'),
          ),
        ),
        data: (items) => items.isEmpty
            ? const AppEmptyState(
                icon: Symbols.task_alt,
                title: '没有待处理的中断任务',
                message: '已保存的执行结果不会自动重做。',
              )
            : ListView.builder(
                padding: const EdgeInsets.all(AppSpacing.l),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final entry = items[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          entry.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.s),
                        Text('任务已中断。继续后由 AI 处理已有结果，不会自动重发已派发的动作。'),
                        for (final call in entry.calls) ...[
                          const SizedBox(height: AppSpacing.m),
                          ResolvedToolCard(record: call),
                        ],
                        const SizedBox(height: AppSpacing.m),
                        Wrap(
                          spacing: AppSpacing.s,
                          runSpacing: AppSpacing.s,
                          children: [
                            TextButton(
                              key: ValueKey('stop-run-${entry.run.id}'),
                              onPressed: _working
                                  ? null
                                  : () => _stop(entry.run.id),
                              child: const Text('停止任务'),
                            ),
                            FilledButton.tonal(
                              key: ValueKey('resume-run-${entry.run.id}'),
                              onPressed: _working ? null : () => _resume(entry),
                              child: const Text('继续任务'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
