import 'package:flutter/material.dart';

import '../theme/app_motion.dart';

class SettingsMaterialPage extends MaterialPage<void> {
  const SettingsMaterialPage({required super.child, super.key});

  @override
  Route<void> createRoute(BuildContext context) => _SettingsRoute(this);
}

class _SettingsRoute extends PageRoute<void>
    with MaterialRouteTransitionMixin<void> {
  _SettingsRoute(SettingsMaterialPage page) : super(settings: page);

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => AppMotion.pageOpen;

  @override
  Duration get reverseTransitionDuration => AppMotion.pageClose;

  @override
  Widget buildContent(BuildContext context) =>
      (settings as SettingsMaterialPage).child;

  // 底层页面保持静止，无需订阅上层设置页的动画帧。
  @override
  bool canTransitionFrom(TransitionRoute<dynamic> previousRoute) => false;

  @override
  DelegatedTransitionBuilder? get delegatedTransition => null;

  // Android 在手势提交后执行普通返回，此时路由动画才开始。
  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (AppMotion.reduce(context)) return child;
    return SlideTransition(
      position: animation.drive(AppPageTransitionsBuilder.slide),
      child: child,
    );
  }
}
