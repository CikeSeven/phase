import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/models/model_catalog.dart';
import '../../../data/models/model_request_record.dart';
import '../../../data/repositories/model_request_repository.dart';
import '../usage/usage_panel.dart';
import 'context_builder.dart';
import 'context_preview.dart';

/// 上下文占用不是 API 累计消耗；缓存统计仅在展开时订阅。
class ContextUsageIndicator extends ConsumerStatefulWidget {
  const ContextUsageIndicator({required this.conversationId, super.key});

  final String conversationId;

  @override
  ConsumerState<ContextUsageIndicator> createState() =>
      _ContextUsageIndicatorState();
}

class _ContextUsageIndicatorState extends ConsumerState<ContextUsageIndicator> {
  final _overlay = OverlayPortalController();
  LocalHistoryEntry? _history;

  void _removeHistory() {
    final entry = _history;
    _history = null;
    entry?.remove();
  }

  void _close() {
    _overlay.hide();
    _removeHistory();
    if (mounted) setState(() {});
  }

  void _toggle() {
    if (_overlay.isShowing) {
      _close();
      return;
    }
    final route = ModalRoute.of(context);
    if (route != null) {
      late final LocalHistoryEntry entry;
      entry = LocalHistoryEntry(
        impliesAppBarDismissal: false,
        onRemove: () {
          if (_history == entry) {
            _history = null;
            _close();
          }
        },
      );
      _history = entry;
      route.addLocalHistoryEntry(entry);
    }
    setState(_overlay.show);
  }

  @override
  void didUpdateWidget(ContextUsageIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.conversationId != widget.conversationId) _close();
  }

  @override
  void dispose() {
    _removeHistory();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final preview = ref.watch(contextPreviewProvider(widget.conversationId));
    // 配置或分支改变后不用 AsyncValue 保留的旧估算冒充当前值。
    final measurement = preview.isLoading || preview.hasError
        ? null
        : preview.value?.measurement;
    final ratio = measurement == null || measurement.windowTokens <= 0
        ? null
        : measurement.estimatedInputTokens / measurement.windowTokens;
    final label = ratio == null ? '—' : '${(ratio * 100).round()}%';
    final colors = Theme.of(context).colorScheme;
    final diameter = math.max(40.0, MediaQuery.textScalerOf(context).scale(40));
    return TextFieldTapRegion(
      child: OverlayPortal.overlayChildLayoutBuilder(
        controller: _overlay,
        overlayChildBuilder: (context, info) {
          final media = MediaQuery.of(context);
          final anchor = MatrixUtils.transformRect(
            info.childPaintTransform,
            Offset.zero & info.childSize,
          );
          final width = math.min(
            288.0,
            info.overlaySize.width - media.padding.horizontal - AppSpacing.xl,
          );
          final bottom = math.min(
            anchor.top - AppSpacing.s,
            info.overlaySize.height - media.viewInsets.bottom,
          );
          final height = math.max(
            0.0,
            bottom - media.padding.top - AppSpacing.m,
          );
          final left = (anchor.right - width).clamp(
            media.padding.left + AppSpacing.m,
            info.overlaySize.width - media.padding.right - AppSpacing.m - width,
          );
          return Stack(
            children: [
              Positioned.fill(
                child: ModalBarrier(
                  onDismiss: _close,
                  semanticsLabel: '关闭上下文用量',
                ),
              ),
              Positioned(
                left: left,
                width: width,
                bottom: info.overlaySize.height - bottom,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: height),
                  child: Material(
                    key: const ValueKey('context-usage-popover'),
                    color: colors.surfaceContainer,
                    elevation: 4,
                    shadowColor: colors.shadow.withValues(alpha: 0.2),
                    borderRadius: AppRadius.controlAll,
                    clipBehavior: Clip.antiAlias,
                    child: SingleChildScrollView(
                      primary: false,
                      padding: const EdgeInsets.all(AppSpacing.l),
                      child: _ContextUsageDetails(
                        conversationId: widget.conversationId,
                        preview: preview,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
        child: Semantics(
          label: '上下文占用',
          value: measurement == null
              ? preview.hasError
                    ? '暂不可用'
                    : '待估算'
              : '预计 $label，已占用约 ${measurement.estimatedInputTokens} token，'
                    '${_windowSourceLabel(measurement.windowSource)} ${measurement.windowTokens} token',
          expanded: _overlay.isShowing,
          child: TextButton(
            key: const ValueKey('chat-context-usage'),
            onPressed: _toggle,
            style: TextButton.styleFrom(
              foregroundColor: colors.onSurfaceVariant,
              minimumSize: const Size.square(48),
              padding: const EdgeInsets.all(AppSpacing.xs),
            ),
            child: ExcludeSemantics(
              child: SizedBox.square(
                dimension: diameter,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                      child: CircularProgressIndicator(
                        // 未知时只画静态轨道，不伪造零占用或持续转圈。
                        value: ratio?.clamp(0.0, 1.0) ?? 0,
                        strokeWidth: 3,
                        strokeCap: StrokeCap.round,
                        color: ratio != null && ratio >= 1
                            ? colors.error
                            : colors.primary,
                        backgroundColor: colors.outlineVariant,
                      ),
                    ),
                    Text(label, style: Theme.of(context).textTheme.labelSmall),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _windowSourceLabel(ContextWindowSource source) => switch (source) {
  ContextWindowSource.user => '用户配置窗口',
  ContextWindowSource.catalog => 'models.dev 目录窗口',
  ContextWindowSource.localDefault => '本地默认窗口',
};

class _ContextUsageDetails extends ConsumerWidget {
  const _ContextUsageDetails({
    required this.conversationId,
    required this.preview,
  });

  final String conversationId;
  final AsyncValue<ContextBuild?> preview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final requests = ref.watch(conversationRequestsProvider(conversationId));
    final measurement = preview.isLoading || preview.hasError
        ? null
        : preview.value?.measurement;
    final unavailable = preview.hasError ? '暂不可用' : '待估算';
    final totals = requests.isLoading || requests.hasError
        ? null
        : RequestUsageTotals(requests.value ?? []);
    final cacheLabel = requests.hasError
        ? '读取失败'
        : totals == null
        ? '读取中…'
        : totals.cacheRequests.isEmpty
        ? '未提供'
        : cacheRateLabel(totals.cacheHitRate);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('上下文用量', style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.m),
        _Metric(
          label: '已占用上下文',
          value: measurement == null
              ? unavailable
              : '≈${measurement.estimatedInputTokens} token',
        ),
        _Metric(
          label: '总上下文',
          value: measurement == null
              ? unavailable
              : '${measurement.windowTokens} token',
        ),
        _Metric(label: '缓存命中率', value: cacheLabel),
        const SizedBox(height: AppSpacing.s),
        DefaultTextStyle(
          style: theme.textTheme.bodySmall!.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (measurement != null)
                Text(_windowSourceLabel(measurement.windowSource)),
              const Text('预计输入，不含未发送草稿'),
              if (totals != null)
                Text(
                  '本会话缓存统计 · 覆盖 ${totals.cacheRequests.length}/${totals.requestCount} 次请求',
                ),
              if (totals != null &&
                  !totals.completeCacheCoverage &&
                  totals.requestCount > 0)
                Text(totals.includesPending ? '包含进行中请求，统计未收口' : '部分请求未提供缓存用量'),
            ],
          ),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.s),
    child: SizedBox(
      width: double.infinity,
      child: Wrap(
        spacing: AppSpacing.m,
        runSpacing: AppSpacing.xs,
        alignment: WrapAlignment.spaceBetween,
        children: [Text(label), Text(value)],
      ),
    ),
  );
}
