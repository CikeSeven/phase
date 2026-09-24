import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// 让内容手势先于 Scaffold 的全屏侧栏打开手势参与竞争。
class ChatHorizontalDragPriority extends SingleChildRenderObjectWidget {
  const ChatHorizontalDragPriority({
    required this.guardDrawerOpening,
    required super.child,
    super.key,
  });

  final bool guardDrawerOpening;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderChatHorizontalDragPriority(guardDrawerOpening);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderObject renderObject,
  ) {
    (renderObject as _RenderChatHorizontalDragPriority).guardDrawerOpening =
        guardDrawerOpening;
  }
}

/// 标记正文和输入区；嵌套标记让代码、表格等局部横滚优先。
class ChatHorizontalDragRegion extends SingleChildRenderObjectWidget {
  const ChatHorizontalDragRegion({required super.child, super.key});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderChatHorizontalDragRegion();
}

class _RenderChatHorizontalDragPriority extends RenderProxyBox {
  _RenderChatHorizontalDragPriority(this.guardDrawerOpening);

  bool guardDrawerOpening;
  final _thresholdGuard = _DrawerOpenThresholdGuard();

  @override
  void handleEvent(PointerEvent event, BoxHitTestEntry entry) {
    if (guardDrawerOpening && event is PointerDownEvent) {
      _thresholdGuard.addPointer(event);
    }
  }

  @override
  void dispose() {
    _thresholdGuard.dispose();
    super.dispose();
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    // 先按实际层级探测，已打开的侧栏、遮罩等仍可阻挡后方阅读区。
    final probe = BoxHitTestResult();
    super.hitTest(probe, position: position);
    _RenderChatHorizontalDragRegion? region;
    for (final entry in probe.path) {
      final target = entry.target;
      if (target is _RenderChatHorizontalDragRegion) {
        region = target;
        break;
      }
    }
    if (region == null) return super.hitTest(result, position: position);

    // Scaffold 把侧栏打开探测层放在正文之上，默认会先注册横向手势。
    // 先命中内容子树，不提前接受手势，滚动、文本编辑和长按仍正常竞争。
    final prioritized = region;
    final hit = result.addWithPaintTransform(
      transform: prioritized.getTransformTo(this),
      position: position,
      hitTest: (result, position) =>
          prioritized.hitTest(result, position: position),
    );
    if (!hit) return super.hitTest(result, position: position);

    // 其余命中路径照常追加；阅读区已注册，避免同一事件派发两次。
    prioritized.skipHitTest = true;
    try {
      return super.hitTest(result, position: position);
    } finally {
      prioritized.skipHitTest = false;
    }
  }
}

class _RenderChatHorizontalDragRegion extends RenderProxyBox {
  bool skipHitTest = false;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) =>
      skipHitTest || super.hitTest(result, position: position);
}

/// 空白或不可滚动区域可能只剩侧栏识别器，它会跳过阈值直接胜出。
/// 保留一个不主动接受的竞争者，直到其他手势胜出或本次触摸结束。
class _DrawerOpenThresholdGuard extends OneSequenceGestureRecognizer {
  @override
  String get debugDescription => 'drawer open threshold guard';

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerUpEvent || event is PointerCancelEvent) {
      resolvePointer(event.pointer, GestureDisposition.rejected);
      stopTrackingPointer(event.pointer);
    }
  }

  @override
  void rejectGesture(int pointer) {
    resolvePointer(pointer, GestureDisposition.rejected);
    stopTrackingPointer(pointer);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {}
}
