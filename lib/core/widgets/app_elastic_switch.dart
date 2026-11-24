import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../theme/app_motion.dart';

class AppElasticSwitch extends StatefulWidget {
  const AppElasticSwitch({
    required this.value,
    required this.onChanged,
    this.thumbColor,
    this.trackColor,
    this.trackOutlineColor,
    super.key,
  });
  final bool value;
  final ValueChanged<bool>? onChanged;
  final WidgetStateProperty<Color?>? thumbColor, trackColor, trackOutlineColor;

  @override
  State<AppElasticSwitch> createState() => _AppElasticSwitchState();
}

class _AppElasticSwitchState extends State<AppElasticSwitch>
    with SingleTickerProviderStateMixin {
  late final _position = AnimationController.unbounded(
    vsync: this,
    value: widget.value ? 1 : 0,
  );
  static final _spring = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 430,
    ratio: .78,
  );
  bool _reduced = false;

  void _settle() {
    final target = widget.value ? 1.0 : 0.0;
    if (_reduced) {
      _position.value = target;
    } else {
      _position.animateWith(
        SpringSimulation(
          _spring,
          _position.value,
          target,
          _position.velocity,
          snapToEnd: true,
        ),
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = AppMotion.reduce(context);
    if (_reduced) _settle();
  }

  @override
  void didUpdateWidget(AppElasticSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value ||
        widget.onChanged == null && oldWidget.onChanged != null) {
      _settle();
    }
  }

  @override
  void dispose() {
    _position.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final disabled = widget.onChanged == null;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final off = {if (disabled) WidgetState.disabled};
    final on = {...off, WidgetState.selected};
    Color tone(
      WidgetStateProperty<Color?>? property,
      Color a,
      Color b,
      double t,
    ) =>
        Color.lerp(property?.resolve(off) ?? a, property?.resolve(on) ?? b, t)!;
    final muted = colors.onSurface.withValues(alpha: .38);
    return Semantics(
      toggled: widget.value,
      enabled: !disabled,
      child: GestureDetector(
        excludeFromSemantics: true,
        onHorizontalDragStart: disabled ? null : (_) => _position.stop(),
        onHorizontalDragUpdate: disabled
            ? null
            : (details) {
                _position.value =
                    (_position.value + details.delta.dx * (rtl ? -1 : 1) / 20)
                        .clamp(0, 1);
              },
        onHorizontalDragCancel: disabled ? null : _settle,
        onHorizontalDragEnd: disabled
            ? null
            : (_) {
                final next = _position.value >= .5;
                if (next != widget.value) widget.onChanged?.call(next);
                _settle();
              },
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: disabled ? null : () => widget.onChanged!(!widget.value),
          child: SizedBox(
            width: 60,
            height: 48,
            child: Center(
              child: AnimatedBuilder(
                animation: _position,
                builder: (_, _) {
                  final t = _position.value.clamp(0.0, 1.0);
                  final diameter = 16 + 8 * t;
                  final stretch = _reduced ? 0.0 : 7 * math.sin(math.pi * t);
                  final center =
                      16 + 20 * (rtl ? 1 - _position.value : _position.value);
                  return Container(
                    width: 52,
                    height: 32,
                    decoration: ShapeDecoration(
                      color: tone(
                        widget.trackColor,
                        colors.surfaceContainerHighest,
                        disabled ? muted : colors.primary,
                        t,
                      ),
                      shape: StadiumBorder(
                        side: BorderSide(
                          width: 2,
                          color: tone(
                            widget.trackOutlineColor,
                            disabled ? muted : colors.outline,
                            Colors.transparent,
                            t,
                          ),
                        ),
                      ),
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          left: center - (diameter + stretch) / 2 - 2,
                          top: (32 - diameter) / 2 - 2,
                          width: diameter + stretch,
                          height: diameter,
                          child: DecoratedBox(
                            decoration: ShapeDecoration(
                              shape: const StadiumBorder(),
                              color: tone(
                                widget.thumbColor,
                                disabled ? muted : colors.outline,
                                disabled ? colors.surface : colors.onPrimary,
                                t,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AppElasticSwitchTile extends StatelessWidget {
  const AppElasticSwitchTile({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.secondary,
    this.contentPadding,
    super.key,
  });
  final Widget title;
  final Widget? subtitle, secondary;
  final EdgeInsetsGeometry? contentPadding;
  final bool value;
  final ValueChanged<bool>? onChanged;
  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: ListTile(
      leading: secondary,
      title: title,
      subtitle: subtitle,
      contentPadding: contentPadding,
      enabled: onChanged != null,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      trailing: AppElasticSwitch(value: value, onChanged: onChanged),
    ),
  );
}
