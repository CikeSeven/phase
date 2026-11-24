import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderAbstractViewport;

import '../theme/app_motion.dart';

/// 与路由共用时间轴，按条目在当前视口中的位置错开转场。
class SettingsListItem extends StatefulWidget {
  const SettingsListItem({required this.child, super.key});

  final Widget child;

  static Widget wrap(Widget child) {
    if (child is SizedBox && child.child == null) return child;
    return SettingsListItem(
      key: child.key == null ? null : ValueKey(child.key),
      child: child,
    );
  }

  @override
  State<SettingsListItem> createState() => _SettingsListItemState();
}

class _SettingsListItemState extends State<SettingsListItem>
    with SingleTickerProviderStateMixin {
  static final _pending = Expando<List<_SettingsListItemState>>();
  late final _entry = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 340),
    value: 1,
  );
  Animation<double>? _route;
  Timer? _delay;
  double? _exitFraction;
  bool _queued = false;

  // 同一帧布局结束后按屏幕位置排一次序，滚出视口的缓存条目不占用延时。
  void _queueEntry(Animation<double> route) {
    _entry.value = 0;
    _queued = true;
    final waiting = _pending[route];
    if (waiting != null) {
      waiting.add(this);
      return;
    }
    final batch = <_SettingsListItemState>[this];
    _pending[route] = batch;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pending[route] = null;
      final visible = <({double y, _SettingsListItemState item})>[];
      for (final item in batch) {
        if (!item.mounted || !item._queued || item._route != route) continue;
        item._queued = false;
        final y = item._viewportFraction();
        if (y == null || y >= 1) {
          item._entry.value = 1;
          continue;
        }
        visible.add((y: y, item: item));
      }
      visible.sort((a, b) => a.y.compareTo(b.y));
      for (var i = 0; i < visible.length; i++) {
        final item = visible[i].item;
        if (i == 0) {
          item._enter();
        } else {
          item._delay = Timer(Duration(milliseconds: 50 * i), item._enter);
        }
      }
    });
  }

  double? _viewportFraction() {
    final box = context.findRenderObject() as RenderBox?;
    final RenderObject? viewport = RenderAbstractViewport.maybeOf(box);
    if (box == null ||
        !box.attached ||
        !box.hasSize ||
        viewport is! RenderBox ||
        !viewport.hasSize ||
        viewport.size.height <= 0) {
      return null;
    }
    final top = box.localToGlobal(Offset.zero, ancestor: viewport).dy;
    if (top + box.size.height <= 0) return null;
    return top / viewport.size.height;
  }

  void _enter() {
    _delay = null;
    _entry.animateTo(1, curve: Curves.easeOutCubic);
  }

  void _status(AnimationStatus status) {
    if (status == AnimationStatus.reverse) {
      _queued = false;
      _delay?.cancel();
      _entry.stop();
      _exitFraction = _viewportFraction()?.clamp(0, 1);
      setState(() {});
    } else if (status == AnimationStatus.forward) {
      setState(() {});
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    final animation =
        route == null || route.isFirst || AppMotion.reduce(context)
        ? null
        : route.animation;
    if (animation != _route) {
      _route?.removeStatusListener(_status);
      _delay?.cancel();
      _queued = false;
      _entry.value = 1;
      _route = animation;
      animation?.addStatusListener(_status);
      if (animation != null &&
          (animation.status == AnimationStatus.forward ||
              animation.isDismissed ||
              (animation.isCompleted &&
                  !(Scrollable.maybeOf(context)
                          ?.position
                          .isScrollingNotifier
                          .value ??
                      false)))) {
        _queueEntry(animation);
      }
    }
  }

  @override
  void dispose() {
    _queued = false;
    _delay?.cancel();
    _route?.removeStatusListener(_status);
    _entry.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final route = _route;
    if (route == null) return widget.child;
    final exiting = route.status == AnimationStatus.reverse;
    final delay = (_exitFraction ?? 0) * .34;
    final progress = exiting
        ? route
              .drive(
                CurveTween(
                  curve: Interval(
                    .34 - delay,
                    1 - delay,
                    curve: Curves.easeInOutSine,
                  ),
                ),
              )
              .drive(Tween(begin: 0.0, end: _entry.value))
        : _entry;
    return SlideTransition(
      position: progress.drive(
        Tween(begin: const Offset(.18, 0), end: Offset.zero),
      ),
      child: FadeTransition(
        // 路由已经将退出的行移出视口，保持表面不透明可省去每行一层合成。
        opacity: exiting ? AlwaysStoppedAnimation(_entry.value) : progress,
        child: RepaintBoundary(child: widget.child),
      ),
    );
  }
}

class SettingsListView extends ListView {
  SettingsListView({
    required List<Widget> children,
    super.key,
    super.controller,
    super.padding,
  }) : super(
         addRepaintBoundaries: false,
         children: children.map(SettingsListItem.wrap).toList(),
       );
}
