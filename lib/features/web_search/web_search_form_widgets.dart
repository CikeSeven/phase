import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/app_icon_badge.dart';

class WebNumberField extends StatelessWidget {
  const WebNumberField({
    required this.controller,
    required this.label,
    required this.minimum,
    required this.maximum,
    required this.enabled,
    required this.onChanged,
    super.key,
  });
  final TextEditingController controller;
  final String label;
  final int minimum;
  final int maximum;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.l),
    child: TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        helperText: '$minimum–$maximum',
      ),
      onChanged: onChanged,
      validator: (value) {
        final number = int.tryParse(value?.trim() ?? '');
        return number == null || number < minimum || number > maximum
            ? '请输入 $minimum 至 $maximum 的整数'
            : null;
      },
    ),
  );
}

/// 草稿离开时才询问；未完成的写入不能被返回动作误当作已保存。
class WebDraftBackGuard extends StatefulWidget {
  const WebDraftBackGuard({
    required this.dirty,
    required this.busy,
    required this.child,
    this.onBusyBack,
    super.key,
  });
  final bool dirty;
  final bool busy;
  final VoidCallback? onBusyBack;
  final Widget child;
  @override
  State<WebDraftBackGuard> createState() => _WebDraftBackGuardState();
}

class _WebDraftBackGuardState extends State<WebDraftBackGuard> {
  bool _leaving = false;
  bool _asking = false;
  Future<void> _back() async {
    if (_asking || _leaving) return;
    // AppDropdown 使用路由内部历史；返回优先关闭菜单，不丢弃页面草稿。
    if (ModalRoute.of(context)?.willHandlePopInternally == true) {
      Navigator.of(context).pop();
      return;
    }
    if (widget.busy) {
      widget.onBusyBack?.call();
      return;
    }
    _asking = true;
    try {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AppDialog(
          title: '放弃未保存的更改？',
          icon: LucideIcons.undo2,
          tone: AppTone.error,
          content: const SizedBox.shrink(),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('继续编辑'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('放弃更改'),
            ),
          ],
        ),
      );
      if (!mounted || discard != true) return;
      setState(() => _leaving = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.pop();
      });
    } finally {
      _asking = false;
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _leaving || (!widget.dirty && !widget.busy),
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _back();
    },
    child: widget.child,
  );
}
