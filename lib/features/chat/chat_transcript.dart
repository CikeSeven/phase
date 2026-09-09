import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../data/models/chat_message.dart';
import 'message_bubble.dart';
import 'thinking_panel.dart';

/// 仓库消息的纯 UI 阅读区；用户回看时保持位置，靠近底部才跟随增量。
class ChatTranscript extends StatefulWidget {
  const ChatTranscript({
    required this.conversationId,
    required this.messages,
    super.key,
  });

  final String conversationId;
  final List<ChatMessage> messages;

  @override
  State<ChatTranscript> createState() => _ChatTranscriptState();
}

class _ChatTranscriptState extends State<ChatTranscript> {
  static const _bottomThreshold = 96.0;
  final _scrollController = ScrollController(keepScrollOffset: false);
  bool _followTail = true;
  bool _userScrolling = false;
  bool _reconcileScheduled = false;
  bool _programmaticScroll = false;
  bool _showReturnToBottom = false;
  ({BuildContext context, double y})? _readingAnchor;

  @override
  void initState() {
    super.initState();
    _scheduleReconcile();
  }

  @override
  void didUpdateWidget(covariant ChatTranscript oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.conversationId != widget.conversationId) {
      _readingAnchor = null;
      _followTail = true;
      _userScrolling = false;
      _showReturnToBottom = false;
    }
    _scheduleReconcile();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scheduleReconcile() {
    if (_reconcileScheduled) return;
    _reconcileScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reconcileScheduled = false;
      if (!mounted || !_scrollController.hasClients) return;
      final position = _scrollController.position;
      if (!position.hasContentDimensions) return;
      if (!_userScrolling) {
        var target = _followTail ? position.maxScrollExtent : position.pixels;
        final anchor = _readingAnchor;
        _readingAnchor = null;
        if (anchor != null && anchor.context.mounted) {
          final box = anchor.context.findRenderObject();
          if (box is RenderBox && box.attached && box.hasSize) {
            target =
                position.pixels + box.localToGlobal(Offset.zero).dy - anchor.y;
          }
        }
        target = target.clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        );
        if ((target - position.pixels).abs() > 0.5) {
          _programmaticScroll = true;
          _scrollController.jumpTo(target);
          _programmaticScroll = false;
          // 惰性列表的末端估算会在新行布局后修正，下一帧再对齐实际边界。
          _scheduleReconcile();
        }
      }
      final showButton =
          !_followTail && position.extentAfter > _bottomThreshold;
      if (showButton != _showReturnToBottom) {
        setState(() => _showReturnToBottom = showButton);
      }
    });
  }

  bool _onThinkingToggle(ThinkingPanelToggleNotification notification) {
    _followTail = false;
    _userScrolling = false;
    final box = notification.anchor.findRenderObject();
    _readingAnchor = box is RenderBox && box.attached && box.hasSize
        ? (context: notification.anchor, y: box.localToGlobal(Offset.zero).dy)
        : null;
    _scheduleReconcile();
    return true;
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0 || _programmaticScroll) return false;
    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      _readingAnchor = null;
      _userScrolling = true;
      _followTail = false;
    } else if (notification is UserScrollNotification &&
        notification.direction != ScrollDirection.idle) {
      _readingAnchor = null;
      _userScrolling = true;
      _followTail = false;
    } else if (notification is ScrollEndNotification && _userScrolling) {
      _userScrolling = false;
      _followTail = notification.metrics.extentAfter <= _bottomThreshold;
    }
    _scheduleReconcile();
    return false;
  }

  void _returnToBottom() {
    _readingAnchor = null;
    _followTail = true;
    _userScrolling = false;
    _scheduleReconcile();
    setState(() => _showReturnToBottom = false);
  }

  @override
  Widget build(BuildContext context) {
    final indices = {
      for (var index = 0; index < widget.messages.length; index++)
        ValueKey(widget.messages[index].id ?? 'message-$index'): index,
    };
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 840),
        child: Stack(
          fit: StackFit.expand,
          children: [
            NotificationListener<SizeChangedLayoutNotification>(
              onNotification: (_) {
                _scheduleReconcile();
                return false;
              },
              child: NotificationListener<ScrollMetricsNotification>(
                onNotification: (notification) {
                  if (notification.depth == 0) _scheduleReconcile();
                  return false;
                },
                child: NotificationListener<ScrollNotification>(
                  onNotification: _onScroll,
                  child: NotificationListener<ThinkingPanelToggleNotification>(
                    onNotification: _onThinkingToggle,
                    child: ListView.builder(
                      key: ValueKey('transcript-${widget.conversationId}'),
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.m,
                      ),
                      itemCount: widget.messages.length,
                      findChildIndexCallback: (key) => indices[key],
                      itemBuilder: (context, index) => MessageBubble(
                        key: ValueKey(
                          widget.messages[index].id ?? 'message-$index',
                        ),
                        message: widget.messages[index],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (_showReturnToBottom)
              Positioned(
                right: AppSpacing.l,
                bottom: AppSpacing.m,
                child: FilledButton.tonalIcon(
                  key: const ValueKey('chat-scroll-to-bottom'),
                  onPressed: _returnToBottom,
                  icon: const Icon(Symbols.arrow_downward),
                  label: const Text('回到底部'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
