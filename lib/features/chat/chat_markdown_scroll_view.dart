import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'chat_horizontal_drag_priority.dart';

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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final behavior = ScrollConfiguration.of(context);
    return ScrollConfiguration(
      behavior: behavior.copyWith(
        scrollbars: false,
        // 默认不接受鼠标拖动；横向阅读区统一允许直接拖动内容。
        dragDevices: {...behavior.dragDevices, PointerDeviceKind.mouse},
      ),
      child: ChatHorizontalDragRegion(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
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
}
