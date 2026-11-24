import 'package:flutter/material.dart';

import '../../core/theme/app_motion.dart';

Widget attachmentImageFrame(
  BuildContext context,
  Widget image,
  int? frame,
  bool synchronous,
) {
  if (synchronous || AppMotion.reduce(context)) return image;
  final colors = Theme.of(context).colorScheme;
  return TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: frame == null ? 0 : 1),
    duration: AppMotion.effects,
    curve: Curves.easeOutCubic,
    child: image,
    builder: (_, t, child) => t == 1
        ? child!
        : Stack(
            fit: StackFit.passthrough,
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      radius: 1.1,
                      colors: [
                        colors.surfaceContainerHighest,
                        colors.surfaceContainerLow,
                      ],
                    ),
                  ),
                ),
              ),
              Opacity(opacity: t, child: child),
            ],
          ),
  );
}
