import 'package:flutter/material.dart';

import '../theme/app_motion.dart';

/// 卡片和对话框在各自布局中提供端点，Hero 在同一个 Navigator 内连接它们。
class AppCardDialogRoute<T> extends PageRouteBuilder<T> {
  AppCardDialogRoute({
    required BuildContext context,
    required this.tag,
    required WidgetBuilder builder,
    super.settings,
    super.barrierDismissible = true,
  }) : super(
         opaque: false,
         allowSnapshotting: false,
         barrierColor: DialogTheme.of(context).barrierColor ?? Colors.black54,
         barrierLabel: MaterialLocalizations.of(context)
             .modalBarrierDismissLabel,
         transitionDuration: AppMotion.reduce(context)
             ? Duration.zero
             : AppMotion.pageOpen,
         reverseTransitionDuration: AppMotion.reduce(context)
             ? Duration.zero
             : AppMotion.pageClose,
         pageBuilder: _page(context, builder),
       );

  final Object tag;

  @override
  TraversalEdgeBehavior get traversalEdgeBehavior =>
      TraversalEdgeBehavior.closedLoop;

  static RoutePageBuilder _page(BuildContext context, WidgetBuilder builder) {
    final themes = InheritedTheme.capture(
      from: context,
      to: Navigator.of(context).context,
    );
    return (_, _, _) => themes.wrap(SafeArea(child: Builder(builder: builder)));
  }
}

class AppCardDialogPage extends Page<void> {
  const AppCardDialogPage({required this.tag, required this.child, super.key});
  final String tag;
  final Widget child;

  @override
  Route<void> createRoute(BuildContext context) => AppCardDialogRoute<void>(
    context: context,
    tag: tag,
    settings: this,
    builder: (context) =>
        (ModalRoute.settingsOf(context)! as AppCardDialogPage).child,
  );
}

class AppCardDialogHero extends StatelessWidget {
  const AppCardDialogHero({
    required this.tag,
    required this.color,
    required this.radius,
    required this.surfaceBuilder,
    required this.child,
    super.key,
  });
  final Object tag;
  final Color color;
  final double radius;
  final Widget Function(Widget content) surfaceBuilder;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final surface = surfaceBuilder(child);
    if (AppMotion.reduce(context)) return surface;
    return Hero(
      tag: tag,
      createRectTween: (begin, end) => RectTween(begin: begin, end: end),
      curve: AppMotion.pageCurve,
      reverseCurve: AppMotion.pageCurve,
      flightShuttleBuilder: _flight,
      child: surface,
    );
  }

  static Widget _flight(
    BuildContext context,
    Animation<double> progress,
    HeroFlightDirection direction,
    BuildContext from,
    BuildContext to,
  ) {
    final opening = direction == HeroFlightDirection.push;
    final entry = opening ? from : to;
    final panel = opening ? to : from;
    final source = entry.findAncestorWidgetOfExactType<AppCardDialogHero>()!;
    final target = panel.findAncestorWidgetOfExactType<AppCardDialogHero>()!;

    // 两端内容按各自的稳定尺寸布局，只在绘制时随卡片缩放。
    Widget face(BuildContext hero, Widget content) {
      final size = (hero.findRenderObject()! as RenderBox).size;
      return FittedBox(
        fit: BoxFit.contain,
        child: SizedBox.fromSize(
          size: size,
          child: RepaintBoundary(child: content),
        ),
      );
    }

    return AnimatedBuilder(
      animation: progress,
      builder: (context, content) => ClipRRect(
        borderRadius: BorderRadius.circular(
          source.radius + (target.radius - source.radius) * progress.value,
        ),
        child: ColoredBox(
          color: Color.lerp(source.color, target.color, progress.value)!,
          child: content,
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          fit: StackFit.expand,
          children: [
            FadeTransition(
              opacity: progress
                  .drive(CurveTween(curve: const Interval(0, .46)))
                  .drive(Tween(begin: 1.0, end: 0.0)),
              child: face(entry, source.child),
            ),
            FadeTransition(
              opacity: progress.drive(
                CurveTween(
                  curve: const Interval(.28, .95, curve: Curves.easeInOut),
                ),
              ),
              child: face(panel, target.child),
            ),
          ],
        ),
      ),
    );
  }
}
