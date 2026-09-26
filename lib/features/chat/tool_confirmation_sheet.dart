import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_sheet.dart';
import '../tools/tool_executor.dart';
import '../tools/tool_presentation.dart';

/// 确认面板的结果。
enum ToolConfirmationOutcome {
  /// 允许这一次动作。
  allowOnce,

  /// 允许本轮连续运行中的应用操作。
  allowApplicationOperationsForRun,

  /// 拒绝这一次动作。
  reject,

  /// 停止整个任务：本次动作不执行，循环按取消收口。
  stopTask,

  /// 到点仍未决定（或被关闭面板）：不批准这次动作。
  expired,
}

/// 弹出一次工具确认面板，返回用户决定。
///
/// 展示本次动作的真实参数及批准范围；本轮应用操作授权由执行器持有。
/// 关闭面板按未决定处理。
Future<ToolConfirmationOutcome> showToolConfirmationSheet(
  BuildContext context,
  ToolConfirmationRequest request,
) async {
  FocusManager.instance.primaryFocus?.unfocus();
  // 拖动杆由 AppSheet 自己画，这里不能再让框架画一个（会变成两根）。
  final outcome = await showModalBottomSheet<ToolConfirmationOutcome>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => ToolConfirmationSheet(request: request),
  );
  return outcome ?? ToolConfirmationOutcome.expired;
}

/// 等待确认的动作：工具名、动作摘要、实际参数、执行通道与剩余时间。
class ToolConfirmationSheet extends StatefulWidget {
  const ToolConfirmationSheet({required this.request, super.key});

  final ToolConfirmationRequest request;

  @override
  State<ToolConfirmationSheet> createState() => _ToolConfirmationSheetState();
}

class _ToolConfirmationSheetState extends State<ToolConfirmationSheet> {
  /// 剩余时间进入这个阈值后按紧急色调展示。
  static const _urgent = Duration(seconds: 10);

  late Duration _remaining;
  Timer? _ticker;
  bool _decided = false;

  @override
  void initState() {
    super.initState();
    _remaining = _timeLeft();
    if (_remaining <= Duration.zero) {
      // 迟到的请求不再等待：直接按未决定收口，不留下过期面板。
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _decide(ToolConfirmationOutcome.expired),
      );
      return;
    }
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Duration _timeLeft() {
    final left = widget.request.expiresAt.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  void _tick() {
    final left = _timeLeft();
    if (left <= Duration.zero) {
      // 到点未决定按拒绝处理。
      _decide(ToolConfirmationOutcome.expired);
      return;
    }
    if (mounted) setState(() => _remaining = left);
  }

  void _decide(ToolConfirmationOutcome outcome) {
    if (_decided) return;
    _decided = true;
    _ticker?.cancel();
    if (mounted) Navigator.of(context).pop(outcome);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final record = widget.request.record;
    final details = ToolPresentation.parameterDetails(record);
    final target = (record.target ?? '').trim();

    return AppSheet(
      footerMaxHeightFactor: 0.5,
      title: ToolPresentation.recordLabel(record),
      subtitle: widget.request.summary,
      // 面板只提供三个动作：关闭（含返回手势）按未决定处理。
      showClose: false,
      titleTrailing: Text(
        '剩余 ${_remaining.inSeconds} 秒',
        key: const ValueKey('tool-confirmation-countdown'),
        maxLines: 1,
        style: theme.textTheme.labelLarge?.copyWith(
          color: _remaining <= _urgent ? colors.error : colors.onSurfaceVariant,
        ),
      ),
      // 三个动作各占一整行：停止、拒绝、允许自上而下排，
      // 大字号下也不会被挤成换行的一团。
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton(
            key: const ValueKey('tool-confirm-stop'),
            onPressed: () => _decide(ToolConfirmationOutcome.stopTask),
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.error,
              side: BorderSide(color: colors.error.withValues(alpha: 0.56)),
            ),
            child: const Text('停止任务'),
          ),
          const SizedBox(height: AppSpacing.s),
          OutlinedButton(
            key: const ValueKey('tool-confirm-reject'),
            onPressed: () => _decide(ToolConfirmationOutcome.reject),
            child: const Text('拒绝'),
          ),
          const SizedBox(height: AppSpacing.s),
          FilledButton(
            key: const ValueKey('tool-confirm-allow'),
            onPressed: () => _decide(
              widget.request.applicationOperationsForRun
                  ? ToolConfirmationOutcome.allowApplicationOperationsForRun
                  : ToolConfirmationOutcome.allowOnce,
            ),
            child: Text(
              widget.request.applicationOperationsForRun ? '允许本轮操作应用' : '允许一次',
            ),
          ),
          // 再留一点底部内边距：三个按钮贴着面板下沿和手势条太近，容易误触。
          const SizedBox(height: AppSpacing.l),
        ],
      ),
      child: ListView(
        key: const ValueKey('tool-confirmation-body'),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
        children: [
          _InfoLine(
            label: '执行通道',
            value: ToolPresentation.recordChannelLabel(record),
          ),
          if (target.isNotEmpty) _InfoLine(label: '目标', value: target),
          _InfoLine(
            label: '策略',
            value: ToolPresentation.policyLabel(widget.request.policy),
          ),
          const SizedBox(height: AppSpacing.m),
          Text('本次动作的实际参数', style: theme.textTheme.labelLarge),
          if (details.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.s),
              child: Text(
                '这次动作没有参数。',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          for (final detail in details) _ParameterBlock(detail: detail),
          const SizedBox(height: AppSpacing.l),
          Text(
            widget.request.applicationOperationsForRun
                ? '允许本轮后续应用操作，本轮结束后失效。'
                : '允许只对本次动作生效；目标或参数变化会重新确认。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// 面板里的一行说明：标签与真实取值。
class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label：',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            TextSpan(text: value, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

/// 一项参数：标签与真实值；长正文与结构化参数按多行展示。
class _ParameterBlock extends StatelessWidget {
  const _ParameterBlock({required this.detail});

  final ToolParameterDetail detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            detail.label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          if (detail.multiline)
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 220),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHigh.withValues(alpha: 0.72),
                borderRadius: AppRadius.smallAll,
              ),
              child: SingleChildScrollView(
                primary: false,
                padding: const EdgeInsets.all(AppSpacing.s),
                child: SelectableText(
                  detail.value,
                  key: ValueKey('tool-parameter-${detail.name}'),
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
                ),
              ),
            )
          else
            SelectableText(
              detail.value,
              key: ValueKey('tool-parameter-${detail.name}'),
              style: theme.textTheme.bodyMedium,
            ),
        ],
      ),
    );
  }
}
