import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_radius.dart';

/// 使用矢量圆弧和圆点绘制 Ubuntu 标志，随屏幕密度保持清晰。
class UbuntuIcon extends StatelessWidget {
  const UbuntuIcon({super.key});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Color(0xFFE95420),
        borderRadius: AppRadius.smallAll,
      ),
      child: const CustomPaint(
        size: Size.square(32),
        painter: _UbuntuLogoPainter(),
      ),
    ),
  );
}

class _UbuntuLogoPainter extends CustomPainter {
  const _UbuntuLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 32, size.height / 32);
    const center = Offset(16, 16);
    final ring = Rect.fromCircle(center: center, radius: 8.5);
    final body = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.8;
    final head = Paint()..color = Colors.white;
    for (var i = 0; i < 3; i++) {
      final angle = i * math.pi * 2 / 3;
      canvas.drawArc(ring, angle + math.pi / 12, math.pi / 2, false, body);
      canvas.drawCircle(
        center + Offset(math.cos(angle), math.sin(angle)) * 12.5,
        2.7,
        head,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_UbuntuLogoPainter oldDelegate) => false;
}
