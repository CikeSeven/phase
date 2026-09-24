import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../core/widgets/app_interactive_surface.dart';
import '../../../core/widgets/content_expansion_notification.dart';

/// 思考默认收起，用户主动展开后保留选择；计时来自消息，不从挂载时刻推算。
class ThinkingPanel extends StatefulWidget {
  const ThinkingPanel({
    required this.reasoning,
    required this.streaming,
    super.key,
    this.duration,
    this.startedAt,
  });

  final String reasoning;
  final bool streaming;

  /// 该段已结束的思考块耗时之和；未知时为 null，只显示「已思考」。
  final Duration? duration;

  /// 该段最后一个、仍在接收的思考块开始时间。
  final DateTime? startedAt;

  @override
  State<ThinkingPanel> createState() => _ThinkingPanelState();
}

class _ThinkingPanelState extends State<ThinkingPanel>
    with AutomaticKeepAliveClientMixin {
  /// 展开内容的最大高度，超出部分内部滚动，不再无限撑开。
  static const _maxContentHeight = 160.0;

  /// 超过这么多字才在流式期间只渲染尾部。
  ///
  /// 每帧重排的代价随文本长度线性增长（实测每千字约 0.55ms/帧，6 万字就是
  /// 30ms 以上，直接掉帧）；短思考照旧全文渲染，长思考在流式期间只保留
  /// 尾部一条，让每帧成本封顶。思考结束后恢复全文，回看不受影响。
  static const _windowThreshold = 6000;
  static const _streamingWindow = 2000;

  String get _renderedReasoning {
    final text = widget.reasoning;
    if (!widget.streaming || text.length <= _windowThreshold) return text;
    return '…${text.substring(text.length - _streamingWindow)}';
  }

  final _headerKey = GlobalKey();
  final _innerController = ScrollController();
  final _clock = ValueNotifier(DateTime.now());
  bool _expanded = false;
  bool _userToggled = false;

  /// 内部滚动跟随尾部：流式增量时停在最新内容；用户上翻则暂停跟随，
  /// 手动回到底部恢复。
  bool _followInner = true;
  Timer? _ticker;

  @override
  bool get wantKeepAlive => _userToggled;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // TickerMode 决定页面是否活跃，依赖变化后恢复时按真实时间补齐。
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant ThinkingPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 流式增量时跟随到最新思考内容底部。
    if (_expanded &&
        widget.streaming &&
        _followInner &&
        widget.reasoning != oldWidget.reasoning) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollInnerToEnd());
    }
    _syncTicker();
  }

  void _scrollInnerToEnd() {
    if (!mounted || !_innerController.hasClients) return;
    _innerController.jumpTo(_innerController.position.maxScrollExtent);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _clock.dispose();
    _innerController.dispose();
    super.dispose();
  }

  bool _onInnerScroll(ScrollNotification notification) {
    if (notification is OverscrollNotification) {
      _handOffOverscroll(notification);
    } else if (notification is UserScrollNotification) {
      if (notification.direction == ScrollDirection.reverse) {
        _followInner = false;
      }
    } else if (notification is ScrollEndNotification) {
      _followInner = notification.metrics.extentAfter <= 1;
    }
    return false;
  }

  /// 内层滚到边界后，把继续拖动的那一段位移交给外层消息列表。
  ///
  /// Flutter 的嵌套滚动不会自动接力：手指落在思考区里，这个手势就归内层所有，
  /// 内层到顶以后继续上滑只会卡住。这里把边界处的过卷量转给最近的祖先滚动
  /// 视图，于是「思考区滚到头 → 继续滚整条消息」是连贯的一个动作。
  void _handOffOverscroll(OverscrollNotification notification) {
    final outer = Scrollable.maybeOf(context)?.position;
    if (outer == null || !outer.hasContentDimensions) return;
    final offset = notification.overscroll;
    if (offset == 0) return;
    final target = (outer.pixels + offset).clamp(
      outer.minScrollExtent,
      outer.maxScrollExtent,
    );
    if ((target - outer.pixels).abs() < 0.5) return;
    outer.jumpTo(target);
  }

  /// 计时是实时状态，不随减少动画暂停；100ms 刷新只通知标题，不重建正文。
  void _syncTicker() {
    final running =
        widget.streaming &&
        widget.startedAt != null &&
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
    if (_expanded && widget.streaming && _followInner) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollInnerToEnd());
    }
  }

  String _headerLabel(DateTime now) {
    if (widget.streaming) {
      final started = widget.startedAt;
      if (started == null) return '思考中…';
      final elapsed =
          (widget.duration ?? Duration.zero) + now.difference(started);
      return '思考中… ${_formatDuration(elapsed)}';
    }
    final duration = widget.duration;
    return duration == null ? '已思考' : '已思考 ${_formatDuration(duration)}';
  }

  static String _formatDuration(Duration duration) {
    final seconds = duration.isNegative
        ? 0.0
        : duration.inMilliseconds / Duration.millisecondsPerSecond;
    return '${seconds.toStringAsFixed(1)} 秒';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final brand = context.brandColors;
    return Material(
      color: brand.tealContainer,
      borderRadius: AppRadius.mediumAll,
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            key: _headerKey,
            button: true,
            expanded: _expanded,
            child: AppInteractiveSurface(
              onTap: _toggle,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
                  child: Row(
                    children: [
                      Icon(
                        Symbols.cognition_rounded,
                        size: 18,
                        color: brand.onTealContainer,
                      ),
                      const SizedBox(width: AppSpacing.s),
                      Expanded(
                        child: ValueListenableBuilder<DateTime>(
                          valueListenable: _clock,
                          builder: (context, now, _) => Text(
                            _headerLabel(now),
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: brand.onTealContainer,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s),
                      Icon(
                        _expanded
                            ? Symbols.expand_less_rounded
                            : Symbols.expand_more_rounded,
                        size: 18,
                        color: brand.onTealContainer,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.only(
                bottom: AppSpacing.s,
                left: AppSpacing.m,
              ),
              child: Container(
                padding: const EdgeInsets.only(left: AppSpacing.m),
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: colors.outlineVariant),
                  ),
                ),
                constraints: const BoxConstraints(maxHeight: _maxContentHeight),
                child: NotificationListener<ScrollNotification>(
                  onNotification: _onInnerScroll,
                  child: SingleChildScrollView(
                    controller: _innerController,
                    primary: false,
                    child: Text(
                      _renderedReasoning,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
