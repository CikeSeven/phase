import 'package:flutter/material.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/frosted_surface.dart';

/// 输入栏的月色玻璃：模糊限于圆角内部，轻阴影与高光区分悬浮层次。
class ChatInputSurface extends StatelessWidget {
  const ChatInputSurface({
    required this.focused,
    required this.child,
    super.key,
  });

  final bool focused;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final highlight = dark ? colors.onSurface : colors.surfaceContainerLowest;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: AppRadius.largeAll,
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: dark ? 0.18 : 0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: FrostedSurface(
        blur: 20,
        color:
            (dark ? colors.surfaceContainerLow : colors.surfaceContainerLowest)
                .withValues(alpha: dark ? 0.68 : 0.58),
        borderColor: focused
            ? colors.primary
            : highlight.withValues(alpha: dark ? 0.16 : 0.64),
        // 高光画在 Material 上，附件和动作按钮的 ink 反馈仍在其上方。
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: const [0, 0.5, 1],
              colors: [
                highlight.withValues(alpha: dark ? 0.02 : 0.12),
                highlight.withValues(alpha: dark ? 0.005 : 0.03),
                colors.primary.withValues(alpha: dark ? 0.02 : 0.015),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.m,
              0,
              AppSpacing.m,
              AppSpacing.s,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
