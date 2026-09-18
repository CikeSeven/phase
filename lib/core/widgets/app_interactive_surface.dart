import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../theme/app_control_style.dart';
import '../theme/app_motion.dart';
import '../theme/app_radius.dart';

/// 操作面与选择面的共同反馈；selected 为 null 时不声明选择语义。
///
/// 弹簧仅改变裁剪形状，布局与触区不缩放，快速改选保留当前速度。
class AppInteractiveSurface extends StatefulWidget {
  const AppInteractiveSurface({
    this.selected,
    required this.onTap,
    required this.child,
    super.key,
    this.color,
    this.radius = AppRadius.medium,
    this.onLongPress,
  });

  final bool? selected;
  final double radius;
  final VoidCallback? onLongPress;
  final VoidCallback? onTap;
  final Widget child;
  final Color? color;

  @override
  State<AppInteractiveSurface> createState() => _AppInteractiveSurfaceState();
}

class _AppInteractiveSurfaceState extends State<AppInteractiveSurface>
    with SingleTickerProviderStateMixin {
  late final AnimationController _radius = AnimationController.unbounded(
    vsync: this,
    value: _targetRadius,
  );
  bool _pressed = false;
  bool _reduceMotion = false;

  double get _targetRadius => _pressed && widget.onTap != null
      ? AppRadius.small
      : widget.selected == true
      ? AppRadius.large
      : widget.radius;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = AppMotion.reduce(context);
    if (_reduceMotion) _radius.value = _targetRadius;
  }

  @override
  void didUpdateWidget(AppInteractiveSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.onTap == null) _pressed = false;
    if (widget.selected != oldWidget.selected ||
        widget.radius != oldWidget.radius ||
        (oldWidget.onTap != null && widget.onTap == null)) {
      _animateShape();
    }
  }

  void _animateShape() {
    if (_reduceMotion) {
      _radius.value = _targetRadius;
      return;
    }
    _radius.animateWith(
      SpringSimulation(
        AppMotion.shapeSpring,
        _radius.value,
        _targetRadius,
        _radius.velocity,
        snapToEnd: true,
      ),
    );
  }

  @override
  void dispose() {
    _radius.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(
        end:
            widget.color ??
            (widget.selected == true
                ? colors.primaryContainer.withValues(alpha: 0.72)
                : colors.surface.withValues(alpha: 0)),
      ),
      duration: _reduceMotion ? Duration.zero : AppMotion.effects,
      curve: Curves.easeOutCubic,
      builder: (context, color, child) => AnimatedBuilder(
        animation: _radius,
        builder: (context, child) => Material(
          color: color,
          borderRadius: BorderRadius.circular(
            _radius.value.clamp(0, AppRadius.full),
          ),
          clipBehavior: Clip.antiAlias,
          // 形状已由弹簧驱动，避免叠加 Material 的隐式形状过渡。
          animationDuration: Duration.zero,
          child: child,
        ),
        child: child,
      ),
      child: Semantics(
        selected: widget.selected,
        button: true,
        enabled: widget.onTap != null,
        child: InkWell(
          onTap: widget.onTap,
          onLongPress: widget.onTap == null ? null : widget.onLongPress,
          onHighlightChanged: (pressed) {
            _pressed = pressed;
            _animateShape();
          },
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: AppControlStyle.touchTarget,
              minHeight: AppControlStyle.touchTarget,
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
