import 'package:flutter/material.dart';

import '../theme/app_motion.dart';

class AppListLoadTransition extends StatelessWidget {
  const AppListLoadTransition({
    required this.child,
    this.slideIn = false,
    super.key,
  });
  final Widget child;
  final bool slideIn;
  @override
  Widget build(BuildContext context) {
    if (AppMotion.reduce(context)) return child;
    return AnimatedSwitcher(
      duration: slideIn ? const Duration(milliseconds: 360) : AppMotion.effects,
      transitionBuilder: slideIn
          ? _slide
          : AnimatedSwitcher.defaultTransitionBuilder,
      layoutBuilder: (current, outgoing) => Stack(
        fit: StackFit.expand,
        children: [
          ?current,
          for (final old in outgoing)
            IgnorePointer(child: ExcludeSemantics(child: old)),
        ],
      ),
      switchInCurve: Curves.easeOutCubic,
      child: KeyedSubtree(
        key: ValueKey(child is AppListSkeleton),
        child: child,
      ),
    );
  }

  static Widget _slide(Widget child, Animation<double> progress) =>
      FadeTransition(
        opacity: progress,
        child: SlideTransition(
          position: progress.drive(
            Tween(begin: const Offset(.14, 0), end: Offset.zero),
          ),
          child: child,
        ),
      );
}

class AppListSkeleton extends StatefulWidget {
  const AppListSkeleton({required this.label, super.key});
  final String label;
  @override
  State<AppListSkeleton> createState() => _AppListSkeletonState();
}

class _AppListSkeletonState extends State<AppListSkeleton>
    with SingleTickerProviderStateMixin {
  late final _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1450),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduce(context) || !TickerMode.valuesOf(context).enabled) {
      _sweep.stop();
    } else if (!_sweep.isAnimating) {
      _sweep.repeat();
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.label,
    liveRegion: true,
    child: Align(
      alignment: Alignment.topCenter,
      child: RepaintBoundary(
        child: SizedBox(
          width: double.infinity,
          height: 224,
          child: CustomPaint(
            painter: _SkeletonPainter(
              _sweep,
              Theme.of(context).colorScheme.surfaceContainerHighest,
              AppMotion.reduce(context),
            ),
          ),
        ),
      ),
    ),
  );
}

class _SkeletonPainter extends CustomPainter {
  _SkeletonPainter(this.progress, this.color, this.reduced)
    : super(repaint: progress);
  final Animation<double> progress;
  final Color color;
  final bool reduced;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    if (!reduced && size.width > 0) {
      final x =
          (1.8 * Curves.easeInOut.transform(progress.value) - .4) * size.width;
      paint.shader =
          LinearGradient(
            colors: [
              color,
              Color.alphaBlend(Colors.white.withValues(alpha: .32), color),
              color,
            ],
          ).createShader(
            Rect.fromLTWH(
              x - size.width * .25,
              0,
              size.width * .5,
              size.height,
            ),
          );
    }
    for (var row = 0; row < 3; row++) {
      final y = 16.0 + row * 68;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(16, y, 44, 44),
          const Radius.circular(12),
        ),
        paint,
      );
      final width = (size.width - 92).clamp(0.0, 420.0);
      for (var line = 0; line < 2; line++) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              72,
              y + 6 + line * 20,
              width * (line == 0 ? .52 : .85),
              10,
            ),
            const Radius.circular(5),
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_SkeletonPainter old) =>
      old.color != color || old.reduced != reduced || old.progress != progress;
}
