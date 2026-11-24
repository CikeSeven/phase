import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../theme/app_motion.dart';

class AppPopupTransition extends StatefulWidget {
  const AppPopupTransition({
    required this.progress,
    required this.child,
    this.alignment = Alignment.center,
    super.key,
  });
  final Animation<double> progress;
  final Widget child;
  final Alignment alignment;

  @override
  State<AppPopupTransition> createState() => _AppPopupTransitionState();
}

class _PopupSpring extends Curve {
  const _PopupSpring();
  static final _spring = SpringSimulation(
    SpringDescription.withDampingRatio(mass: 1, stiffness: 360, ratio: .72),
    0,
    1,
    0,
  );
  @override
  double transformInternal(double t) => _spring.x(t * .34) / _spring.x(.34);
}

class _AppPopupTransitionState extends State<AppPopupTransition> {
  late CurvedAnimation _progress;
  void _bind() {
    _progress = CurvedAnimation(
      parent: widget.progress,
      curve: const _PopupSpring(),
      reverseCurve: Curves.easeOutQuad,
    );
  }

  @override
  void initState() {
    super.initState();
    _bind();
  }

  @override
  void didUpdateWidget(AppPopupTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      _progress.dispose();
      _bind();
    }
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (AppMotion.reduce(context)) return widget.child;
    return FadeTransition(
      opacity: widget.progress,
      child: ScaleTransition(
        alignment: widget.alignment,
        scale: _progress.drive(Tween(begin: .95, end: 1.0)),
        child: RepaintBoundary(child: widget.child),
      ),
    );
  }
}
