import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../tools/tool.dart';
import 'command_task_controller.dart';
import 'task_presentation.dart';

enum _LogStream { all, stdout, stderr }

class TaskDetailPage extends ConsumerStatefulWidget {
  const TaskDetailPage({required this.id, super.key});
  final String id;
  @override
  ConsumerState<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends ConsumerState<TaskDetailPage> {
  final _scroll = ScrollController();
  final _cancellation = RunCancellation();
  _LogStream _stream = _LogStream.all;
  bool _busy = false;
  bool _follow = true;
  int? _stdoutOffset;
  int? _stderrOffset;

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
      // The controller retains the error for the retry surface.
    }
  }

  @override
  void dispose() {
    _cancellation.cancel();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _action(Future<void> Function() operation) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await operation();
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

  Future<bool> _confirm(String title, String label, String text) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AppDialog(
          title: title,
          content: SelectableText(text),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(label),
            ),
          ],
        ),
      ) ==
      true;

  String _text(CommandTaskOutput output) => [
    if (_stream != _LogStream.stderr) ...[
      if (output.stdout.truncated) '[stdout 较早的日志已省略]',
      if (output.stdout.text.isNotEmpty) output.stdout.text,
    ],
    if (_stream != _LogStream.stdout) ...[
      if (output.stderr.truncated) '[stderr 较早的日志已省略]',
      if (output.stderr.text.isNotEmpty)
        '${_stream == _LogStream.all ? '[stderr]\n' : ''}${output.stderr.text}',
    ],
  ].join('\n');

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(commandTaskControllerProvider);
    final task = state.tasks
        .where((value) => value.id == widget.id)
        .firstOrNull;
    final output = state.initialized && task != null
        ? ref.watch(
            commandTaskOutputProvider(
              widget.id,
              stdoutOffset: _stdoutOffset,
              stderrOffset: _stderrOffset,
            ),
          )
        : null;
    final names = ref.watch(taskConversationsProvider).value ?? [];
    final owner = names
        .where((value) => value.id == task?.conversationId)
        .firstOrNull;
    final controller = ref.read(commandTaskControllerProvider.notifier);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return AppScaffold(
      title: '任务详情',
      actions: [
        IconButton(
          tooltip: '复制命令',
          onPressed: task == null
              ? null
              : () => _action(
                  () => Clipboard.setData(ClipboardData(text: task.command)),
                ),
          icon: const Icon(LucideIcons.copy),
        ),
        if (task?.status.active == true)
          IconButton(
            tooltip: '停止任务',
            onPressed: _busy || task!.status == CommandTaskStatus.stopping
                ? null
                : () => _action(() async {
                    await controller.stop(task.id);
                  }),
            icon: const Icon(LucideIcons.square),
          )
        else ...[
          IconButton(
            tooltip: '重新运行',
            onPressed: _busy || task == null
                ? null
                : () async {
                    if (!await _confirm('重新运行任务', '重新运行', task.command) ||
                        !context.mounted) {
                      return;
                    }
                    await _action(() async {
                      final next = await controller.restart(
                        task.id,
                        _cancellation,
                      );
                      if (context.mounted) {
                        context.pushReplacement('/background-tasks/${next.id}');
                      }
                    });
                  },
            icon: const Icon(LucideIcons.rotateCw),
          ),
          IconButton(
            tooltip: '删除任务记录',
            onPressed: _busy || task == null
                ? null
                : () async {
                    if (!await _confirm('删除任务记录', '删除', task.title) ||
                        !context.mounted) {
                      return;
                    }
                    await _action(() async {
                      await controller.remove(task.id);
                      if (context.mounted) context.pop();
                    });
                  },
            icon: const Icon(LucideIcons.trash2),
          ),
        ],
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
          : task == null
          ? const AppEmptyState(
              icon: LucideIcons.terminal,
              title: '任务记录不存在',
              message: '记录已删除',
            )
          : SingleChildScrollView(
              controller: _scroll,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.l),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          task.title,
                          style: theme.textTheme.titleMedium,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppSpacing.s),
                        Wrap(
                          spacing: AppSpacing.m,
                          runSpacing: AppSpacing.xs,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  taskStatusIcon(task.status),
                                  size: 18,
                                  color: taskStatusColor(context, task.status),
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Text(
                                  task.status.label,
                                  style: TextStyle(
                                    color: taskStatusColor(
                                      context,
                                      task.status,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            _ElapsedTime(task: task),
                            if (task.exitCode != null)
                              Text('exit ${task.exitCode}'),
                            if (task.signal != null)
                              Text('signal ${task.signal}'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.l,
                      0,
                      AppSpacing.l,
                      AppSpacing.xl,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SelectableText(
                          task.command,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(height: AppSpacing.m),
                        _TaskField(
                          label: '会话',
                          value: owner?.title ?? task.conversationId,
                        ),
                        _TaskField(label: '工作目录', value: task.cwd),
                        _TaskField(label: '任务 ID', value: task.id),
                        _TaskField(
                          label: '完成后继续 AI 回复',
                          value: task.notifyOnCompletion ? '开启' : '关闭',
                        ),
                        if (task.completionDelivery ==
                            TaskCompletionDelivery.pending)
                          Row(
                            children: [
                              const Expanded(child: Text('等待 AI 续答')),
                              IconButton(
                                tooltip: '继续 AI 回复',
                                onPressed: controller.retryCompletionDelivery,
                                icon: const Icon(LucideIcons.messageCircle),
                              ),
                            ],
                          ),
                        if (state.completionErrors[task.conversationId]
                            case final failure?)
                          Text(
                            failure.userMessage,
                            style: TextStyle(color: colors.error),
                          ),
                        _TaskField(
                          label: '创建时间',
                          value: taskDate(task.createdAt),
                        ),
                        if (task.finishedAt != null)
                          _TaskField(
                            label: '结束时间',
                            value: taskDate(task.finishedAt!),
                          ),
                        if (task.timeoutMs != null)
                          _TaskField(
                            label: '执行超时',
                            value: '${task.timeoutMs! / 1000} 秒',
                          ),
                        if (task.error != null) ...[
                          const SizedBox(height: AppSpacing.s),
                          Text(
                            task.error!,
                            style: TextStyle(color: colors.error),
                          ),
                        ],
                        if (state.error != null)
                          Text(
                            state.error!.userMessage,
                            style: TextStyle(color: colors.error),
                          ),
                        const SizedBox(height: AppSpacing.l),
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: AppSpacing.s,
                          runSpacing: AppSpacing.s,
                          children: [
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SegmentedButton<_LogStream>(
                                segments: const [
                                  ButtonSegment(
                                    value: _LogStream.all,
                                    label: Text('全部'),
                                  ),
                                  ButtonSegment(
                                    value: _LogStream.stdout,
                                    label: Text('stdout'),
                                  ),
                                  ButtonSegment(
                                    value: _LogStream.stderr,
                                    label: Text('stderr'),
                                  ),
                                ],
                                selected: {_stream},
                                onSelectionChanged: (value) =>
                                    setState(() => _stream = value.first),
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: '复制日志',
                                  onPressed: output?.value == null
                                      ? null
                                      : () => _action(
                                          () => Clipboard.setData(
                                            ClipboardData(
                                              text: _text(output!.value!),
                                            ),
                                          ),
                                        ),
                                  icon: const Icon(LucideIcons.copy),
                                ),
                                IconButton(
                                  tooltip: '刷新日志',
                                  onPressed: _busy
                                      ? null
                                      : () => _action(controller.refresh),
                                  icon: const Icon(LucideIcons.rotateCw),
                                ),
                                IconButton(
                                  tooltip: '滚动到底部',
                                  onPressed: () {
                                    if (_scroll.hasClients) {
                                      _scroll.jumpTo(
                                        _scroll.position.maxScrollExtent,
                                      );
                                    }
                                  },
                                  icon: const Icon(LucideIcons.arrowDown),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.s),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              const Text('实时'),
                              Switch(
                                value: _follow,
                                onChanged: (value) {
                                  setState(() {
                                    _follow = value;
                                    _stdoutOffset = value
                                        ? null
                                        : output?.value?.stdout.startOffset;
                                    _stderrOffset = value
                                        ? null
                                        : output?.value?.stderr.startOffset;
                                  });
                                },
                              ),
                              IconButton(
                                tooltip: '较早日志',
                                onPressed:
                                    output?.value == null ||
                                        (output!.value!.stdout.startOffset <=
                                                output
                                                    .value!
                                                    .stdout
                                                    .oldestOffset &&
                                            output.value!.stderr.startOffset <=
                                                output
                                                    .value!
                                                    .stderr
                                                    .oldestOffset)
                                    ? null
                                    : () => setState(() {
                                        _follow = false;
                                        _stdoutOffset =
                                            (output.value!.stdout.startOffset -
                                                    32768)
                                                .clamp(
                                                  0,
                                                  output
                                                      .value!
                                                      .stdout
                                                      .totalBytes,
                                                );
                                        _stderrOffset =
                                            (output.value!.stderr.startOffset -
                                                    32768)
                                                .clamp(
                                                  0,
                                                  output
                                                      .value!
                                                      .stderr
                                                      .totalBytes,
                                                );
                                      }),
                                icon: const Icon(LucideIcons.chevronLeft),
                              ),
                              IconButton(
                                tooltip: '较新日志',
                                onPressed:
                                    output?.value == null ||
                                        (!output!.value!.stdout.hasMore &&
                                            !output.value!.stderr.hasMore)
                                    ? null
                                    : () => setState(() {
                                        _follow = false;
                                        _stdoutOffset =
                                            output.value!.stdout.nextOffset;
                                        _stderrOffset =
                                            output.value!.stderr.nextOffset;
                                      }),
                                icon: const Icon(LucideIcons.chevronRight),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          'stdout ${taskByteSize(task.stdoutBytes)} · stderr ${taskByteSize(task.stderrBytes)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        const Divider(height: 24),
                        if (output != null)
                          output.when(
                            skipLoadingOnReload: true,
                            loading: () => const AppLoadingIndicator(),
                            error: (error, _) => Text(
                              error is Failure ? error.userMessage : '任务日志读取失败',
                              style: TextStyle(color: colors.error),
                            ),
                            data: (value) {
                              final text = _text(value);
                              return SelectableText(
                                text.isEmpty ? '暂无输出' : text,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontFamily: 'monospace',
                                  height: 1.5,
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _TaskField extends StatelessWidget {
  const _TaskField({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
    child: SelectableText(
      '$label: $value',
      style: Theme.of(context).textTheme.bodySmall,
    ),
  );
}

class _ElapsedTime extends StatefulWidget {
  const _ElapsedTime({required this.task});
  final CommandTask task;
  @override
  State<_ElapsedTime> createState() => _ElapsedTimeState();
}

class _ElapsedTimeState extends State<_ElapsedTime> {
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(_ElapsedTime oldWidget) {
    super.didUpdateWidget(oldWidget);
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    if (widget.task.status.active) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text(taskDuration(widget.task));
}
