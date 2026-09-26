import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../core/widgets/app_expansion.dart';
import '../../../core/widgets/app_interactive_surface.dart';
import '../../../core/widgets/content_expansion_notification.dart';
import '../../../data/models/message_part.dart';

/// 同一段连续过程的总览；整组折叠不覆盖各张卡片的手动展开状态。
class ActivityCardGroup extends StatefulWidget {
  const ActivityCardGroup({
    required this.reasoningParts,
    required this.toolCallCount,
    required this.children,
    this.activeReasoningPart,
    this.fallbackThinkingDurationMs,
    super.key,
  });

  final List<ReasoningPart> reasoningParts;
  final ReasoningPart? activeReasoningPart;

  /// 仅在本组包含整条回答唯一的思考段且已结束时使用消息级计时。
  final int? fallbackThinkingDurationMs;

  final int toolCallCount;
  final List<Widget> children;

  @override
  State<ActivityCardGroup> createState() => _ActivityCardGroupState();
}

class _ActivityCardGroupState extends State<ActivityCardGroup>
    with AutomaticKeepAliveClientMixin {
  final _headerKey = GlobalKey();
  final _clock = ValueNotifier(DateTime.now());
  bool _expanded = false;
  bool _userToggled = false;
  Timer? _ticker;

  bool get _hasSummary => widget.children.length > 1;

  @override
  bool get wantKeepAlive => _userToggled;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant ActivityCardGroup oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTicker();
  }

  void _syncTicker() {
    final active = widget.activeReasoningPart;
    final running =
        _hasSummary &&
        active?.startedAt != null &&
        active?.durationMs == null &&
        TickerMode.valuesOf(context).enabled;
    if (!running) {
      _ticker?.cancel();
      _ticker = null;
      return;
    }
    _clock.value = DateTime.now();
    _ticker ??= Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted) _clock.value = DateTime.now();
    });
  }

  void _toggle() {
    ContentExpansionNotification(anchor: _headerKey.currentContext!)
        .dispatch(context);
    setState(() {
      _expanded = !_expanded;
      _userToggled = true;
    });
    updateKeepAlive();
  }

  int? _thinkingDurationMs(DateTime now) {
    var total = 0;
    for (final part in widget.reasoningParts) {
      final durationMs = part.durationMs;
      if (durationMs != null) {
        total += durationMs < 0 ? 0 : durationMs;
      } else if (identical(part, widget.activeReasoningPart) &&
          part.startedAt != null) {
        final elapsed = now.difference(part.startedAt!);
        total += elapsed.isNegative ? 0 : elapsed.inMilliseconds;
      } else {
        // 缺少任一段的计时就不把部分合计冒充总耗时。
        return widget.fallbackThinkingDurationMs;
      }
    }
    return total;
  }

  String _summaryLabel(DateTime now) {
    final labels = <String>[];
    if (widget.reasoningParts.isNotEmpty) {
      final durationMs = _thinkingDurationMs(now);
      if (durationMs == null) {
        labels.add(widget.activeReasoningPart == null ? '已思考' : '思考中…');
      } else {
        final seconds = durationMs < 0 ? 0.0 : durationMs / 1000;
        labels.add('共思考 ${seconds.toStringAsFixed(1)} 秒');
      }
    }
    if (widget.toolCallCount > 0) {
      labels.add('调用了 ${widget.toolCallCount} 个工具');
    }
    return labels.join('，');
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final brand = context.brandColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Material(
        color: brand.tealContainer,
        borderRadius: AppRadius.mediumAll,
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_hasSummary)
              Semantics(
                key: _headerKey,
                expanded: _expanded,
                child: AppInteractiveSurface(
                  color: brand.tealContainer,
                  radius: 0,
                  animateShape: false,
                  onTap: _toggle,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.m,
                      vertical: AppSpacing.s,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          widget.reasoningParts.isEmpty
                              ? Symbols.build_rounded
                              : Symbols.cognition_rounded,
                          size: 18,
                          color: brand.onTealContainer,
                        ),
                        const SizedBox(width: AppSpacing.s),
                        Expanded(
                          child: ValueListenableBuilder<DateTime>(
                            valueListenable: _clock,
                            builder: (context, now, _) => Text(
                              _summaryLabel(now),
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: brand.onTealContainer,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s),
                        AppExpansionArrow(
                          expanded: _expanded,
                          color: brand.onTealContainer,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            // 单卡直接显示；固定详情身份，追加成多卡组也不重建原卡片。
            AppExpansionBody(
              key: const ValueKey('activity-details'),
              expanded: !_hasSummary || _expanded,
              builder: (context) => _ActivityCardContents(
                expanded: !_hasSummary || _expanded,
                hasSummary: _hasSummary,
                children: widget.children,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 主体先展开，最后一段再拉开间距；只改变卡片之间的空间，不重建卡片。
class _ActivityCardContents extends StatefulWidget {
  const _ActivityCardContents({
    required this.expanded,
    required this.hasSummary,
    required this.children,
  });

  final bool expanded;
  final bool hasSummary;
  final List<Widget> children;

  @override
  State<_ActivityCardContents> createState() => _ActivityCardContentsState();
}

class _ActivityCardContentsState extends State<_ActivityCardContents>
    with SingleTickerProviderStateMixin {
  late final _spacing = AnimationController(
    vsync: this,
    value: widget.hasSummary ? 0 : 1,
  );
  bool _initialized = false;
  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = AppMotion.reduce(context);
    if (!_initialized || reduced != _reduceMotion) {
      _initialized = true;
      _reduceMotion = reduced;
      _animateSpacing();
    }
  }

  @override
  void didUpdateWidget(covariant _ActivityCardContents oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.expanded != oldWidget.expanded) _animateSpacing();
  }

  void _animateSpacing() {
    final target = widget.expanded ? 1.0 : 0.0;
    if (_reduceMotion) {
      _spacing.value = target;
    } else if (widget.expanded) {
      _spacing.animateTo(
        target,
        duration: AppMotion.expansionOpen,
        curve: AppMotion.expansionSpacingCurve,
      );
    } else {
      _spacing.animateBack(
        target,
        duration: AppMotion.expansionClose,
        curve: AppMotion.expansionCurve,
      );
    }
  }

  @override
  void dispose() {
    _spacing.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brand = context.brandColors;
    final colors = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _spacing,
      builder: (context, _) {
        final gap = AppSpacing.xs / 2 * _spacing.value;
        return ColoredBox(
          color: Color.lerp(
            brand.tealContainer,
            colors.surface,
            _spacing.value,
          )!,
          child: Padding(
            padding: EdgeInsets.only(top: widget.hasSummary ? gap : 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: gap,
              children: widget.children,
            ),
          ),
        );
      },
    );
  }
}
