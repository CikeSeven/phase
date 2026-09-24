import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// 让局部横滚先于 Scaffold 的全屏侧栏打开手势参与竞争。
class ChatHorizontalDragPriority extends SingleChildRenderObjectWidget {
  const ChatHorizontalDragPriority({required super.child, super.key});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderChatHorizontalDragPriority();
}

/// 只标记内容阅读区；普通正文仍由原有侧栏手势处理。
class ChatHorizontalDragRegion extends SingleChildRenderObjectWidget {
  const ChatHorizontalDragRegion({required super.child, super.key});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderChatHorizontalDragRegion();
}

class _RenderChatHorizontalDragPriority extends RenderProxyBox {
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
    // 只提前命中阅读区子树，不提前接受手势，纵向滚动和长按仍正常竞争。
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
