import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/error/failure.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_dropdown.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../../data/models/command_task.dart';
import '../tools/tool.dart';
import 'command_task_controller.dart';

class TaskStartDialog extends ConsumerStatefulWidget {
  const TaskStartDialog({this.conversationId, super.key});
  final String? conversationId;
  @override
  ConsumerState<TaskStartDialog> createState() => _TaskStartDialogState();
}

class _TaskStartDialogState extends ConsumerState<TaskStartDialog> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _command = TextEditingController();
  final _cwd = TextEditingController();
  final _timeout = TextEditingController();
  final _cancellation = RunCancellation();
  String? _conversationId;
  String? _error;
  bool _busy = false;
  bool _notifyOnCompletion = true;

  @override
  void dispose() {
    _cancellation.cancel();
    for (final controller in [_title, _command, _cwd, _timeout]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _start(String conversationId) async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final timeout = _timeout.text.trim();
      final task = await ref
          .read(commandTaskControllerProvider.notifier)
          .startForConversation(
            conversationId: conversationId,
            command: _command.text,
            title: _title.text.trim().isEmpty ? null : _title.text.trim(),
            cwd: _cwd.text.trim().isEmpty ? null : _cwd.text.trim(),
            timeoutMs: timeout.isEmpty
                ? null
                : (double.parse(timeout) * 1000).ceil(),
            cancellation: _cancellation,
            notifyOnCompletion: _notifyOnCompletion,
          );
      if (mounted) Navigator.pop<CommandTask>(context, task);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is Failure ? error.userMessage : '任务启动失败',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final conversations = ref.watch(taskConversationsProvider);
    final options = <String, String>{
      for (final conversation in conversations.value ?? [])
        if (conversation.workspaceId != null)
          conversation.id: conversation.title,
    };
    final preferred = _conversationId ?? widget.conversationId;
    final selected = options.containsKey(preferred)
        ? preferred
        : widget.conversationId == null
        ? options.keys.firstOrNull
        : null;
    return PopScope(
      canPop: !_busy,
      child: AppDialog(
        title: '新建后台任务',
        icon: LucideIcons.terminal,
        content: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (conversations.isLoading) const AppLoadingIndicator(),
              if (conversations.hasError) ...[
                const Text('会话列表读取失败'),
                TextButton.icon(
                  onPressed: () => ref.invalidate(taskConversationsProvider),
                  icon: const Icon(LucideIcons.rotateCw),
                  label: const Text('重试'),
                ),
              ],
              if (selected != null)
                AppDropdown<String>(
                  label: '所属会话',
                  value: selected,
                  options: options,
                  onChanged: _busy || widget.conversationId != null
                      ? null
                      : (value) => setState(() => _conversationId = value),
                )
              else if (!conversations.isLoading && !conversations.hasError)
                const Text('没有可用会话'),
              const SizedBox(height: AppSpacing.m),
              TextFormField(
                controller: _title,
                enabled: !_busy,
                maxLength: 120,
                decoration: const InputDecoration(labelText: '名称（可选）'),
              ),
              const SizedBox(height: AppSpacing.s),
              TextFormField(
                controller: _command,
                enabled: !_busy,
                minLines: 3,
                maxLines: 6,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
                decoration: const InputDecoration(labelText: '命令'),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? '请输入命令' : null,
              ),
              const SizedBox(height: AppSpacing.m),
              TextFormField(
                controller: _cwd,
                enabled: !_busy,
                decoration: const InputDecoration(labelText: '工作目录（默认会话工作区）'),
                validator: (value) =>
                    value != null &&
                        value.trim().isNotEmpty &&
                        !value.trim().startsWith('/')
                    ? '请输入绝对路径'
                    : null,
              ),
              const SizedBox(height: AppSpacing.m),
              TextFormField(
                controller: _timeout,
                enabled: !_busy,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: '执行超时（秒，可选）'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return null;
                  final number = double.tryParse(value);
                  return number == null ||
                          !number.isFinite ||
                          number <= 0 ||
                          number * 1000 > 2147483647
                      ? '请输入有效的正数秒'
                      : null;
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.m),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('完成后继续 AI 回复'),
                value: _notifyOnCompletion,
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _notifyOnCompletion = value),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton.icon(
            onPressed: _busy || selected == null
                ? null
                : () => _start(selected),
            icon: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: AppLoadingIndicator(),
                  )
                : const Icon(LucideIcons.play),
            label: const Text('启动'),
          ),
        ],
      ),
    );
  }
}
