import 'package:flutter/material.dart';

import '../theme/app_motion.dart';

class AppCompletionMark extends StatelessWidget {
  const AppCompletionMark({
    required this.color,
    required this.animate,
    this.checked = true,
    super.key,
  });
  final Color color;
  final bool animate;
  final bool checked;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(
      begin: animate || !checked ? 0.0 : 1.0,
      end: checked ? 1.0 : 0.0,
    ),
    duration: !checked || AppMotion.reduce(context)
        ? Duration.zero
        : const Duration(milliseconds: 300),
    curve: Curves.easeOutCubic,
    builder: (_, t, _) => CustomPaint(
      size: const Size.square(14),
      painter: _CheckPainter(t, color),
    ),
  );
}

class _CheckPainter extends CustomPainter {
  const _CheckPainter(this.t, this.color);
  final double t;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * .12, size.height * .54)
      ..lineTo(size.width * .39, size.height * .78)
      ..lineTo(size.width * .90, size.height * .21);
    final metric = path.computeMetrics().first;
    final end = metric.length * t;
    final pen = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 1.8
      ..color = color;
    canvas.drawPath(metric.extractPath(0, end), pen);
    if (t > 0 && t < 1) {
      pen
        ..color = color.withValues(alpha: .22)
        ..strokeWidth = 3;
      canvas.drawPath(
        metric.extractPath((end - 3).clamp(0, end).toDouble(), end),
        pen,
      );
    }
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.t != t || old.color != color;
}
