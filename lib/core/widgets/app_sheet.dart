import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/frosted_surface.dart';

/// 用于 isScrollControlled、useSafeArea 且背景透明的模态底部面板。
///
/// 默认 child 是有界的可滚动区域（ListView，或含 Expanded 的列表布局），
/// 不再包裹第二层内容滚动。静态表单设置 scrollableChild: false。
/// 面板自行避让键盘，限宽 720dp、限高为剩余可用高度的 85%；极短窗口
/// 允许标题、有限高的列表视口与 footer 一起滚动，正常高度时 footer 固定。
class AppSheet extends StatelessWidget {
  const AppSheet({
    required this.title,
    required this.child,
    super.key,
    this.subtitle,
    this.titleTrailing,
    this.footer,
    this.showClose = true,
    this.scrollableChild = true,
  });

  final String title;
  final String? subtitle;

  /// 标题右侧的紧凑内容（如当前值摘要），空间不足时先于标题省略。
  final Widget? titleTrailing;
  final Widget child;
  final Widget? footer;
  final bool showClose;
  final bool scrollableChild;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final media = MediaQuery.maybeOf(context);
    final keyboard = media?.viewInsets.bottom ?? 0;
    final scale = math.max(1.0, (media?.textScaler.scale(14) ?? 14) / 14);
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.m,
        AppSpacing.l,
        AppSpacing.l,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: AppSpacing.xxl,
              height: AppSpacing.xs,
              decoration: BoxDecoration(
                color: colors.outlineVariant,
                borderRadius: AppRadius.smallAll,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.m),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Semantics(
                        header: true,
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleLarge,
                        ),
                      ),
                    ),
                    if (titleTrailing != null) ...[
                      const SizedBox(width: AppSpacing.m),
                      Flexible(child: titleTrailing!),
                    ],
                  ],
                ),
              ),
              if (showClose) ...[
                const SizedBox(width: AppSpacing.s),
                IconButton(
                  tooltip: '关闭',
                  onPressed: () => Navigator.of(context).maybePop(),
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  icon: const Icon(Symbols.close),
                ),
              ],
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtitle!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
    final footerWidget = footer == null
        ? const SizedBox.shrink()
        : DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: colors.outlineVariant.withValues(alpha: 0.56),
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.l),
              child: footer!,
            ),
          );

    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableHeight = constraints.hasBoundedHeight
              ? constraints.maxHeight
              : math.max(0.0, (media?.size.height ?? 600) - keyboard);
          return Align(
            alignment: Alignment.bottomCenter,
            heightFactor: 1,
            child: SizedBox(
              height: availableHeight * 0.85,
              width: math.min(constraints.maxWidth, 720),
              child: FrostedSurface(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadius.extraLarge),
                ),
                color: colors.surfaceContainerLow.withValues(
                  alpha: theme.brightness == Brightness.dark ? 0.98 : 0.96,
                ),
                child: SafeArea(
                  top: false,
                  child: LayoutBuilder(
                    builder: (context, panelConstraints) {
                      if (panelConstraints.maxHeight < 360 * scale) {
                        return SingleChildScrollView(
                          primary: false,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              header,
                              if (scrollableChild)
                                SizedBox(
                                  height: math.max(
                                    160 * scale,
                                    panelConstraints.maxHeight * 0.65,
                                  ),
                                  child: child,
                                )
                              else
                                child,
                              footerWidget,
                            ],
                          ),
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight: panelConstraints.maxHeight * 0.32,
                            ),
                            child: SingleChildScrollView(
                              primary: false,
                              child: header,
                            ),
                          ),
                          Expanded(
                            child: scrollableChild
                                ? child
                                : SingleChildScrollView(
                                    primary: false,
                                    child: child,
                                  ),
                          ),
                          if (footer != null)
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight: panelConstraints.maxHeight * 0.32,
                              ),
                              child: SingleChildScrollView(
                                primary: false,
                                child: footerWidget,
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
