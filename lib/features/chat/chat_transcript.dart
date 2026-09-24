import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/content_expansion_notification.dart';
import '../../../data/models/attachment.dart';
import '../../../data/models/chat_message.dart';
import 'chat_return_to_bottom_button.dart';
import 'message_bubble.dart';

/// 一条消息的气泡缓存项：记录生成它时的输入，用于判断能否复用。
class _BubbleEntry {
  const _BubbleEntry({
    required this.message,
    required this.attachments,
    required this.canRegenerate,
    required this.onRegenerate,
    required this.widget,
  });

  final ChatMessage message;
  final Map<String, Attachment> attachments;
  final bool canRegenerate;
  final Future<void> Function()? onRegenerate;
  final Widget widget;
}

/// 仓库消息的纯 UI 阅读区；用户回看时保持位置，靠近底部才跟随增量。
class ChatTranscript extends StatefulWidget {
  const ChatTranscript({
    required this.conversationId,
    required this.messages,
    super.key,
    this.attachments = const {},
    this.onRegenerate,
    this.isGenerating = false,
    this.topPadding = 0,
    this.bottomPadding = 0,
  });

  final String conversationId;
  final List<ChatMessage> messages;

  /// 会话附件索引，随消息的 Part 引用还原成文件。
  final Map<String, Attachment> attachments;

  /// 重新生成最后一条回答；生成中时不提供。
  final Future<void> Function()? onRegenerate;

  final bool isGenerating;

  /// 顶栏与固定运行提示的高度；留白随消息滚动，视口延伸至顶栏后方。
  final double topPadding;

  /// 预留给悬浮输入栏的高度，末条消息可滚出遮挡区。
  final double bottomPadding;

  @override
  State<ChatTranscript> createState() => _ChatTranscriptState();
}

class _ChatTranscriptState extends State<ChatTranscript> {
  /// 判定「还在底部」的容差：惯性回弹与亚像素抖动不解除底部跟随。
  static const _bottomThreshold = 8.0;

  /// 显示「回到底部」按钮的最小回看距离，避免轻扫一下就出现按钮。
  static const _returnButtonThreshold = 96.0;
  final _scrollController = ScrollController(keepScrollOffset: false);
  bool _followTail = true;
  bool _userScrolling = false;
  bool _reconcileScheduled = false;
  bool _programmaticScroll = false;
  bool _showReturnToBottom = false;
  bool _scrollingTowardLatest = false;
  bool _returningToBottom = false;
  int _returnScrollRevision = 0;

  /// 本次手势开始时的滚动位置与「是否被拖离尾部」，用于判断松手后
  /// 该不该恢复底部跟随（停在底部上方的回看不应该被拉回去）。
  double? _dragStartPixels;
  bool _draggedAway = false;
  ({BuildContext context, double y})? _readingAnchor;

  @override
  void initState() {
    super.initState();
    _scheduleReconcile();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_returningToBottom && AppMotion.reduce(context)) {
      _cancelReturnToBottom(stopScroll: true);
      _followTail = true;
      _scheduleReconcile();
    }
  }

  @override
  void didUpdateWidget(covariant ChatTranscript oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.conversationId != widget.conversationId) {
      _cancelReturnToBottom();
      _readingAnchor = null;
      _followTail = true;
      _userScrolling = false;
      _showReturnToBottom = false;
      _scrollingTowardLatest = false;
      _dragStartPixels = null;
      _draggedAway = false;
    }
    _scheduleReconcile();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// 消息气泡缓存：同一个消息对象与同一份附件索引直接复用上一次的 widget。
  ///
  /// 生成期间每次增量都会重建整个阅读区，没有缓存的话每条可见消息都要重新
  /// 解析 Markdown（实测 2 万字约 19ms/帧）。Flutter 在 widget 实例完全相同时
  /// 跳过该子树的重建，因此这里只需保证「消息没变 → 实例不变」。
  final _bubbles = <String, _BubbleEntry>{};

  Widget _bubble(int index) {
    final message = widget.messages[index];
    // 只有分支最后一条回答可以重新生成。
    final canRegenerate =
        widget.onRegenerate != null &&
        !widget.isGenerating &&
        index == widget.messages.length - 1;
    final cached = _bubbles[message.id];
    if (cached != null &&
        identical(cached.message, message) &&
        identical(cached.attachments, widget.attachments) &&
        cached.canRegenerate == canRegenerate &&
        cached.onRegenerate == widget.onRegenerate) {
      return cached.widget;
    }
    if (_bubbles.length > widget.messages.length * 2) {
      final live = {for (final item in widget.messages) item.id};
      _bubbles.removeWhere((id, _) => !live.contains(id));
    }
    final widget_ = MessageBubble(
      key: ValueKey(message.id),
      message: message,
      attachments: widget.attachments,
      onRegenerate: canRegenerate ? widget.onRegenerate : null,
    );
    _bubbles[message.id] = _BubbleEntry(
      message: message,
      attachments: widget.attachments,
      canRegenerate: canRegenerate,
      onRegenerate: widget.onRegenerate,
      widget: widget_,
    );
    return widget_;
  }

  void _scheduleReconcile() {
    if (_reconcileScheduled) return;
    _reconcileScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reconcileScheduled = false;
      if (!mounted || !_scrollController.hasClients) return;
      final position = _scrollController.position;
      if (!position.hasContentDimensions) return;
      if (!_userScrolling && !_returningToBottom) {
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
          !_followTail &&
          !_returningToBottom &&
          _scrollingTowardLatest &&
          position.extentAfter > _returnButtonThreshold;
      if (showButton != _showReturnToBottom) {
        setState(() => _showReturnToBottom = showButton);
      }
    });
  }

  bool _onContentExpansion(ContentExpansionNotification notification) {
    _cancelReturnToBottom(stopScroll: true);
    _followTail = false;
    _userScrolling = false;
    _scrollingTowardLatest = false;
    final box = notification.anchor.findRenderObject();
    _readingAnchor = box is RenderBox && box.attached && box.hasSize
        ? (context: notification.anchor, y: box.localToGlobal(Offset.zero).dy)
        : null;
    _scheduleReconcile();
    return true;
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0 || _programmaticScroll) return false;
    if (_returningToBottom) {
      final userInput =
          notification is ScrollStartNotification &&
              notification.dragDetails != null ||
          notification is ScrollUpdateNotification &&
              notification.dragDetails != null ||
          notification is UserScrollNotification &&
              notification.direction != ScrollDirection.idle;
      if (!userInput) return false;
      _cancelReturnToBottom();
    }
    if (notification is ScrollStartNotification) {
      _readingAnchor = null;
      _userScrolling = true;
      _followTail = false;
      _dragStartPixels = notification.metrics.pixels;
      // 用户想继续贴底时（例如在底部上滑想看内容），放开后仍应跟随。
      _draggedAway = false;
    } else if (notification is UserScrollNotification &&
        notification.direction != ScrollDirection.idle) {
      _readingAnchor = null;
      _userScrolling = true;
      _followTail = false;
      // 正向列表的 reverse 是 offset 增大，即向最新消息滚动。
      _scrollingTowardLatest =
          notification.direction == ScrollDirection.reverse;
    } else if (notification is ScrollUpdateNotification &&
        _userScrolling &&
        !notification.metrics.outOfRange) {
      final delta = notification.scrollDelta ?? 0;
      // 同时覆盖内层思考/工具滚到边界后移交给外层的滚动。
      if (delta.abs() > 0.5) _scrollingTowardLatest = delta > 0;
    } else if (notification is ScrollEndNotification && _userScrolling) {
      _userScrolling = false;
      final metrics = notification.metrics;
      // 手势是否把列表拖离了尾部：底部回弹不改变滚动位置，不算拖开。
      final start = _dragStartPixels;
      if (start != null && metrics.pixels < start - 0.5) {
        _draggedAway = true;
      }
      // 只有停在底部（且整段手势没往上拖）才恢复跟随；停在底部上方的
      // 一小段距离同样算"用户在回看"，不把视图拉回去。
      _followTail = !_draggedAway && metrics.extentAfter <= _bottomThreshold;
      if (_followTail) _scrollingTowardLatest = false;
      _dragStartPixels = null;
    }
    _scheduleReconcile();
    return false;
  }

  void _cancelReturnToBottom({bool stopScroll = false}) {
    if (!_returningToBottom) return;
    _returnScrollRevision++;
    _returningToBottom = false;
    _followTail = false;
    if (stopScroll && _scrollController.hasClients) {
      _programmaticScroll = true;
      _scrollController.jumpTo(_scrollController.position.pixels);
      _programmaticScroll = false;
    }
  }

  bool _ownsReturnScroll(int revision, ScrollPosition position) =>
      mounted &&
      _returningToBottom &&
      revision == _returnScrollRevision &&
      _scrollController.hasClients &&
      identical(position, _scrollController.position);

  Future<void> _returnToBottom() async {
    if (_returningToBottom || !_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (!position.hasContentDimensions) return;
    _readingAnchor = null;
    _userScrolling = false;
    _scrollingTowardLatest = false;
    _dragStartPixels = null;
    _draggedAway = false;
    setState(() => _showReturnToBottom = false);
    if (AppMotion.reduce(context)) {
      _followTail = true;
      _scheduleReconcile();
      return;
    }

    _followTail = false;
    _returningToBottom = true;
    final revision = ++_returnScrollRevision;
    var firstLeg = true;
    try {
      while (_ownsReturnScroll(revision, position)) {
        final distance = position.extentAfter;
        if (distance <= 1) {
          _followTail = true;
          break;
        }
        final screens = distance / math.max(1, position.viewportDimension);
        final milliseconds = firstLeg
            ? (420 + math.sqrt(screens) * 110).round().clamp(420, 820)
            : (screens * 160).round().clamp(100, 260);
        await position.animateTo(
          position.maxScrollExtent,
          duration: Duration(milliseconds: milliseconds),
          curve: firstLeg
              ? Curves.easeInOutCubicEmphasized
              : Curves.easeOutCubic,
        );
        if (!_ownsReturnScroll(revision, position)) return;
        // 等待惰性消息布局更新实际尾端，剩余距离继续缓停，而不是最后跳一下。
        await WidgetsBinding.instance.endOfFrame;
        firstLeg = false;
      }
    } finally {
      if (mounted && revision == _returnScrollRevision) {
        _returningToBottom = false;
        _scheduleReconcile();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final indices = {
      for (var index = 0; index < widget.messages.length; index++)
        ValueKey(widget.messages[index].id): index,
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
                  child: NotificationListener<ContentExpansionNotification>(
                    onNotification: _onContentExpansion,
                    child: Listener(
                      // 手指按下即撤销续滚，避免 animateTo 完成后再次抢走手势。
                      onPointerDown: (_) => _cancelReturnToBottom(),
                      child: ListView.builder(
                        key: ValueKey('transcript-${widget.conversationId}'),
                        controller: _scrollController,
                        padding: EdgeInsets.only(
                          top: AppSpacing.m + widget.topPadding,
                          bottom: AppSpacing.m + widget.bottomPadding,
                        ),
                        itemCount: widget.messages.length,
                        findChildIndexCallback: (key) => indices[key],
                        itemBuilder: (context, index) => _bubble(index),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: AppSpacing.l,
              bottom: AppSpacing.m + widget.bottomPadding,
              child: ChatReturnToBottomButton(
                key: ValueKey('return-to-bottom-${widget.conversationId}'),
                visible: _showReturnToBottom,
                onPressed: _returnToBottom,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
