import 'package:flutter/material.dart';

import '../theme/brand_colors.dart';

/// 贯穿页面的静态月色画布，装饰层不参与点击或语义导航。
class AppBackground extends StatelessWidget {
  const AppBackground({required this.child, super.key, this.subtle = false});

  final Widget child;
  final bool subtle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final brand = context.brandColors;
    final dark = theme.brightness == Brightness.dark;
    final strength = subtle ? 0.45 : 1.0;
    final clear = colors.surface.withValues(alpha: 0);

    return Stack(
      fit: StackFit.expand,
      children: [
        ExcludeSemantics(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surface,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  stops: const [0, 0.52, 1],
                  colors: [
                    Color.alphaBlend(
                      brand.teal.withValues(
                        alpha: (dark ? 0.10 : 0.09) * strength,
                      ),
                      colors.surface,
                    ),
                    colors.surface,
                    Color.alphaBlend(
                      brand.lavender.withValues(
                        alpha: (dark ? 0.12 : 0.10) * strength,
                      ),
                      colors.surface,
                    ),
                  ],
                ),
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    stops: const [0, 0.6, 1],
                    colors: [
                      colors.primary.withValues(
                        alpha: (dark ? 0.10 : 0.08) * strength,
                      ),
                      clear,
                      clear,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
