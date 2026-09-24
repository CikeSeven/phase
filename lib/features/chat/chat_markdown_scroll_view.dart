import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';

/// 宽内容只在自己的阅读区域横滚，不借用聊天列表的主滚动控制器。
class ChatMarkdownScrollView extends StatefulWidget {
  const ChatMarkdownScrollView({
    required this.child,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  State<ChatMarkdownScrollView> createState() => _ChatMarkdownScrollViewState();
}

class _ChatMarkdownScrollViewState extends State<ChatMarkdownScrollView> {
  final _controller = ScrollController(keepScrollOffset: false);
  bool _overflow = false;
  bool _pendingOverflow = false;
  bool _scheduled = false;

  bool _onMetrics(ScrollMetricsNotification notification) {
    if (notification.depth != 0 ||
        notification.metrics.axis != Axis.horizontal) {
      return false;
    }
    _pendingOverflow = notification.metrics.maxScrollExtent > 0;
    if (!_scheduled && _pendingOverflow != _overflow) {
      _scheduled = true;
      // 滚动范围在布局结束后才确定，不能在布局期间更新滚动条状态。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scheduled = false;
        if (!mounted || _overflow == _pendingOverflow) return;
        setState(() => _overflow = _pendingOverflow);
      });
    }
    return false;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) =>
        NotificationListener<ScrollMetricsNotification>(
          onNotification: _onMetrics,
          child: Scrollbar(
            controller: _controller,
            thumbVisibility: _overflow,
            interactive: true,
            thickness: 3,
            radius: const Radius.circular(AppSpacing.xs),
            scrollbarOrientation: ScrollbarOrientation.bottom,
            child: SingleChildScrollView(
              controller: _controller,
              primary: false,
              scrollDirection: Axis.horizontal,
              padding: widget.padding,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: constraints.hasBoundedWidth
                      ? math.max(
                          0,
                          constraints.maxWidth - widget.padding.horizontal,
                        )
                      : 0,
                ),
                child: widget.child,
              ),
            ),
          ),
        ),
  );
}
