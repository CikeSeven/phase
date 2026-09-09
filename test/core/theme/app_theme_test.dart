import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/theme/app_radius.dart';
import 'package:phase/core/theme/app_theme.dart';
import 'package:phase/core/theme/brand_colors.dart';

void main() {
  for (final (name, theme) in [
    ('light', AppTheme.light()),
    ('dark', AppTheme.dark()),
  ]) {
    group(name, () {
      test('语义色和容器文字满足正文对比度', () {
        final colors = theme.colorScheme;
        final brand = theme.extension<BrandColors>()!;
        final pairs = <String, (Color, Color)>{
          'primary': (colors.onPrimary, colors.primary),
          'primaryContainer': (
            colors.onPrimaryContainer,
            colors.primaryContainer,
          ),
          'error': (colors.onError, colors.error),
          'errorContainer': (colors.onErrorContainer, colors.errorContainer),
          'gold': (brand.onGold, brand.gold),
          'goldContainer': (brand.onGoldContainer, brand.goldContainer),
          'teal': (brand.onTeal, brand.teal),
          'tealContainer': (brand.onTealContainer, brand.tealContainer),
          'lavender': (brand.onLavender, brand.lavender),
          'lavenderContainer': (
            brand.onLavenderContainer,
            brand.lavenderContainer,
          ),
        };
        for (final entry in pairs.entries) {
          _expectContrast(entry.value.$1, entry.value.$2, entry.key);
        }
        for (final accent in [brand.gold, brand.teal, brand.lavender]) {
          _expectContrast(accent, colors.surface, 'accent on canvas');
        }
      });

      test('合成玻璃、语义衬色与背景色域后正文和说明仍清晰', () {
        final colors = theme.colorScheme;
        final brand = theme.extension<BrandColors>()!;
        final dark = theme.brightness == Brightness.dark;
        final canvasColors = [
          colors.surface,
          for (final tint in [colors.primary, brand.teal, brand.lavender])
            Color.alphaBlend(tint.withValues(alpha: 0.12), colors.surface),
        ];
        final base = dark
            ? colors.surfaceContainerLow
            : colors.surfaceContainerLowest;
        for (final canvas in canvasColors) {
          final backgrounds = [
            canvas,
            Color.alphaBlend(
              base.withValues(alpha: dark ? 0.88 : 0.80),
              canvas,
            ),
            colors.surfaceContainerHigh,
            colors.surfaceContainerHighest,
            for (final tint in [brand.gold, brand.teal, brand.lavender])
              Color.alphaBlend(
                Color.alphaBlend(
                  tint.withValues(alpha: dark ? 0.09 : 0.045),
                  base,
                ).withValues(alpha: dark ? 0.88 : 0.80),
                canvas,
              ),
          ];
          for (final background in backgrounds) {
            _expectContrast(colors.onSurface, background, 'body on composite');
            _expectContrast(
              colors.onSurfaceVariant,
              background,
              'detail on composite',
            );
          }
        }
      });

      test('文字、触区与 Android 预测返回构成稳定主题合同', () {
        expect(theme.textTheme.bodyLarge?.fontSize, 16);
        expect(theme.textTheme.bodyLarge?.height, 1.5);
        expect(theme.listTileTheme.tileColor, isNull);
        expect(theme.listTileTheme.selectedTileColor, isNull);
        for (final style in [
          theme.filledButtonTheme.style,
          theme.elevatedButtonTheme.style,
          theme.outlinedButtonTheme.style,
          theme.textButtonTheme.style,
          theme.iconButtonTheme.style,
          theme.segmentedButtonTheme.style,
        ]) {
          final minimum = style!.minimumSize!.resolve({})!;
          expect(minimum.height, greaterThanOrEqualTo(48));
          expect(minimum.width, greaterThanOrEqualTo(48));
        }
        final input =
            theme.inputDecorationTheme.enabledBorder! as OutlineInputBorder;
        expect(input.borderRadius, AppRadius.mediumAll);
        expect(AppRadius.extraLarge, 32);
        expect(theme.appBarTheme.shape, isNull);
        expect(
          theme.pageTransitionsTheme.builders[TargetPlatform.android],
          isA<PredictiveBackPageTransitionsBuilder>(),
        );
      });
    });
  }

  test('BrandColors 所有语义色参与 copyWith 与明暗插值', () {
    const light = BrandColors.light;
    const dark = BrandColors.dark;
    final midpoint = light.lerp(dark, 0.5);
    final changed = light.copyWith(
      teal: dark.teal,
      onTeal: dark.onTeal,
      tealContainer: dark.tealContainer,
      onTealContainer: dark.onTealContainer,
      lavender: dark.lavender,
      onLavender: dark.onLavender,
      lavenderContainer: dark.lavenderContainer,
      onLavenderContainer: dark.onLavenderContainer,
    );
    expect(changed.gold, light.gold);
    expect(changed.teal, dark.teal);
    expect(changed.onTeal, dark.onTeal);
    expect(changed.tealContainer, dark.tealContainer);
    expect(changed.onTealContainer, dark.onTealContainer);
    expect(changed.lavender, dark.lavender);
    expect(changed.onLavender, dark.onLavender);
    expect(changed.lavenderContainer, dark.lavenderContainer);
    expect(changed.onLavenderContainer, dark.onLavenderContainer);
    for (final (actual, from, to) in [
      (midpoint.gold, light.gold, dark.gold),
      (midpoint.onGold, light.onGold, dark.onGold),
      (midpoint.goldContainer, light.goldContainer, dark.goldContainer),
      (midpoint.onGoldContainer, light.onGoldContainer, dark.onGoldContainer),
      (midpoint.teal, light.teal, dark.teal),
      (midpoint.onTeal, light.onTeal, dark.onTeal),
      (midpoint.tealContainer, light.tealContainer, dark.tealContainer),
      (midpoint.onTealContainer, light.onTealContainer, dark.onTealContainer),
      (midpoint.lavender, light.lavender, dark.lavender),
      (midpoint.onLavender, light.onLavender, dark.onLavender),
      (
        midpoint.lavenderContainer,
        light.lavenderContainer,
        dark.lavenderContainer,
      ),
      (
        midpoint.onLavenderContainer,
        light.onLavenderContainer,
        dark.onLavenderContainer,
      ),
    ]) {
      expect(actual, Color.lerp(from, to, 0.5));
    }
  });

  for (final brightness in Brightness.values) {
    testWidgets('普通 MaterialApp 的 $brightness 后备色组可用', (tester) async {
      BrandColors? actual;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: Builder(
            builder: (context) {
              actual = context.brandColors;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(
        actual,
        brightness == Brightness.dark ? BrandColors.dark : BrandColors.light,
      );
      expect(tester.takeException(), isNull);
    });
  }
}

void _expectContrast(Color foreground, Color background, String reason) {
  final front = Color.alphaBlend(foreground, background).computeLuminance();
  final back = background.computeLuminance();
  final ratio = (math.max(front, back) + 0.05) / (math.min(front, back) + 0.05);
  expect(ratio, greaterThanOrEqualTo(4.5), reason: reason);
}
