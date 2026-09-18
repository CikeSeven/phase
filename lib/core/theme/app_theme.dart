import 'package:flutter/material.dart';

import 'app_control_style.dart';
import 'app_motion.dart';
import 'app_radius.dart';
import 'app_spacing.dart';
import 'brand_colors.dart';

/// 保留月色玻璃配色与材质的 Material 3 Expressive 主题。
abstract final class AppTheme {
  static const seedColor = Color(0xFF3D5A98);

  static ThemeData light() => _build(
    ColorScheme.fromSeed(seedColor: seedColor).copyWith(
      surface: const Color(0xFFF5F7FC),
      surfaceDim: const Color(0xFFDCE2EF),
      surfaceBright: const Color(0xFFFAFBFF),
      surfaceContainerLowest: const Color(0xFFFFFFFF),
      surfaceContainerLow: const Color(0xFFF0F3FA),
      surfaceContainer: const Color(0xFFE9EEF7),
      surfaceContainerHigh: const Color(0xFFE3E9F3),
      surfaceContainerHighest: const Color(0xFFDBE3F0),
      onSurface: const Color(0xFF182338),
      onSurfaceVariant: const Color(0xFF475469),
      outline: const Color(0xFF747F92),
      outlineVariant: const Color(0xFFC4CEDF),
    ),
    BrandColors.light,
  );

  static ThemeData dark() => _build(
    ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.dark,
    ).copyWith(
      surface: const Color(0xFF0C1423),
      surfaceDim: const Color(0xFF0C1423),
      surfaceBright: const Color(0xFF2B3B54),
      surfaceContainerLowest: const Color(0xFF080F1C),
      surfaceContainerLow: const Color(0xFF101B2B),
      surfaceContainer: const Color(0xFF152235),
      surfaceContainerHigh: const Color(0xFF1A2940),
      surfaceContainerHighest: const Color(0xFF21314A),
      onSurface: const Color(0xFFE4EAF7),
      onSurfaceVariant: const Color(0xFFBAC6DC),
      outline: const Color(0xFF8795AD),
      outlineVariant: const Color(0xFF35465F),
    ),
    BrandColors.dark,
  );

  static ThemeData _build(ColorScheme colors, BrandColors brandColors) {
    final dark = colors.brightness == Brightness.dark;
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colors,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
    );
    final text = base.textTheme
        .copyWith(
          headlineMedium: base.textTheme.headlineMedium?.copyWith(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            height: 1.25,
          ),
          headlineSmall: base.textTheme.headlineSmall?.copyWith(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            height: 1.3,
          ),
          titleLarge: base.textTheme.titleLarge?.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            height: 1.25,
          ),
          titleMedium: base.textTheme.titleMedium?.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            height: 1.4,
          ),
          titleSmall: base.textTheme.titleSmall?.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            height: 1.4,
          ),
          bodyLarge: base.textTheme.bodyLarge?.copyWith(
            fontSize: 16,
            height: 1.5,
          ),
          bodyMedium: base.textTheme.bodyMedium?.copyWith(
            fontSize: 14,
            height: 1.5,
          ),
          bodySmall: base.textTheme.bodySmall?.copyWith(
            fontSize: 12,
            height: 1.45,
          ),
          labelLarge: base.textTheme.labelLarge?.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            height: 1.25,
          ),
          labelMedium: base.textTheme.labelMedium?.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            height: 1.3,
          ),
          labelSmall: base.textTheme.labelSmall?.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            height: 1.3,
          ),
        )
        .apply(bodyColor: colors.onSurface, displayColor: colors.onSurface);
    final outline = colors.outlineVariant.withValues(alpha: 0.68);
    final transparent = colors.surface.withValues(alpha: 0);
    const menuShape = RoundedRectangleBorder(borderRadius: AppRadius.largeAll);
    OutlineInputBorder inputBorder(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: AppRadius.mediumAll,
          borderSide: BorderSide(color: color, width: width),
        );

    return base.copyWith(
      extensions: [brandColors],
      textTheme: text,
      scaffoldBackgroundColor: colors.surface,
      canvasColor: colors.surface,
      dividerColor: outline,
      dividerTheme: DividerThemeData(color: outline, thickness: 1, space: 1),
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          // 非手势导航使用 SDK 默认过渡，手势返回保留 Android 预测预览。
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(
            fallbackColor: colors.surface,
          ),
        },
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        toolbarHeight: 64,
        titleSpacing: AppSpacing.l,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: colors.surface.withValues(alpha: dark ? 0.92 : 0.86),
        surfaceTintColor: transparent,
        foregroundColor: colors.onSurface,
        titleTextStyle: text.titleLarge,
        iconTheme: IconThemeData(color: colors.onSurfaceVariant, size: 24),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceContainerLowest.withValues(
          alpha: dark ? 0.56 : 0.84,
        ),
        border: inputBorder(outline),
        enabledBorder: inputBorder(outline),
        focusedBorder: inputBorder(colors.primary, 2),
        errorBorder: inputBorder(colors.error),
        focusedErrorBorder: inputBorder(colors.error, 2),
        labelStyle: text.bodyLarge?.copyWith(color: colors.onSurfaceVariant),
        hintStyle: text.bodyLarge?.copyWith(color: colors.onSurfaceVariant),
        helperStyle: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
        errorStyle: text.bodySmall?.copyWith(color: colors.error),
        errorMaxLines: 3,
        contentPadding: const EdgeInsets.all(AppSpacing.l),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: colors.primary,
        selectionColor: colors.primary.withValues(alpha: dark ? 0.28 : 0.18),
        selectionHandleColor: colors.primary,
      ),
      dialogTheme: DialogThemeData(
        constraints: const BoxConstraints(maxWidth: 440),
        insetPadding: const EdgeInsets.all(AppSpacing.xl),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.extraLargeAll,
          side: BorderSide(color: outline),
        ),
        backgroundColor: colors.surfaceContainerLow,
        surfaceTintColor: transparent,
        elevation: 2,
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        constraints: const BoxConstraints(maxWidth: 720),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.extraLarge),
          ),
        ),
        backgroundColor: colors.surfaceContainerLow,
        surfaceTintColor: transparent,
        elevation: 0,
        modalElevation: 2,
        showDragHandle: false,
        dragHandleColor: colors.outlineVariant,
        dragHandleSize: const Size(AppSpacing.xxl, AppSpacing.xs),
        clipBehavior: Clip.antiAlias,
      ),
      cardTheme: CardThemeData(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.largeAll,
          side: BorderSide(color: outline),
        ),
        color: colors.surfaceContainerLow.withValues(alpha: dark ? 0.88 : 0.80),
        surfaceTintColor: transparent,
        elevation: 0,
      ),
      listTileTheme: ListTileThemeData(
        titleTextStyle: text.titleMedium,
        subtitleTextStyle: text.bodyMedium?.copyWith(
          color: colors.onSurfaceVariant,
        ),
        leadingAndTrailingTextStyle: text.bodySmall?.copyWith(
          color: colors.onSurfaceVariant,
        ),
        iconColor: colors.onSurfaceVariant,
        textColor: colors.onSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.l,
          vertical: AppSpacing.xs,
        ),
        horizontalTitleGap: AppSpacing.m,
        minVerticalPadding: AppSpacing.s,
        minTileHeight: 56,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: AppControlStyle.medium.copyWith(
          textStyle: WidgetStatePropertyAll(text.titleMedium),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: AppControlStyle.medium.copyWith(
          textStyle: WidgetStatePropertyAll(text.titleMedium),
          elevation: const WidgetStatePropertyAll(1),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: AppControlStyle.medium.copyWith(
          side: WidgetStateProperty.resolveWith(
            (states) => BorderSide(
              color: states.contains(WidgetState.disabled)
                  ? colors.onSurface.withValues(alpha: 0.12)
                  : colors.outline,
            ),
          ),
          textStyle: WidgetStatePropertyAll(text.titleMedium),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: AppControlStyle.compact.copyWith(
          textStyle: WidgetStatePropertyAll(text.labelLarge),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: AppControlStyle.compact.copyWith(
          padding: const WidgetStatePropertyAll(EdgeInsets.all(AppSpacing.m)),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: AppControlStyle.compact.copyWith(
          textStyle: WidgetStatePropertyAll(text.labelLarge),
          side: const WidgetStatePropertyAll(BorderSide.none),
          shape: const WidgetStatePropertyAll(StadiumBorder()),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return colors.onSurface.withValues(alpha: 0.12);
            }
            return states.contains(WidgetState.selected)
                ? colors.primaryContainer
                : colors.surfaceContainerLow.withValues(alpha: 0.72);
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return colors.onSurface.withValues(alpha: 0.38);
            }
            return states.contains(WidgetState.selected)
                ? colors.onPrimaryContainer
                : colors.onSurface;
          }),
        ),
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 16,
        trackGap: 6,
        trackShape: const GappedSliderTrackShape(),
        thumbShape: const HandleThumbShape(),
        thumbSize: WidgetStateProperty.resolveWith(
          (states) => Size(
            !states.contains(WidgetState.disabled) &&
                    (states.contains(WidgetState.pressed) ||
                        states.contains(WidgetState.focused))
                ? 2
                : 4,
            44,
          ),
        ),
        tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 2),
        inactiveTrackColor: colors.secondaryContainer,
        activeTickMarkColor: colors.onPrimary,
        inactiveTickMarkColor: colors.onSecondaryContainer,
        valueIndicatorShape: const RoundedRectSliderValueIndicatorShape(),
        valueIndicatorColor: colors.inverseSurface,
        valueIndicatorTextStyle: text.labelLarge?.copyWith(
          color: colors.onInverseSurface,
        ),
      ),
      chipTheme: ChipThemeData(
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.smallAll),
        side: BorderSide(color: outline),
        backgroundColor: colors.surfaceContainerLow,
        selectedColor: colors.primaryContainer,
        secondarySelectedColor: colors.primaryContainer,
        checkmarkColor: colors.onPrimaryContainer,
        labelStyle: text.labelMedium?.copyWith(color: colors.onSurface),
        secondaryLabelStyle: text.labelMedium?.copyWith(
          color: colors.onPrimaryContainer,
        ),
        labelPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.s),
        padding: const EdgeInsets.all(AppSpacing.s),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(colors.surfaceContainer),
          surfaceTintColor: WidgetStatePropertyAll(transparent),
          shape: WidgetStatePropertyAll(menuShape),
          elevation: const WidgetStatePropertyAll(2),
          padding: const WidgetStatePropertyAll(EdgeInsets.all(AppSpacing.s)),
        ),
      ),
      menuButtonTheme: MenuButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
          textStyle: WidgetStatePropertyAll(text.bodyMedium),
          shape: WidgetStateProperty.resolveWith(
            (states) => RoundedRectangleBorder(
              borderRadius:
                  !states.contains(WidgetState.disabled) &&
                      states.contains(WidgetState.pressed)
                  ? AppRadius.smallAll
                  : states.contains(WidgetState.selected)
                  ? AppRadius.largeAll
                  : AppRadius.mediumAll,
            ),
          ),
          animationDuration: AppMotion.effects,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colors.surfaceContainer,
        surfaceTintColor: transparent,
        shape: menuShape,
        elevation: 2,
        labelTextStyle: WidgetStatePropertyAll(text.bodyMedium),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.controlAll),
        backgroundColor: colors.primaryContainer,
        foregroundColor: colors.onPrimaryContainer,
        elevation: 2,
        highlightElevation: 3,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.mediumAll),
        backgroundColor: colors.inverseSurface,
        contentTextStyle: text.bodyMedium?.copyWith(
          color: colors.onInverseSurface,
        ),
        actionTextColor: colors.inversePrimary,
        elevation: 2,
        insetPadding: const EdgeInsets.all(AppSpacing.l),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: colors.surfaceContainerLow.withValues(
          alpha: dark ? 0.94 : 0.88,
        ),
        surfaceTintColor: transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(
            right: Radius.circular(AppRadius.extraLarge),
          ),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: colors.inverseSurface,
          borderRadius: AppRadius.smallAll,
        ),
        textStyle: text.bodySmall?.copyWith(color: colors.onInverseSurface),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.m,
          vertical: AppSpacing.s,
        ),
      ),
    );
  }
}
