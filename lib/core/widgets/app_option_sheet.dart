import 'package:flutter/material.dart';

import '../theme/app_motion.dart';
import 'app_popup_transition.dart';

Future<T?> showAppOptionSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Color? backgroundColor,
  bool? showDragHandle,
}) {
  final navigator = Navigator.of(context);
  final labels = MaterialLocalizations.of(context);
  return navigator.push(
    AppOptionSheetRoute<T>(
      builder: builder,
      capturedThemes: InheritedTheme.capture(
        from: context,
        to: navigator.context,
      ),
      barrierLabel: labels.scrimLabel,
      barrierOnTapHint: labels.scrimOnTapHint(labels.bottomSheetLabel),
      modalBarrierColor: Theme.of(context).bottomSheetTheme.modalBarrierColor,
      backgroundColor: backgroundColor,
      showDragHandle: showDragHandle,
      sheetAnimationStyle: AppMotion.sheetStyle(context),
    ),
  );
}

class AppOptionSheetRoute<T> extends ModalBottomSheetRoute<T> {
  AppOptionSheetRoute({
    required WidgetBuilder builder,
    super.capturedThemes,
    required super.barrierLabel,
    super.barrierOnTapHint,
    super.modalBarrierColor,
    super.backgroundColor,
    super.showDragHandle,
    required super.sheetAnimationStyle,
  }) : super(
         isScrollControlled: true,
         useSafeArea: true,
         builder: (context) => RepaintBoundary(child: builder(context)),
       );

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (AppMotion.reduce(context)) return child;
    return AppPopupTransition(
      alignment: Alignment.bottomCenter,
      progress: animation,
      child: child,
    );
  }
}
