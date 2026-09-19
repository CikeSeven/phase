import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import 'app_background.dart';
import 'app_bottom_bar.dart';
import 'app_top_bar.dart';

export 'app_top_bar.dart';

/// 普通页面壳；body 不额外添加留白，宽屏默认限宽 720dp。
///
/// bottomBar 可传操作内容或 AppBottomBar，安全区和键盘位移只处理一次。
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    required this.title,
    required this.body,
    super.key,
    this.subtitle,
    this.actions = const [],
    this.bottomBar,
    this.floatingActionButton,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.maxBodyWidth = 720,
    this.showAppBarDivider = true,
    this.appBarBottom,
  }) : assert(maxBodyWidth > 0);

  final String title;
  final Widget body;
  final String? subtitle;
  final List<Widget> actions;
  final Widget? bottomBar;
  final Widget? floatingActionButton;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final double maxBodyWidth;
  final bool showAppBarDivider;
  final PreferredSizeWidget? appBarBottom;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.maybeOf(context);
    final scaler = media?.textScaler ?? TextScaler.noScaling;
    final titleStyle = theme.textTheme.titleLarge;
    final subtitleStyle = theme.textTheme.bodySmall;
    final titleHeight =
        scaler.scale(titleStyle?.fontSize ?? 22) * (titleStyle?.height ?? 1.25);
    final subtitleHeight = subtitle == null
        ? 0.0
        : scaler.scale(subtitleStyle?.fontSize ?? 12) *
                  (subtitleStyle?.height ?? 1.45) +
              AppSpacing.xs;
    final bar = bottomBar;

    return AppBackground(
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface.withValues(alpha: 0),
        appBar: AppTopBar(
          toolbarHeight: math.max(
            64,
            titleHeight + subtitleHeight + AppSpacing.l,
          ),
          leading: leading,
          automaticallyImplyLeading: automaticallyImplyLeading,
          showDivider: showAppBarDivider,
          bottom: appBarBottom,
          actions: actions,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: titleStyle,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: subtitleStyle?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        body: SafeArea(
          top: false,
          bottom: bar == null,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxBodyWidth),
              child: SizedBox.expand(child: body),
            ),
          ),
        ),
        bottomNavigationBar: bar == null
            ? null
            : Padding(
                padding: EdgeInsets.only(bottom: media?.viewInsets.bottom ?? 0),
                child: bar is AppBottomBar ? bar : AppBottomBar(child: bar),
              ),
        floatingActionButton: floatingActionButton,
      ),
    );
  }
}
