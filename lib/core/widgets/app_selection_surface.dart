import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../theme/app_control_style.dart';
import '../theme/app_motion.dart';
import '../theme/app_radius.dart';

/// 主题、模型等选择面的共同反馈，不持有或提前提交业务选择。
///
/// 弹簧仅改变裁剪形状，布局与触区不缩放，快速改选保留当前速度。
class AppSelectionSurface extends StatefulWidget {
  const AppSelectionSurface({
    required this.selected,
    required this.onTap,
    required this.child,
    super.key,
    this.color,
  });

  final bool selected;
  final VoidCallback? onTap;
  final Widget child;
  final Color? color;

  @override
  State<AppSelectionSurface> createState() => _AppSelectionSurfaceState();
}

class _AppSelectionSurfaceState extends State<AppSelectionSurface>
    with SingleTickerProviderStateMixin {
  late final AnimationController _radius = AnimationController.unbounded(
    vsync: this,
    value: _targetRadius,
  );
  bool _pressed = false;
  bool _reduceMotion = false;

  double get _targetRadius => _pressed && widget.onTap != null
      ? AppRadius.small
      : widget.selected
      ? AppRadius.large
      : AppRadius.medium;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = AppMotion.reduce(context);
    if (_reduceMotion) _radius.value = _targetRadius;
  }

  @override
  void didUpdateWidget(AppSelectionSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.onTap == null) _pressed = false;
    if (widget.selected != oldWidget.selected ||
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
            (widget.selected
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
