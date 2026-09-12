import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../core/theme/frosted_surface.dart';

/// 用户主动切换思考区时，由阅读区保留标题位置。
class ThinkingPanelToggleNotification extends Notification {
  const ThinkingPanelToggleNotification({required this.anchor});

  final BuildContext anchor;
}

/// 思考结束自动收起时通知阅读区：保留标题位置，但不像手动切换那样
/// 解除底部跟随。
class ThinkingPanelAutoCollapseNotification extends Notification {
  const ThinkingPanelAutoCollapseNotification({required this.anchor});

  final BuildContext anchor;
}

/// 真实思考内容默认展开，思考结束自动收起，手动选择优先保留。
class ThinkingPanel extends StatefulWidget {
  const ThinkingPanel({
    required this.reasoning,
    required this.streaming,
    super.key,
    this.duration,
  });

  final String reasoning;
  final bool streaming;

  /// 思考耗时（持久化在消息上）；未知时为 null，只显示「已思考」。
  final Duration? duration;

  @override
  State<ThinkingPanel> createState() => _ThinkingPanelState();
}

class _ThinkingPanelState extends State<ThinkingPanel>
    with AutomaticKeepAliveClientMixin {
  /// 展开内容的最大高度，超出部分内部滚动，不再无限撑开。
  static const _maxContentHeight = 260.0;

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
  late final DateTime _startedAt = DateTime.now();
  bool _expanded = true;
  bool _userToggled = false;

  /// 内部滚动跟随尾部：流式增量时停在最新内容；用户上翻则暂停跟随，
  /// 手动回到底部恢复。
  bool _followInner = true;
  Timer? _ticker;

  @override
  bool get wantKeepAlive => _userToggled;

  @override
  void initState() {
    super.initState();
    // 打开一条正在流式中的消息时，直接定位到最新内容底部。
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollInnerToEnd());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // initState 里不能读 MediaQuery，计时器在这里按依赖启停。
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant ThinkingPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.streaming && !widget.streaming) {
      _ticker?.cancel();
      _ticker = null;
      // 思考结束自动收起；用户手动操作过则以用户选择为准。
      if (!_userToggled) {
        final anchor = _headerKey.currentContext;
        if (anchor != null) {
          ThinkingPanelAutoCollapseNotification(anchor: anchor)
              .dispatch(context);
        }
        setState(() => _expanded = false);
      }
    }
    // 流式增量时跟随到最新思考内容底部。
    if (widget.streaming &&
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
    _innerController.dispose();
    super.dispose();
  }

  bool _onInnerScroll(ScrollNotification notification) {
    if (notification is UserScrollNotification) {
      if (notification.direction == ScrollDirection.reverse) {
        _followInner = false;
      }
    } else if (notification is ScrollEndNotification) {
      _followInner = notification.metrics.extentAfter <= 1;
    }
    return false;
  }

  /// 流式期间每秒刷新计时；disableAnimations 下保持静止（也避免
  /// pumpAndSettle 类等待永不稳定）。
  void _syncTicker() {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (widget.streaming && !reduce && _ticker == null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if ((!widget.streaming || reduce) && _ticker != null) {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  void _toggle() {
    ThinkingPanelToggleNotification(anchor: _headerKey.currentContext!)
        .dispatch(context);
    setState(() {
      _expanded = !_expanded;
      _userToggled = true;
    });
    updateKeepAlive();
  }

  String get _headerLabel {
    if (widget.streaming) {
      final elapsed = DateTime.now().difference(_startedAt);
      return '思考中… ${_formatDuration(elapsed)}';
    }
    final duration = widget.duration;
    return duration == null ? '已思考' : '已思考 ${_formatDuration(duration)}';
  }

  static String _formatDuration(Duration duration) {
    if (duration.inSeconds < 10) {
      return '${(duration.inMilliseconds / 1000).toStringAsFixed(1)} 秒';
    }
    return '${duration.inSeconds} 秒';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final brand = context.brandColors;
    return FrostedSurface(
      blur: 0,
      borderRadius: AppRadius.mediumAll,
      color: brand.lavenderContainer.withValues(
        alpha: theme.brightness == Brightness.dark ? 0.60 : 0.64,
      ),
      borderColor: brand.lavender.withValues(alpha: 0.24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            key: _headerKey,
            button: true,
            expanded: _expanded,
            child: InkWell(
              borderRadius: AppRadius.mediumAll,
              onTap: _toggle,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.m),
                  child: Row(
                    children: [
                      Icon(
                        Symbols.psychology,
                        size: 20,
                        color: brand.onLavenderContainer,
                      ),
                      const SizedBox(width: AppSpacing.s),
                      Expanded(
                        child: Text(
                          _headerLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: brand.onLavenderContainer,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s),
                      Icon(
                        _expanded ? Symbols.expand_less : Symbols.expand_more,
                        size: 20,
                        color: brand.onLavenderContainer,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.m,
                0,
                AppSpacing.m,
                AppSpacing.m,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: _maxContentHeight),
                child: NotificationListener<ScrollNotification>(
                  onNotification: _onInnerScroll,
                  child: SingleChildScrollView(
                    controller: _innerController,
                    primary: false,
                    child: Text(
                      _renderedReasoning,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: brand.onLavenderContainer,
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
