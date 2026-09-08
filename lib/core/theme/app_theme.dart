import 'package:flutter/material.dart';

import 'app_radius.dart';
import 'brand_colors.dart';

/// 落地 DESIGN.md 的主题构建：月夜靛蓝种子色 + 月华金扩展。
abstract final class AppTheme {
  /// 月夜靛蓝（DESIGN.md §2.1 主种子色）。
  static const seedColor = Color(0xFF3D5A98);

  static ThemeData light() => _build(
    ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.light),
    BrandColors.light,
  );

  static ThemeData dark() => _build(
    ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.dark),
    BrandColors.dark,
  );

  static ThemeData _build(ColorScheme colorScheme, BrandColors brandColors) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      extensions: [brandColors],
      // 内容优先：AppBar 不加阴影，靠色调分层。
      appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: AppRadius.mediumAll,
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.mediumAll,
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mediumAll),
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      drawerTheme: DrawerThemeData(backgroundColor: colorScheme.surface),
    );
  }
}
