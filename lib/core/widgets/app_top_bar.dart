import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/app_spacing.dart';
import '../theme/frosted_surface.dart';

/// 与页面边缘连续的玻璃顶栏，可用于业务自行持有的 Scaffold。
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  const AppTopBar({
    required this.title,
    super.key,
    this.leading,
    this.actions = const [],
    this.automaticallyImplyLeading = true,
    this.toolbarHeight = 64,
  });

  final Widget title;
  final Widget? leading;
  final List<Widget> actions;
  final bool automaticallyImplyLeading;
  final double toolbarHeight;

  @override
  Size get preferredSize => Size.fromHeight(toolbarHeight);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final clear = colors.surface.withValues(alpha: 0);
    return AppBar(
      title: title,
      leading: leading ?? _impliedLeading(context),
      automaticallyImplyLeading: automaticallyImplyLeading,
      actions: actions,
      actionsPadding: const EdgeInsets.only(right: AppSpacing.s),
      toolbarHeight: toolbarHeight,
      titleSpacing: AppSpacing.l,
      centerTitle: false,
      backgroundColor: clear,
      surfaceTintColor: clear,
      elevation: 0,
      scrolledUnderElevation: 0,
      shape: const RoundedRectangleBorder(),
      flexibleSpace: FrostedSurface(
        borderRadius: BorderRadius.zero,
        borderColor: clear,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: colors.outlineVariant.withValues(alpha: 0.48),
              ),
            ),
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }

  Widget? _impliedLeading(BuildContext context) {
    if (!automaticallyImplyLeading) return null;
    final scaffold = Scaffold.maybeOf(context);
    final localizations = MaterialLocalizations.of(context);
    if (scaffold?.hasDrawer == true) {
      return IconButton(
        tooltip: localizations.openAppDrawerTooltip,
        onPressed: scaffold!.openDrawer,
        icon: const Icon(Symbols.menu),
      );
    }
    final route = ModalRoute.of(context);
    if (route?.impliesAppBarDismissal != true) return null;
    final close = route is PageRoute && route.fullscreenDialog;
    return IconButton(
      tooltip: close
          ? localizations.closeButtonTooltip
          : localizations.backButtonTooltip,
      onPressed: () => Navigator.of(context).maybePop(),
      icon: Icon(close ? Symbols.close : Symbols.arrow_back),
    );
  }
}
