import 'package:flutter/material.dart';

import 'app_motion.dart';
import 'app_radius.dart';
import 'app_spacing.dart';

/// Expressive 按钮的尺寸与形状状态；不覆盖各按钮种类的语义色。
abstract final class AppControlStyle {
  static const touchTarget = 48.0;
  static const mediumHeight = 56.0;

  static final medium = ButtonStyle(
    minimumSize: const WidgetStatePropertyAll(Size(touchTarget, mediumHeight)),
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.m),
    ),
    shape: shape(),
    animationDuration: AppMotion.effects,
  );

  static final compact = ButtonStyle(
    minimumSize: const WidgetStatePropertyAll(Size.square(touchTarget)),
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: AppSpacing.l, vertical: AppSpacing.m),
    ),
    shape: shape(compact: true),
    animationDuration: AppMotion.effects,
  );

  /// 胶囊 → 按压圆角；选中/运行态保留圆角方形，禁用时忽略按压状态。
  static WidgetStateProperty<OutlinedBorder> shape({
    bool compact = false,
    bool active = false,
  }) => WidgetStateProperty.resolveWith((states) {
    if (!states.contains(WidgetState.disabled) &&
        states.contains(WidgetState.pressed)) {
      return RoundedRectangleBorder(
        borderRadius: compact ? AppRadius.extraSmallAll : AppRadius.controlAll,
      );
    }
    if (active || states.contains(WidgetState.selected)) {
      return RoundedRectangleBorder(
        borderRadius: compact ? AppRadius.controlAll : AppRadius.mediumAll,
      );
    }
    return const StadiumBorder();
  });
}
