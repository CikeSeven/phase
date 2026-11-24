import 'package:flutter/material.dart';

/// Expressive 快速空间弹簧用于形状；颜色使用无回弹的短过渡。
abstract final class AppMotion {
  static const effects = Duration(milliseconds: 200);
  static const menuOpen = Duration(milliseconds: 300);
  static const menuClose = Duration(milliseconds: 210);
  static const menuCurve = Cubic(0.2, 0.8, 0.2, 1);
  static const menuReverseCurve = Cubic(0.30, 0, 0.64, 0.88);
  static const pageOpen = Duration(milliseconds: 480);
  static const pageClose = Duration(milliseconds: 360);
  static const pageCurve = Cubic(.30, .12, .28, 1);
  static const sheetOpen = Duration(milliseconds: 340);
  static const sheetClose = Duration(milliseconds: 220);
  static const expansionOpen = Duration(milliseconds: 280);
  static const expansionClose = Duration(milliseconds: 180);
  static const expansionCurve = Curves.easeOutCubic;
  static const expansionSpacingCurve = Interval(
    0.4,
    1,
    curve: Curves.easeOutCubic,
  );

  static final shapeSpring = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 800,
    ratio: 0.6,
  );

  // Android 无障碍控件读取也会开启 accessibleNavigation，并不代表减少动画。
  static bool reduce(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context);

  static AnimationStyle sheetStyle(BuildContext context) => reduce(context)
      ? AnimationStyle.noAnimation
      : const AnimationStyle(duration: sheetOpen, reverseDuration: sheetClose);
}

class AppPageTransitionsBuilder extends PageTransitionsBuilder {
  const AppPageTransitionsBuilder();
  static final slide = Tween<Offset>(
    begin: const Offset(1, 0),
    end: Offset.zero,
  ).chain(CurveTween(curve: AppMotion.pageCurve));
  @override
  Duration get transitionDuration => AppMotion.pageOpen;
  @override
  Duration get reverseTransitionDuration => AppMotion.pageClose;
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => AppMotion.reduce(context)
      ? child
      : SlideTransition(position: animation.drive(slide), child: child);
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
