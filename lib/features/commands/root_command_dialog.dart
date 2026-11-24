import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/error/failure.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/app_icon_badge.dart';
import 'root_command_driver.dart';

class RootCommandDialog extends StatefulWidget {
  const RootCommandDialog({required this.driver, super.key});

  final RootCommandDriver driver;

  @override
  State<RootCommandDialog> createState() => _RootCommandDialogState();
}

class _RootCommandDialogState extends State<RootCommandDialog> {
  final _command = TextEditingController();
  RootCommandResult? _result;
  String? _error;
  bool _running = false;
  bool _stopping = false;

  @override
  void dispose() {
    _command.dispose();
    super.dispose();
  }

  Future<void> _execute() async {
    final command = _command.text;
    if (_running || command.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _running = true;
      _result = null;
      _error = null;
    });
    try {
      final result = await widget.driver.execute(command);
      if (mounted) setState(() => _result = result);
    } on Failure catch (error) {
      if (mounted) setState(() => _error = error.userMessage);
    } finally {
      if (mounted) {
        setState(() {
          _running = false;
          _stopping = false;
        });
      }
    }
  }

  Future<void> _stop() async {
    if (!_running || _stopping) return;
    setState(() => _stopping = true);
    try {
      await widget.driver.cancel();
    } on Failure catch (error) {
      if (mounted) {
        setState(() {
          _error = error.userMessage;
          _stopping = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final result = _result;
    final status = switch (result?.status) {
      RootCommandStatus.cancelled => '已停止',
      RootCommandStatus.timedOut => '授权或执行超时',
      RootCommandStatus.unconfirmed => '未收到 Root 进程结束回执',
      RootCommandStatus.exited => '退出码 ${result!.exitCode}',
      null when _stopping => '正在停止…',
      null when _running => '正在等待授权或执行命令…',
      null => null,
    };
    return PopScope(
      canPop: !_running,
      child: AppDialog(
        title: 'Root 模式',
        description: '在已 Root 的 Android 设备上，以 UID 0 执行命令。',
        icon: LucideIcons.terminal,
        tone: AppTone.error,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.m,
          children: [
            TextField(
              controller: _command,
              enabled: !_running,
              minLines: 2,
              maxLines: 6,
              autocorrect: false,
              enableSuggestions: false,
              smartDashesType: SmartDashesType.disabled,
              smartQuotesType: SmartQuotesType.disabled,
              keyboardType: TextInputType.multiline,
              style: const TextStyle(fontFamily: 'monospace'),
              decoration: const InputDecoration(
                labelText: 'Android Shell 命令',
                hintText: 'id',
                alignLabelWithHint: true,
              ),
            ),
            if (status != null)
              Semantics(liveRegion: true, child: Text(status)),
            if (_error case final error?)
              Semantics(
                liveRegion: true,
                child: Text(error, style: TextStyle(color: colors.error)),
              ),
            if (result != null) ...[
              SelectableText(
                result.output.isEmpty ? '无输出' : result.output,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
              if (result.truncated) const Text('输出已截断（256 KiB）'),
            ],
          ],
        ),
        actions: [
          if (_running)
            TextButton(
              onPressed: _stopping ? null : _stop,
              child: const Text('停止'),
            )
          else
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('关闭'),
            ),
          ValueListenableBuilder(
            valueListenable: _command,
            builder: (context, value, _) => FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colors.error,
                foregroundColor: colors.onError,
              ),
              onPressed: _running || value.text.trim().isEmpty
                  ? null
                  : _execute,
              child: const Text('以 Root 执行'),
            ),
          ),
        ],
      ),
    );
  }
}
