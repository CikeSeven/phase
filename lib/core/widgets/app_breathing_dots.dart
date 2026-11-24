import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_motion.dart';

class AppBreathingDots extends StatefulWidget {
  const AppBreathingDots({required this.label, super.key});
  final String label;
  @override
  State<AppBreathingDots> createState() => _AppBreathingDotsState();
}

class _AppBreathingDotsState extends State<AppBreathingDots>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduce(context) || !TickerMode.valuesOf(context).enabled) {
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.label,
    child: RepaintBoundary(
      child: CustomPaint(
        size: const Size(32, 20),
        painter: _DotPainter(_pulse, Theme.of(context).colorScheme.primary),
      ),
    ),
  );
}

class _DotPainter extends CustomPainter {
  _DotPainter(this.pulse, this.color) : super(repaint: pulse);
  final Animation<double> pulse;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (var i = 0; i < 3; i++) {
      final t = (1 + math.cos((pulse.value - i * .16) * 2 * math.pi)) / 2;
      paint.color = color.withValues(alpha: .38 + .62 * t);
      canvas.drawCircle(
        Offset(6 + i * 10, size.height / 2 - 1.5 * t),
        2.3 + t * .6,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DotPainter old) =>
      pulse != old.pulse || color != old.color;
}
