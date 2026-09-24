import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/datasources/local/model_catalog_cache.dart';
import '../../../data/models/model_catalog.dart';
import '../../../data/models/model_request_record.dart';
import '../../../data/repositories/model_request_repository.dart';
import '../chat_controller.dart';
import '../model_selection.dart';
import '../usage/usage_panel.dart';
import 'context_builder.dart';
import 'context_meter.dart';
import 'context_preview.dart';

/// 上下文占用不是 API 累计消耗；缓存统计仅在展开时订阅。
class ContextUsageIndicator extends ConsumerStatefulWidget {
  const ContextUsageIndicator({
    required this.conversationId,
    this.submitting = false,
    super.key,
  });

  static const diameter = 40 * 2 / 3;
  final String? conversationId;
  final bool submitting;

  @override
  ConsumerState<ContextUsageIndicator> createState() =>
      _ContextUsageIndicatorState();
}

class _ContextUsageIndicatorState extends ConsumerState<ContextUsageIndicator> {
  final _overlay = OverlayPortalController();
  LocalHistoryEntry? _history;
  ContextMeasurement? _displayed;
  late bool _empty = widget.conversationId == null;

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
    if (oldWidget.conversationId != widget.conversationId) {
      // 首次发送从草稿接管新会话时，保留同一个 0% 基线到本轮结束。
      final running = ref.read(chatControllerProvider);
      final adopting =
          oldWidget.conversationId == null &&
          widget.submitting &&
          (!running.isGenerating ||
              running.runningConversationId == widget.conversationId);
      if (!adopting) {
        _displayed = null;
        _empty = widget.conversationId == null;
      }
      _close();
    }
  }

  @override
  void dispose() {
    _removeHistory();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.conversationId;
    final preview = id == null
        ? const AsyncData<ContextBuild?>(null)
        : ref.watch(contextPreviewProvider(id));
    final running = ref.watch(
      chatControllerProvider.select(
        (s) => (s.isGenerating, s.runningConversationId),
      ),
    );
    final generatingHere = running.$1 && running.$2 == id;
    final frozen = generatingHere || (widget.submitting && !running.$1);
    final measured = preview.isLoading || preview.hasError
        ? null
        : preview.value?.measurement;
    // 请求开始时 controller 会清空计量，工具轮之间也会换测量；这些都不重置圆环。
    if (!frozen && measured != null) {
      _displayed = measured;
      _empty = false;
    } else if (frozen && !_empty && _displayed == null && measured != null) {
      // 中途首次进入运行中的会话，只采用第一份可用快照，随后冻结。
      _displayed = measured;
    }
    final measurement = _displayed;
    final ratio = _empty
        ? 0.0
        : measurement == null || measurement.windowTokens <= 0
        ? null
        : measurement.estimatedInputTokens / measurement.windowTokens;
    final label = _percentage(ratio);
    final colors = Theme.of(context).colorScheme;
    final diameter = math.max(
      ContextUsageIndicator.diameter,
      MediaQuery.textScalerOf(context).scale(ContextUsageIndicator.diameter),
    );
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
            240.0,
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
          final left = (anchor.center.dx - width / 2).clamp(
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
                      padding: const EdgeInsets.all(AppSpacing.m),
                      child: _ContextUsageDetails(
                        conversationId: widget.conversationId,
                        measurement: measurement,
                        empty: _empty,
                        failed: preview.hasError,
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
          value: _empty
              ? '0%'
              : measurement == null
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
                child: TweenAnimationBuilder<double>(
                  key: ValueKey(id),
                  tween: Tween(begin: ratio ?? 0, end: ratio ?? 0),
                  duration: AppMotion.reduce(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 360),
                  curve: Curves.easeInOutCubic,
                  builder: (context, value, _) => Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(
                        child: CircularProgressIndicator(
                          value: value.clamp(0.0, 1.0),
                          strokeWidth: 6,
                          strokeAlign: 0,
                          strokeCap: StrokeCap.round,
                          color: ratio != null && ratio >= 1
                              ? colors.error
                              : colors.primary,
                          backgroundColor: colors.outlineVariant,
                        ),
                      ),
                      Text(
                        _percentage(ratio == null ? null : value),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontSize: 11 * 2 / 3,
                          height: 1,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
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

String _percentage(double? ratio) {
  if (ratio == null) return '—';
  if (ratio > 0 && ratio < .01) return '<1%';
  return '${(ratio * 100).round()}%';
}

class _ContextUsageDetails extends ConsumerWidget {
  const _ContextUsageDetails({
    required this.conversationId,
    required this.measurement,
    required this.empty,
    required this.failed,
  });

  final String? conversationId;
  final ContextMeasurement? measurement;
  final bool empty;
  final bool failed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final id = conversationId;
    final requests = id == null
        ? const AsyncData<List<ModelRequestRecord>>([])
        : ref.watch(conversationRequestsProvider(id));
    var window = measurement?.windowTokens;
    if (empty) {
      final selection = ref.watch(modelSelectionProvider).value;
      if (selection != null) {
        final model = selection.profile.models
            .where((model) => model.id == selection.model)
            .firstOrNull;
        window = resolveContextLimits(
          presetId: selection.profile.presetId,
          modelId: selection.model,
          userContextWindow: model?.contextWindow,
          userMaxOutputTokens: model?.maxOutputTokens,
          catalog: ref.watch(modelCatalogProvider).value ?? ModelCatalog.empty,
        ).contextWindow;
      }
    }
    final unavailable = failed ? '暂不可用' : '待估算';
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
    return DefaultTextStyle(
      style: theme.textTheme.bodySmall!,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('上下文用量', style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.s),
          _Metric(
            label: '已占用上下文',
            value: empty
                ? '0 token'
                : measurement == null
                ? unavailable
                : '≈${measurement!.estimatedInputTokens} token',
          ),
          _Metric(
            label: '总上下文',
            value: window == null ? unavailable : '$window token',
          ),
          Semantics(
            label: totals == null
                ? null
                : '缓存用量覆盖 ${totals.cacheRequests.length}/${totals.requestCount} 次请求',
            child: _Metric(label: '缓存命中率', value: cacheLabel),
          ),
        ],
      ),
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
