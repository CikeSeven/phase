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
    this.showDivider = true,
    this.titleSpacing = AppSpacing.l,
    this.bottom,
  });

  final Widget title;
  final Widget? leading;
  final List<Widget> actions;
  final bool automaticallyImplyLeading;
  final double toolbarHeight;
  final bool showDivider;

  /// 标题两侧留白；聊天页传更小的值，给模型名留出更多截断空间。
  final double titleSpacing;
  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize =>
      Size.fromHeight(toolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final clear = colors.surface.withValues(alpha: 0);
    final highlight = dark ? colors.onSurface : colors.surfaceContainerLowest;
    return AppBar(
      title: title,
      leading: leading ?? _impliedLeading(context),
      automaticallyImplyLeading: automaticallyImplyLeading,
      actions: actions,
      actionsPadding: const EdgeInsets.only(right: AppSpacing.s),
      toolbarHeight: toolbarHeight,
      bottom: bottom,
      titleSpacing: titleSpacing,
      centerTitle: false,
      backgroundColor: clear,
      surfaceTintColor: clear,
      elevation: 0,
      scrolledUnderElevation: 0,
      shape: const RoundedRectangleBorder(),
      flexibleSpace: Padding(
        // 玻璃底色只覆盖工具栏，底部进度区域沿用下方页面画布。
        padding: EdgeInsets.only(bottom: bottom?.preferredSize.height ?? 0),
        child: FrostedSurface(
          borderRadius: BorderRadius.zero,
          borderColor: clear,
          color:
              (dark
                      ? colors.surfaceContainerLow
                      : colors.surfaceContainerLowest)
                  .withValues(alpha: dark ? 0.42 : 0.28),
          blur: 24,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: const [0, 0.5, 1],
                colors: [
                  highlight.withValues(alpha: dark ? 0.025 : 0.08),
                  highlight.withValues(alpha: dark ? 0.005 : 0.015),
                  colors.primary.withValues(alpha: dark ? 0.025 : 0.015),
                ],
              ),
              border: showDivider
                  ? Border(
                      bottom: BorderSide(
                        color: colors.outlineVariant.withValues(alpha: 0.16),
                      ),
                    )
                  : null,
            ),
            child: const SizedBox.expand(),
          ),
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
