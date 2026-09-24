import 'package:flutter/material.dart';

/// Expressive 快速空间弹簧用于形状；颜色使用无回弹的短过渡。
abstract final class AppMotion {
  static const effects = Duration(milliseconds: 200);
  static const menuOpen = Duration(milliseconds: 180);
  static const menuClose = Duration(milliseconds: 120);
  static const menuCurve = Cubic(0.2, 0.8, 0.2, 1);
  static const menuReverseCurve = Curves.easeOutCubic;

  static final shapeSpring = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 800,
    ratio: 0.6,
  );

  static bool reduce(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context) ||
      MediaQuery.accessibleNavigationOf(context);
}

/// SDK 按钮的 Material 形状动画不自行读取减少动画偏好，在装配处统一适配。
class AppMotionTheme extends StatelessWidget {
  const AppMotionTheme({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reduced = AppMotion.reduce(context);
    ButtonStyle immediate(ButtonStyle? style) => (style ?? const ButtonStyle())
        .copyWith(animationDuration: Duration.zero);
    return Theme(
      // 保持 Theme 节点身份稳定，切换无障碍偏好时不重建导航和表单状态。
      data: reduced
          ? theme.copyWith(
              filledButtonTheme: FilledButtonThemeData(
                style: immediate(theme.filledButtonTheme.style),
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: immediate(theme.elevatedButtonTheme.style),
              ),
              outlinedButtonTheme: OutlinedButtonThemeData(
                style: immediate(theme.outlinedButtonTheme.style),
              ),
              textButtonTheme: TextButtonThemeData(
                style: immediate(theme.textButtonTheme.style),
              ),
              iconButtonTheme: IconButtonThemeData(
                style: immediate(theme.iconButtonTheme.style),
              ),
              segmentedButtonTheme: SegmentedButtonThemeData(
                style: immediate(theme.segmentedButtonTheme.style),
              ),
              menuButtonTheme: MenuButtonThemeData(
                style: immediate(theme.menuButtonTheme.style),
              ),
            )
          : theme,
      child: child,
    );
  }
}
