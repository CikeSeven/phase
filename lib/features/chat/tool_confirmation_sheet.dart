import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_icon_badge.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../data/models/tool_call_record.dart';
import '../../../data/models/tool_permission.dart';
import '../../../data/models/tool_source.dart';
import '../tools/tool_diff.dart';
import '../tools/tool_diff_view.dart';
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
/// 展示本次动作的核心内容及批准范围；本轮应用操作授权由执行器持有。
/// 关闭面板按未决定处理。
Future<ToolConfirmationOutcome> showToolConfirmationSheet(
  BuildContext context,
  ToolConfirmationRequest request,
) async {
  FocusManager.instance.primaryFocus?.unfocus();
  final outcome = await showModalBottomSheet<ToolConfirmationOutcome>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => ToolConfirmationSheet(request: request),
  );
  return outcome ?? ToolConfirmationOutcome.expired;
}

/// 等待确认的动作面板。
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
  late PermissionGrantScope _grantScope;

  @override
  void initState() {
    super.initState();
    _grantScope = widget.request.applicationOperationsForRun
        ? PermissionGrantScope.run
        : PermissionGrantScope.once;
    _remaining = _timeLeft();
    if (_remaining <= Duration.zero) {
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

  static String? _resolveSubtitle(ToolConfirmationRequest request) {
    final record = request.record;
    if (record.toolName == 'shell') {
      final summary = request.summary.trim();
      final firstLine = summary.split('\n').first.trim();
      if (firstLine.isNotEmpty && firstLine != '执行命令') {
        return firstLine;
      }
      return null;
    }
    if (record.source?.kind == ToolSourceKind.mcp) {
      return 'MCP · ${record.source?.originalName ?? record.target ?? "远程工具"}';
    }
    final label = ToolPresentation.recordLabel(record);
    final summary = request.summary.trim();
    if (summary.isEmpty || summary == label) return null;
    if (summary.startsWith('$label ') || summary.startsWith('$label：')) {
      final stripped = summary.substring(label.length + 1).trim();
      return stripped.isNotEmpty ? stripped : null;
    }
    final firstLine = summary.split('\n').first.trim();
    return (firstLine.isNotEmpty && firstLine != label) ? firstLine : null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final record = widget.request.record;
    final subtitle = _resolveSubtitle(widget.request);

    return AppSheet(
      footerMaxHeightFactor: 0.35,
      title: ToolPresentation.recordLabel(record),
      titleWidget: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: colors.primaryContainer.withValues(alpha: 0.8),
              borderRadius: AppRadius.smallAll,
            ),
            alignment: Alignment.center,
            child: Icon(
              ToolPresentation.icon(record.toolName),
              size: 18,
              color: colors.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: AppSpacing.s),
          Flexible(
            child: Text(
              ToolPresentation.recordLabel(record),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      subtitle: subtitle,
      showClose: false,
      titleTrailing: Align(
        alignment: Alignment.centerRight,
        child: _CountdownBadge(
          remaining: _remaining,
          urgent: _remaining <= _urgent,
        ),
      ),
      footer: _ConfirmationFooter(grantScope: _grantScope, onDecide: _decide),
      child: ListView(
        key: const ValueKey('tool-confirmation-body'),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
        children: [
          if (widget.request.permission?.reason case final reason?)
            if (reason.isNotEmpty &&
                reason != '此操作需要本次确认' &&
                reason != '应用操作需要批准本次或本轮范围') ...[
              Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.s),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.m,
                  vertical: AppSpacing.s,
                ),
                decoration: BoxDecoration(
                  color: colors.tertiaryContainer.withValues(alpha: 0.5),
                  borderRadius: AppRadius.smallAll,
                ),
                child: Row(
                  children: [
                    Icon(
                      LucideIcons.info,
                      size: 15,
                      color: colors.onTertiaryContainer,
                    ),
                    const SizedBox(width: AppSpacing.s),
                    Expanded(
                      child: Text(
                        reason,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onTertiaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          _buildToolBody(record),
          if (widget.request.applicationOperationsForRun)
            _ScopeSelector(
              scope: _grantScope,
              decided: _decided,
              onChanged: (scope) => setState(() => _grantScope = scope),
            ),
          const SizedBox(height: AppSpacing.m),
        ],
      ),
    );
  }

  Widget _buildToolBody(ToolCallRecord record) {
    return switch (record.toolName) {
      'shell' => _ShellCommandCard(
        command: record.arguments['command'] as String? ?? '',
        cwd: record.arguments['cwd'] as String?,
        timeout: record.arguments['timeout'] as num?,
      ),
      'write_file' || 'edit_file' => _FileOperationCard(record: record),
      'http_request' => _HttpRequestCard(record: record),
      _ => _GenericParameterList(record: record),
    };
  }
}

/// 倒计时胶囊标签。
class _CountdownBadge extends StatelessWidget {
  const _CountdownBadge({required this.remaining, required this.urgent});

  final Duration remaining;
  final bool urgent;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final bg = urgent ? colors.errorContainer : colors.surfaceContainerHighest;
    final fg = urgent ? colors.onErrorContainer : colors.onSurfaceVariant;

    return Container(
      key: const ValueKey('tool-confirmation-countdown'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(color: bg, borderRadius: AppRadius.smallAll),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.timer, size: 14, color: fg),
          const SizedBox(width: AppSpacing.xs),
          Text(
            '剩余 ${remaining.inSeconds} 秒',
            maxLines: 1,
            style: theme.textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// 终端命令展示卡片。
class _ShellCommandCard extends StatelessWidget {
  const _ShellCommandCard({required this.command, this.cwd, this.timeout});

  final String command;
  final String? cwd;
  final num? timeout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final terminalBg = isDark
        ? colors.surfaceContainerHigh
        : const Color(0xFF1E2433);
    final terminalFg = isDark ? colors.onSurface : const Color(0xFFE2E8F0);
    final metaFg = isDark ? colors.onSurfaceVariant : const Color(0xFF94A3B8);

    return Container(
      decoration: BoxDecoration(
        color: terminalBg,
        borderRadius: AppRadius.mediumAll,
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: isDark ? 0.35 : 0.2),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.m,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest.withValues(
                alpha: isDark ? 0.4 : 0.15,
              ),
              border: Border(
                bottom: BorderSide(
                  color: colors.outlineVariant.withValues(
                    alpha: isDark ? 0.25 : 0.15,
                  ),
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(LucideIcons.terminal, size: 15, color: colors.primary),
                const SizedBox(width: AppSpacing.s),
                if (cwd != null && cwd!.isNotEmpty) ...[
                  Icon(LucideIcons.folder, size: 13, color: metaFg),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      cwd!,
                      key: const ValueKey('tool-parameter-cwd'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontFamily: 'monospace',
                        color: metaFg,
                      ),
                    ),
                  ),
                ] else
                  const Spacer(),
                IconButton(
                  tooltip: '复制命令',
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  padding: EdgeInsets.zero,
                  icon: Icon(LucideIcons.copy, size: 15, color: metaFg),
                  onPressed: () => _copyText(context, command, '复制命令'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.m),
            child: SelectableText(
              command,
              key: const ValueKey('tool-parameter-command'),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: 'monospace',
                fontSize: 13.5,
                height: 1.5,
                color: terminalFg,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (timeout != null)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.m,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: colors.outlineVariant.withValues(
                      alpha: isDark ? 0.2 : 0.1,
                    ),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.clock, size: 13, color: metaFg),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    '超时：$timeout 秒',
                    key: const ValueKey('tool-parameter-timeout'),
                    style: theme.textTheme.labelSmall?.copyWith(color: metaFg),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// 文件操作卡片（读、写、编辑）。
class _FileOperationCard extends StatelessWidget {
  const _FileOperationCard({required this.record});

  final ToolCallRecord record;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final args = record.arguments;
    final path = (args['path'] as String?) ?? (record.target ?? '');
    final content = args['content'] as String?;
    final edits = args['edits'] as List?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.m,
            vertical: AppSpacing.s,
          ),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHigh.withValues(alpha: 0.7),
            borderRadius: AppRadius.smallAll,
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            children: [
              Icon(
                record.toolName == 'write_file'
                    ? LucideIcons.filePlus
                    : LucideIcons.filePen,
                size: 16,
                color: colors.primary,
              ),
              const SizedBox(width: AppSpacing.s),
              Expanded(
                child: SelectableText(
                  path,
                  key: const ValueKey('tool-parameter-path'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                tooltip: '复制路径',
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
                icon: const Icon(LucideIcons.copy, size: 15),
                onPressed: () => _copyText(context, path, '复制路径'),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s),
        if (content != null) ...[
          Container(
            decoration: BoxDecoration(
              color: colors.surfaceContainerHigh.withValues(alpha: 0.5),
              borderRadius: AppRadius.smallAll,
              border: Border.all(
                color: colors.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.m,
                    AppSpacing.xs,
                    AppSpacing.s,
                    AppSpacing.xs,
                  ),
                  child: Row(
                    children: [
                      Text(
                        '写入内容（${content.length} 字符）',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: '复制内容',
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        padding: EdgeInsets.zero,
                        icon: const Icon(LucideIcons.copy, size: 14),
                        onPressed: () => _copyText(context, content, '复制内容'),
                      ),
                    ],
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 240),
                  child: SingleChildScrollView(
                    primary: false,
                    padding: const EdgeInsets.all(AppSpacing.m),
                    child: SelectableText(
                      content,
                      key: const ValueKey('tool-parameter-content'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        height: 1.45,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ] else if (edits != null && edits.isNotEmpty) ...[
          if (edits.every(
            (e) =>
                e is Map<String, dynamic> &&
                e['oldText'] is String &&
                e['newText'] is String,
          )) ...[
            Container(
              decoration: BoxDecoration(
                color: colors.surfaceContainerHigh.withValues(alpha: 0.5),
                borderRadius: AppRadius.smallAll,
                border: Border.all(
                  color: colors.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.m,
                      AppSpacing.xs,
                      AppSpacing.s,
                      AppSpacing.xs,
                    ),
                    child: Text(
                      '文本替换（${edits.length} 处）',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 240),
                    child: SingleChildScrollView(
                      primary: false,
                      child: ToolDiffView(
                        lines: toolEditDiff(edits.cast<Map<String, dynamic>>()),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            SelectableText(
              const JsonEncoder.withIndent('  ').convert(edits),
              key: const ValueKey('tool-parameter-edits'),
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
          ],
        ],
      ],
    );
  }
}

/// HTTP 请求卡片。
class _HttpRequestCard extends StatelessWidget {
  const _HttpRequestCard({required this.record});

  final ToolCallRecord record;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final args = record.arguments;
    final method = (args['method'] as String? ?? 'GET').toUpperCase();
    final url = args['url'] as String? ?? '';
    final headers = args['headers'];
    final body = args['body'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.s),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHigh.withValues(alpha: 0.7),
            borderRadius: AppRadius.smallAll,
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppBadge(
                label: method,
                tone: method == 'GET'
                    ? AppTone.teal
                    : method == 'POST'
                    ? AppTone.primary
                    : AppTone.lavender,
              ),
              const SizedBox(width: AppSpacing.s),
              Expanded(
                child: SelectableText(
                  url,
                  key: const ValueKey('tool-parameter-url'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                tooltip: '复制 URL',
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
                icon: const Icon(LucideIcons.copy, size: 15),
                onPressed: () => _copyText(context, url, '复制 URL'),
              ),
            ],
          ),
        ),
        Opacity(
          opacity: 0,
          child: SizedBox(
            height: 0,
            child: SelectableText(
              method,
              key: const ValueKey('tool-parameter-method'),
            ),
          ),
        ),
        if (headers != null) ...[
          const SizedBox(height: AppSpacing.s),
          _CodeParameterBlock(
            label: '请求头',
            name: 'headers',
            value: headers is String
                ? headers
                : const JsonEncoder.withIndent('  ').convert(headers),
          ),
        ],
        if (body != null && body.toString().isNotEmpty) ...[
          const SizedBox(height: AppSpacing.s),
          _CodeParameterBlock(
            label: '请求正文',
            name: 'body',
            value: body is String
                ? body
                : const JsonEncoder.withIndent('  ').convert(body),
          ),
        ],
      ],
    );
  }
}

/// 通用/兜底参数列表。
class _GenericParameterList extends StatelessWidget {
  const _GenericParameterList({required this.record});

  final ToolCallRecord record;

  @override
  Widget build(BuildContext context) {
    final details = ToolPresentation.parameterDetails(record)
        .where((d) => d.value != '（未提供）')
        .toList();

    if (details.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.m),
        child: Center(
          child: Text(
            '该操作无需额外参数',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final detail in details) ...[
          if (detail.multiline)
            _CodeParameterBlock(
              label: detail.label,
              name: detail.name,
              value: detail.value,
            )
          else
            _SingleLineParamBlock(detail: detail),
          const SizedBox(height: AppSpacing.s),
        ],
      ],
    );
  }
}

/// 单行参数块。
class _SingleLineParamBlock extends StatelessWidget {
  const _SingleLineParamBlock({required this.detail});

  final ToolParameterDetail detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.m,
        vertical: AppSpacing.s,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh.withValues(alpha: 0.5),
        borderRadius: AppRadius.smallAll,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${detail.label}：',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          Expanded(
            child: SelectableText(
              detail.value,
              key: ValueKey('tool-parameter-${detail.name}'),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 代码或长正文参数展示块。
class _CodeParameterBlock extends StatelessWidget {
  const _CodeParameterBlock({
    required this.label,
    required this.name,
    required this.value,
  });

  final String label;
  final String name;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh.withValues(alpha: 0.5),
        borderRadius: AppRadius.smallAll,
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.m,
              AppSpacing.xs,
              AppSpacing.s,
              AppSpacing.xs,
            ),
            child: Row(
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: '复制$label',
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  padding: EdgeInsets.zero,
                  icon: const Icon(LucideIcons.copy, size: 14),
                  onPressed: () => _copyText(context, value, '复制$label'),
                ),
              ],
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200),
            child: SingleChildScrollView(
              primary: false,
              padding: const EdgeInsets.all(AppSpacing.m),
              child: SelectableText(
                value,
                key: ValueKey('tool-parameter-$name'),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  height: 1.45,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 授权范围选择器（分段控件）。
class _ScopeSelector extends StatelessWidget {
  const _ScopeSelector({
    required this.scope,
    required this.decided,
    required this.onChanged,
  });

  final PermissionGrantScope scope;
  final bool decided;
  final ValueChanged<PermissionGrantScope> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.m),
      padding: const EdgeInsets.all(AppSpacing.s),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh.withValues(alpha: 0.5),
        borderRadius: AppRadius.mediumAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.xs,
              bottom: AppSpacing.xs,
            ),
            child: Row(
              children: [
                Icon(LucideIcons.shield, size: 14, color: colors.primary),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  '授权范围',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<PermissionGrantScope>(
              segments: const [
                ButtonSegment(
                  value: PermissionGrantScope.once,
                  label: Text('仅本次'),
                  icon: Icon(LucideIcons.shieldAlert, size: 16),
                ),
                ButtonSegment(
                  value: PermissionGrantScope.run,
                  label: Text('本轮均允许'),
                  icon: Icon(LucideIcons.shieldCheck, size: 16),
                ),
              ],
              selected: {scope},
              onSelectionChanged: decided
                  ? null
                  : (selected) {
                      if (selected.isNotEmpty) {
                        onChanged(selected.first);
                      }
                    },
            ),
          ),
        ],
      ),
    );
  }
}

/// 底部操作栏。
class _ConfirmationFooter extends StatelessWidget {
  const _ConfirmationFooter({required this.grantScope, required this.onDecide});

  final PermissionGrantScope grantScope;
  final ValueChanged<ToolConfirmationOutcome> onDecide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final allowLabel = grantScope == PermissionGrantScope.run
        ? '允许本轮操作应用'
        : '允许一次';

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 330) {
          return Row(
            children: [
              OutlinedButton.icon(
                key: const ValueKey('tool-confirm-stop'),
                onPressed: () => onDecide(ToolConfirmationOutcome.stopTask),
                icon: const Icon(LucideIcons.circleStop, size: 15),
                label: const Text('停止任务'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.error,
                  side: BorderSide(color: colors.error.withValues(alpha: 0.5)),
                  minimumSize: const Size(48, 48),
                ),
              ),
              const Spacer(),
              OutlinedButton(
                key: const ValueKey('tool-confirm-reject'),
                onPressed: () => onDecide(ToolConfirmationOutcome.reject),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(68, 48),
                ),
                child: const Text('拒绝'),
              ),
              const SizedBox(width: AppSpacing.s),
              FilledButton.icon(
                key: const ValueKey('tool-confirm-allow'),
                onPressed: () => onDecide(
                  grantScope == PermissionGrantScope.run
                      ? ToolConfirmationOutcome.allowApplicationOperationsForRun
                      : ToolConfirmationOutcome.allowOnce,
                ),
                icon: Icon(
                  grantScope == PermissionGrantScope.run
                      ? LucideIcons.shieldCheck
                      : LucideIcons.check,
                  size: 16,
                ),
                label: Text(allowLabel),
                style: FilledButton.styleFrom(minimumSize: const Size(88, 48)),
              ),
            ],
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const ValueKey('tool-confirm-reject'),
                    onPressed: () => onDecide(ToolConfirmationOutcome.reject),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                    child: const Text('拒绝'),
                  ),
                ),
                const SizedBox(width: AppSpacing.s),
                Expanded(
                  child: FilledButton.icon(
                    key: const ValueKey('tool-confirm-allow'),
                    onPressed: () => onDecide(
                      grantScope == PermissionGrantScope.run
                          ? ToolConfirmationOutcome
                                .allowApplicationOperationsForRun
                          : ToolConfirmationOutcome.allowOnce,
                    ),
                    icon: Icon(
                      grantScope == PermissionGrantScope.run
                          ? LucideIcons.shieldCheck
                          : LucideIcons.check,
                      size: 16,
                    ),
                    label: Text(allowLabel),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            OutlinedButton.icon(
              key: const ValueKey('tool-confirm-stop'),
              onPressed: () => onDecide(ToolConfirmationOutcome.stopTask),
              icon: const Icon(LucideIcons.circleStop, size: 15),
              label: const Text('停止任务'),
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.error,
                side: BorderSide(color: colors.error.withValues(alpha: 0.5)),
                minimumSize: const Size(0, 44),
              ),
            ),
          ],
        );
      },
    );
  }
}

Future<void> _copyText(BuildContext context, String text, String label) async {
  String feedback;
  try {
    await Clipboard.setData(ClipboardData(text: text));
    feedback = '已$label';
  } on PlatformException {
    feedback = '复制失败，请重试';
  }
  if (!context.mounted) return;
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(buildAppSnackBar(content: Text(feedback)));
}
