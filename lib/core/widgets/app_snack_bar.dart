import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/frosted_surface.dart';

/// 保留 SDK 的队列、计时与关闭语义；玻璃仅覆盖提示本身，不覆盖外部留白。
SnackBar buildAppSnackBar({required Widget content, SnackBarAction? action}) {
  return SnackBar(
    backgroundColor: Colors.transparent,
    elevation: 0,
    padding: EdgeInsets.zero,
    shape: const RoundedRectangleBorder(borderRadius: AppRadius.mediumAll),
    showCloseIcon: false,
    hitTestBehavior: HitTestBehavior.deferToChild,
    // 动作放在同一块玻璃内，仍沿用 SDK 有动作时等待操作的行为。
    persist: action != null,
    content: _SnackBarSurface(content: content, action: action),
  );
}

class _SnackBarSurface extends StatelessWidget {
  const _SnackBarSurface({required this.content, this.action});

  final Widget content;
  final SnackBarAction? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final snackBarTheme = SnackBarTheme.of(context);
    final shape = snackBarTheme.shape;
    final action = this.action;

    return FrostedSurface(
      borderRadius: AppRadius.mediumAll,
      blur: 28,
      color: snackBarTheme.backgroundColor,
      borderColor: shape is RoundedRectangleBorder ? shape.side.color : null,
      padding: const EdgeInsets.fromLTRB(AppSpacing.m, 0, AppSpacing.xs, 0),
      child: DefaultTextStyle(
        style: snackBarTheme.contentTextStyle ?? theme.textTheme.bodyMedium!,
        child: LayoutBuilder(
          builder: (context, constraints) {
            var stackAction = false;
            if (action != null) {
              final painter = TextPainter(
                text: TextSpan(
                  text: action.label,
                  style: theme.textTheme.labelLarge,
                ),
                textDirection: Directionality.of(context),
                textScaler: MediaQuery.textScalerOf(context),
                maxLines: 1,
              )..layout();
              final actionWidth = painter.width + AppSpacing.l * 2;
              painter.dispose();
              stackAction = actionWidth > constraints.maxWidth * 0.25;
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.s,
                        ),
                        child: content,
                      ),
                    ),
                    if (action != null && !stackAction) action,
                    IconButton(
                      tooltip: '关闭提示',
                      iconSize: 20,
                      color: snackBarTheme.closeIconColor,
                      onPressed: () => ScaffoldMessenger.of(context)
                          .hideCurrentSnackBar(
                            reason: SnackBarClosedReason.dismiss,
                          ),
                      icon: const Icon(Symbols.close),
                    ),
                  ],
                ),
                if (action != null && stackAction)
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: action,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
