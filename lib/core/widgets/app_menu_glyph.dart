import 'package:flutter/material.dart';

import '../theme/app_motion.dart';

class AppMenuGlyph extends StatelessWidget {
  const AppMenuGlyph({required this.open, this.size = 24, super.key});
  final bool open;
  final double size;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    duration: AppMotion.reduce(context) ? Duration.zero : AppMotion.menuOpen,
    curve: Curves.easeOutCubic,
    tween: Tween(begin: 0, end: open ? 1 : 0),
    builder: (_, value, _) => AnimatedIcon(
      icon: AnimatedIcons.menu_close,
      progress: AlwaysStoppedAnimation(value),
      size: size,
    ),
  );
}
