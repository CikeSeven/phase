import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../theme/app_motion.dart';

class AppPressScale extends StatefulWidget {
  const AppPressScale({required this.builder, super.key});
  final Widget Function(BuildContext context, WidgetStatesController states)
  builder;
  @override
  State<AppPressScale> createState() => _AppPressScaleState();
}

class _AppPressScaleState extends State<AppPressScale>
    with SingleTickerProviderStateMixin {
  static final _spring = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 700,
    ratio: 1,
  );
  late final _scale = AnimationController.unbounded(vsync: this, value: 1);
  late final _states = WidgetStatesController()..addListener(_changed);
  bool _pressed = false;
  bool _reduced = false;
  Future<void> _settle(double target) => _scale
      .animateWith(
        SpringSimulation(
          _spring,
          _scale.value,
          target,
          _scale.velocity,
          snapToEnd: true,
        ),
      )
      .orCancel;
  Future<void> _changed() async {
    final pressed = _states.value.contains(WidgetState.pressed);
    if (_states.value.contains(WidgetState.disabled) || _reduced) {
      _pressed = false;
      if (_scale.isAnimating || _scale.value != 1) _scale.value = 1;
      return;
    }
    if (pressed == _pressed) return;
    _pressed = pressed;
    try {
      await _settle(pressed ? .92 : 1.05);
      if (mounted && !_pressed && !pressed) await _settle(1);
    } on TickerCanceled {
      return;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = AppMotion.reduce(context);
    if (_reduced) _scale.value = 1;
  }

  @override
  void dispose() {
    _states.dispose();
    _scale.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _scale,
    builder: (_, child) => Transform.scale(
      scale: _scale.value,
      transformHitTests: false,
      child: child,
    ),
    child: widget.builder(context, _states),
  );
}
