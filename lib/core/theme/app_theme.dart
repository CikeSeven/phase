import 'package:flutter/material.dart';

import 'app_radius.dart';
import 'app_spacing.dart';
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
      scaffoldBackgroundColor: colorScheme.surfaceContainerLowest,
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          // M3 前进淡入 + 返回淡出转场，且原生支持 Android 14+ 预测性返回预览。
          TargetPlatform.android: const FadeForwardsPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: colorScheme.surface.withValues(alpha: 0.72),
        surfaceTintColor: colorScheme.surface.withValues(alpha: 0),
        foregroundColor: colorScheme.onSurface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(AppRadius.large),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHigh.withValues(alpha: 0.76),
        border: OutlineInputBorder(
          borderRadius: AppRadius.mediumAll,
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.mediumAll,
          borderSide: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.72),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.mediumAll,
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.l,
          vertical: AppSpacing.m,
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.extraLargeAll),
        backgroundColor: colorScheme.surfaceContainerHigh,
        surfaceTintColor: colorScheme.surfaceTint.withValues(alpha: 0.12),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.extraLarge),
          ),
        ),
        backgroundColor: colorScheme.surfaceContainerHigh,
        surfaceTintColor: colorScheme.surfaceTint.withValues(alpha: 0.12),
      ),
      cardTheme: CardThemeData(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.largeAll),
        color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.72),
        surfaceTintColor: colorScheme.surfaceTint.withValues(alpha: 0.08),
        elevation: 0,
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mediumAll),
        tileColor: colorScheme.surfaceContainerHigh.withValues(alpha: 0.56),
        selectedTileColor: colorScheme.primaryContainer.withValues(alpha: 0.82),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        minVerticalPadding: 8,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.fullAll),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.fullAll),
        elevation: 2,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.fullAll),
        backgroundColor: colorScheme.inverseSurface.withValues(alpha: 0.94),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: colorScheme.surface.withValues(alpha: 0.72),
        surfaceTintColor: colorScheme.surfaceTint.withValues(alpha: 0.08),
        elevation: 0,
      ),
    );
  }
}
