import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../theme/app_motion.dart';

/// 鼠标坐标取自静止的触区，绘制变形不会让边缘反复触发进入和离开。
class AppPointerMotion extends StatefulWidget {
  const AppPointerMotion({
    required this.child,
    this.showcase = false,
    super.key,
  });
  final Widget child;
  final bool showcase;
  @override
  State<AppPointerMotion> createState() => _AppPointerMotionState();
}

class _AppPointerMotionState extends State<AppPointerMotion>
    with SingleTickerProviderStateMixin {
  Offset? _pointer;
  late final _beam = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  );
  void _move(PointerEvent event) {
    if (event.kind != PointerDeviceKind.mouse || AppMotion.reduce(context)) {
      return;
    }
    final size = context.size;
    if (size == null || size.isEmpty) return;
    final p = event.localPosition;
    setState(
      () => _pointer = Offset(
        (2 * p.dx / size.width - 1).clamp(-1, 1),
        (2 * p.dy / size.height - 1).clamp(-1, 1),
      ),
    );
    if (widget.showcase && !_beam.isAnimating) _beam.repeat();
  }

  void _clear() {
    _beam.stop();
    if (_pointer != null) setState(() => _pointer = null);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduce(context)) {
      _beam.stop();
      _pointer = null;
    }
  }

  @override
  void dispose() {
    _beam.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = _pointer ?? Offset.zero;
    final active = widget.showcase && _pointer != null;
    final matrix = Matrix4.identity();
    if (widget.showcase) {
      matrix.setEntry(3, 2, .001);
      matrix.translateByDouble(0, active ? -3 : 0, 0, 1);
      matrix.rotateX(-p.dy * .035);
      matrix.rotateY(p.dx * .045);
    } else {
      matrix.translateByDouble(p.dx * 4, p.dy * 4, 0, 1);
    }
    return MouseRegion(
      onEnter: _move,
      onHover: _move,
      onExit: (_) => _clear(),
      child: AnimatedContainer(
        duration: AppMotion.reduce(context) ? Duration.zero : AppMotion.effects,
        curve: Curves.easeOutCubic,
        transformAlignment: Alignment.center,
        transform: matrix,
        decoration: widget.showcase
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  if (active)
                    const BoxShadow(
                      color: Color(0x26000000),
                      blurRadius: 14,
                      offset: Offset(0, 5),
                    ),
                ],
              )
            : null,
        child: widget.showcase
            ? RepaintBoundary(
                child: CustomPaint(
                  foregroundPainter: active
                      ? _HoverLight(
                          _beam,
                          p,
                          Theme.of(context).colorScheme.primary,
                        )
                      : null,
                  child: widget.child,
                ),
              )
            : widget.child,
      ),
    );
  }
}

class _HoverLight extends CustomPainter {
  _HoverLight(this.beam, this.point, this.color) : super(repaint: beam);
  final Animation<double> beam;
  final Offset point;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final bounds = RRect.fromRectAndRadius(
      rect.deflate(1),
      const Radius.circular(20),
    );
    canvas.drawRRect(
      bounds,
      Paint()
        ..shader = RadialGradient(
          center: Alignment(point.dx, point.dy),
          colors: [color.withValues(alpha: .095), color.withValues(alpha: 0)],
        ).createShader(rect),
    );
    canvas.drawRRect(
      bounds,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..shader = SweepGradient(
          colors: [
            color.withValues(alpha: 0),
            color.withValues(alpha: 0),
            color.withValues(alpha: .7),
            color.withValues(alpha: 0),
          ],
          stops: const [0, .77, .94, 1],
          transform: GradientRotation(math.pi * 2 * beam.value),
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_HoverLight old) =>
      point != old.point || color != old.color || beam != old.beam;
}
