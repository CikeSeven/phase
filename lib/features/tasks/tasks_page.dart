import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/error/failure.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../data/models/command_task.dart';
import 'command_task_controller.dart';
import 'task_presentation.dart';
import 'task_start_dialog.dart';

enum _TaskFilter { active, all, finished }

class TasksPage extends ConsumerStatefulWidget {
  const TasksPage({this.conversationId, super.key});
  final String? conversationId;
  @override
  ConsumerState<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends ConsumerState<TasksPage> {
  _TaskFilter _filter = _TaskFilter.all;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_initialize());
    });
  }

  Future<void> _initialize() async {
    try {
      await ref.read(commandTaskControllerProvider.notifier).initialize();
    } on Object {
      // The controller retains the failure and the page exposes retry.
    }
  }

  Future<void> _action(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          buildAppSnackBar(
            content: Text(error is Failure ? error.userMessage : '任务操作失败'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _newTask() async {
    final task = await showDialog<CommandTask>(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          TaskStartDialog(conversationId: widget.conversationId),
    );
    if (task != null && mounted) context.push('/background-tasks/${task.id}');
  }

  Future<void> _stopAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AppDialog(
        title: '停止所有后台任务',
        icon: LucideIcons.square,
        content: Text(
          widget.conversationId == null ? '停止所有会话中的后台命令？' : '停止本会话中的所有后台命令？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('停止全部'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _action(
        () => ref
            .read(commandTaskControllerProvider.notifier)
            .stopAll(conversationId: widget.conversationId),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(commandTaskControllerProvider);
    final names = ref.watch(taskConversationsProvider).value ?? [];
    final owned = state.tasks
        .where(
          (task) =>
              widget.conversationId == null ||
              task.conversationId == widget.conversationId,
        )
        .toList();
    final tasks = owned
        .where(
          (task) => switch (_filter) {
            _TaskFilter.active => task.status.active,
            _TaskFilter.finished => !task.status.active,
            _TaskFilter.all => true,
          },
        )
        .toList();
    final colors = Theme.of(context).colorScheme;
    return AppScaffold(
      title: widget.conversationId == null ? '任务管理' : '会话任务',
      actions: [
        if (state.pendingCompletions.isNotEmpty)
          IconButton(
            tooltip: '继续 AI 回复',
            onPressed: _busy
                ? null
                : () => ref
                      .read(commandTaskControllerProvider.notifier)
                      .retryCompletionDelivery(),
            icon: const Icon(LucideIcons.messageCircle),
          ),
        IconButton(
          tooltip: '刷新',
          onPressed: _busy
              ? null
              : () => _action(
                  () => ref
                      .read(commandTaskControllerProvider.notifier)
                      .refresh(),
                ),
          icon: const Icon(LucideIcons.rotateCw),
        ),
        IconButton(
          tooltip: '停止所有后台任务',
          onPressed: _busy || !owned.any((task) => task.status.active)
              ? null
              : _stopAll,
          icon: const Icon(LucideIcons.square),
        ),
        IconButton(
          tooltip: '新建后台任务',
          onPressed: _busy || !state.initialized ? null : _newTask,
          icon: const Icon(LucideIcons.plus),
        ),
      ],
      body: !state.initialized
          ? state.error != null
                ? AppEmptyState(
                    icon: LucideIcons.circleAlert,
                    title: '无法读取任务',
                    message: state.error!.userMessage,
                    action: TextButton(
                      onPressed: _initialize,
                      child: const Text('重试'),
                    ),
                  )
                : const Center(child: AppLoadingIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.l),
                  child: LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SegmentedButton<_TaskFilter>(
                        segments: const [
                          ButtonSegment(
                            value: _TaskFilter.all,
                            label: Text('全部'),
                          ),
                          ButtonSegment(
                            value: _TaskFilter.active,
                            label: Text('运行中'),
                          ),
                          ButtonSegment(
                            value: _TaskFilter.finished,
                            label: Text('已结束'),
                          ),
                        ],
                        selected: {_filter},
                        onSelectionChanged: (value) =>
                            setState(() => _filter = value.first),
                      ),
                    ),
                  ),
                ),
                if (state.error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.l,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            state.error!.userMessage,
                            style: TextStyle(color: colors.error),
                          ),
                        ),
                        IconButton(
                          tooltip: '重试保存并刷新',
                          onPressed: _busy
                              ? null
                              : () => _action(
                                  () => ref
                                      .read(
                                        commandTaskControllerProvider.notifier,
                                      )
                                      .refresh(),
                                ),
                          icon: const Icon(LucideIcons.rotateCw),
                        ),
                      ],
                    ),
                  ),
                if (state.completionErrors.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.l,
                    ),
                    child: Text(
                      state.completionErrors.values.first.userMessage,
                      style: TextStyle(color: colors.error),
                    ),
                  ),
                Expanded(
                  child: tasks.isEmpty
                      ? AppEmptyState(
                          icon: LucideIcons.terminal,
                          message: '暂无后台命令',
                          title:
                              '没有${_filter == _TaskFilter.active
                                  ? '运行中的'
                                  : _filter == _TaskFilter.finished
                                  ? '已结束的'
                                  : ''}任务',
                          action: _filter == _TaskFilter.all
                              ? TextButton.icon(
                                  onPressed: _newTask,
                                  icon: const Icon(LucideIcons.plus),
                                  label: const Text('新建任务'),
                                )
                              : null,
                        )
                      : ListView.separated(
                          itemCount: tasks.length,
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.l,
                            0,
                            AppSpacing.l,
                            AppSpacing.l,
                          ),
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final task = tasks[index];
                            final owner = names
                                .where(
                                  (value) => value.id == task.conversationId,
                                )
                                .firstOrNull;
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.s,
                              ),
                              leading: Icon(
                                taskStatusIcon(task.status),
                                color: taskStatusColor(context, task.status),
                              ),
                              title: Text(
                                task.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${task.status.label}${task.exitCode == null ? '' : ' · exit ${task.exitCode}'} · ${taskDuration(task)}',
                                  ),
                                  if (widget.conversationId == null)
                                    Text(
                                      owner?.title ?? task.conversationId,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  Text(
                                    task.cwd,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                              trailing: task.status.active
                                  ? IconButton(
                                      tooltip: '停止任务',
                                      onPressed:
                                          _busy ||
                                              task.status ==
                                                  CommandTaskStatus.stopping
                                          ? null
                                          : () => _action(() async {
                                              await ref
                                                  .read(
                                                    commandTaskControllerProvider
                                                        .notifier,
                                                  )
                                                  .stop(task.id);
                                            }),
                                      icon: const Icon(LucideIcons.square),
                                    )
                                  : const Icon(LucideIcons.chevronRight),
                              onTap: () =>
                                  context.push('/background-tasks/${task.id}'),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
