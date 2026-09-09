import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/frosted_surface.dart';

/// 固定操作栏，自行处理底部系统安全区；键盘位移由 AppScaffold 处理。
class AppBottomBar extends StatelessWidget {
  const AppBottomBar({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return FrostedSurface(
      borderRadius: BorderRadius.zero,
      borderColor: colors.outlineVariant.withValues(alpha: 0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: colors.outlineVariant.withValues(alpha: 0.56),
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.l),
            child: child,
          ),
        ),
      ),
    );
  }
}
