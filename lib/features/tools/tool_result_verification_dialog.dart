import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failure.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../data/models/tool_call_record.dart';
import 'run_recovery_controller.dart';
import 'tool_presentation.dart';

class ToolResultVerificationDialog extends ConsumerStatefulWidget {
  const ToolResultVerificationDialog({super.key, required this.record});
  final ToolCallRecord record;

  @override
  ConsumerState<ToolResultVerificationDialog> createState() =>
      _ToolResultVerificationDialogState();
}

class _ToolResultVerificationDialogState
    extends ConsumerState<ToolResultVerificationDialog> {
  final _text = TextEditingController();
  bool? _succeeded;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_succeeded == null || _text.text.trim().isEmpty) {
      setState(() => _error = '请选择实际状态并填写核验结果');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(runRecoveryControllerProvider.notifier)
          .verify(widget.record.id, succeeded: _succeeded!, result: _text.text);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error is Failure ? error.userMessage : '保存核验结果失败';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AppDialog(
      title: '核验实际结果',
      description:
          '${ToolPresentation.toolLabel(widget.record.toolName)}\n${widget.record.target ?? ''}\n请检查实际目标后填写；保存核验不会执行此动作。',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<bool>(
            isExpanded: true,
            key: const ValueKey('verification-status'),
            decoration: const InputDecoration(labelText: '实际状态'),
            items: const [
              DropdownMenuItem(value: true, child: Text('已确认成功')),
              DropdownMenuItem(value: false, child: Text('已确认失败 / 未发生')),
            ],
            onChanged: _saving
                ? null
                : (value) => setState(() => _succeeded = value),
          ),
          const SizedBox(height: AppSpacing.m),
          TextField(
            key: const ValueKey('verification-result'),
            controller: _text,
            enabled: !_saving,
            minLines: 2,
            maxLines: 5,
            decoration: InputDecoration(labelText: '实际结果', errorText: _error),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const ValueKey('save-verification'),
          onPressed: _saving ? null : _save,
          child: Text(_saving ? '保存中…' : '保存核验'),
        ),
      ],
    ),
  );
}
