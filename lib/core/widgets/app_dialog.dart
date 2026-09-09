import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/frosted_surface.dart';
import 'app_icon_badge.dart';

/// 可直接由 showDialog 返回的限宽弹窗。
///
/// 普通 content 由弹窗负责滚动；ListView 或含 Expanded 的列表布局应设置
/// scrollableContent: true，以获得有界视口，不参与 intrinsic 测量。
class AppDialog extends StatelessWidget {
  const AppDialog({
    required this.title,
    required this.content,
    super.key,
    this.description,
    this.icon,
    this.tone = AppTone.primary,
    this.actions = const [],
    this.scrollableContent = false,
  });

  final String title;
  final String? description;
  final IconData? icon;
  final AppTone tone;
  final Widget content;
  final List<Widget> actions;
  final bool scrollableContent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final media = MediaQuery.maybeOf(context);
    final scale = math.max(1.0, (media?.textScaler.scale(14) ?? 14) / 14);
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.l,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icon != null) ...[
                AppIconBadge(icon: icon!, tone: tone, size: 40, iconSize: 22),
                const SizedBox(width: AppSpacing.m),
              ],
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(title, style: theme.textTheme.titleLarge),
                ),
              ),
            ],
          ),
          if (description != null) ...[
            const SizedBox(height: AppSpacing.m),
            Text(
              description!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
    final footer = Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        actions.isEmpty ? 0 : AppSpacing.l,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      child: actions.isEmpty
          ? const SizedBox.shrink()
          : OverflowBar(
              alignment: MainAxisAlignment.end,
              overflowAlignment: OverflowBarAlignment.end,
              spacing: AppSpacing.s,
              overflowSpacing: AppSpacing.s,
              children: actions,
            ),
    );
    final insetContent = Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: content,
    );

    return Dialog(
      constraints: const BoxConstraints(maxWidth: 440),
      insetPadding: const EdgeInsets.all(AppSpacing.xl),
      insetAnimationDuration: media?.disableAnimations == true
          ? Duration.zero
          : const Duration(milliseconds: 200),
      backgroundColor: colors.surface.withValues(alpha: 0),
      surfaceTintColor: colors.surfaceTint.withValues(alpha: 0),
      elevation: 0,
      child: FrostedSurface(
        borderRadius: AppRadius.extraLargeAll,
        color: colors.surfaceContainerLow.withValues(
          alpha: theme.brightness == Brightness.dark ? 0.98 : 0.96,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxHeight < 360 * scale) {
              return SingleChildScrollView(
                primary: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    header,
                    if (scrollableContent)
                      SizedBox(
                        height: math.max(
                          160 * scale,
                          constraints.maxHeight * 0.55,
                        ),
                        child: insetContent,
                      )
                    else
                      insetContent,
                    footer,
                  ],
                ),
              );
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: constraints.maxHeight * 0.35,
                  ),
                  child: SingleChildScrollView(primary: false, child: header),
                ),
                Flexible(
                  child: scrollableContent
                      ? insetContent
                      : SingleChildScrollView(
                          primary: false,
                          child: insetContent,
                        ),
                ),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: constraints.maxHeight * 0.35,
                  ),
                  child: SingleChildScrollView(primary: false, child: footer),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
