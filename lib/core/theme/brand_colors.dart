import 'package:flutter/material.dart';

/// 青玉、雾紫和月华金的语义色；正文仍使用 ColorScheme 的表面文字色。
@immutable
class BrandColors extends ThemeExtension<BrandColors> {
  const BrandColors({
    required this.gold,
    required this.onGold,
    required this.goldContainer,
    required this.onGoldContainer,
    this.teal = const Color(0xFF176963),
    this.onTeal = const Color(0xFFFFFFFF),
    this.tealContainer = const Color(0xFFD3EEE7),
    this.onTealContainer = const Color(0xFF123F3B),
    this.lavender = const Color(0xFF68558E),
    this.onLavender = const Color(0xFFFFFFFF),
    this.lavenderContainer = const Color(0xFFECE1F8),
    this.onLavenderContainer = const Color(0xFF403053),
  });

  final Color gold;
  final Color onGold;
  final Color goldContainer;
  final Color onGoldContainer;
  final Color teal;
  final Color onTeal;
  final Color tealContainer;
  final Color onTealContainer;
  final Color lavender;
  final Color onLavender;
  final Color lavenderContainer;
  final Color onLavenderContainer;

  static const light = BrandColors(
    gold: Color(0xFF806117),
    onGold: Color(0xFFFFFFFF),
    goldContainer: Color(0xFFF4E7BC),
    onGoldContainer: Color(0xFF48350B),
  );

  static const dark = BrandColors(
    gold: Color(0xFFE9C76F),
    onGold: Color(0xFF3E2D00),
    goldContainer: Color(0xFF4D3E1C),
    onGoldContainer: Color(0xFFF8E5AD),
    teal: Color(0xFF91D7CC),
    onTeal: Color(0xFF003833),
    tealContainer: Color(0xFF214B47),
    onTealContainer: Color(0xFFBCEEE4),
    lavender: Color(0xFFD0BCF1),
    onLavender: Color(0xFF382650),
    lavenderContainer: Color(0xFF493B63),
    onLavenderContainer: Color(0xFFEDE0FE),
  );

  @override
  BrandColors copyWith({
    Color? gold,
    Color? onGold,
    Color? goldContainer,
    Color? onGoldContainer,
    Color? teal,
    Color? onTeal,
    Color? tealContainer,
    Color? onTealContainer,
    Color? lavender,
    Color? onLavender,
    Color? lavenderContainer,
    Color? onLavenderContainer,
  }) {
    return BrandColors(
      gold: gold ?? this.gold,
      onGold: onGold ?? this.onGold,
      goldContainer: goldContainer ?? this.goldContainer,
      onGoldContainer: onGoldContainer ?? this.onGoldContainer,
      teal: teal ?? this.teal,
      onTeal: onTeal ?? this.onTeal,
      tealContainer: tealContainer ?? this.tealContainer,
      onTealContainer: onTealContainer ?? this.onTealContainer,
      lavender: lavender ?? this.lavender,
      onLavender: onLavender ?? this.onLavender,
      lavenderContainer: lavenderContainer ?? this.lavenderContainer,
      onLavenderContainer: onLavenderContainer ?? this.onLavenderContainer,
    );
  }

  @override
  BrandColors lerp(ThemeExtension<BrandColors>? other, double t) {
    if (other is! BrandColors) return this;
    return BrandColors(
      gold: Color.lerp(gold, other.gold, t)!,
      onGold: Color.lerp(onGold, other.onGold, t)!,
      goldContainer: Color.lerp(goldContainer, other.goldContainer, t)!,
      onGoldContainer: Color.lerp(onGoldContainer, other.onGoldContainer, t)!,
      teal: Color.lerp(teal, other.teal, t)!,
      onTeal: Color.lerp(onTeal, other.onTeal, t)!,
      tealContainer: Color.lerp(tealContainer, other.tealContainer, t)!,
      onTealContainer: Color.lerp(onTealContainer, other.onTealContainer, t)!,
      lavender: Color.lerp(lavender, other.lavender, t)!,
      onLavender: Color.lerp(onLavender, other.onLavender, t)!,
      lavenderContainer: Color.lerp(
        lavenderContainer,
        other.lavenderContainer,
        t,
      )!,
      onLavenderContainer: Color.lerp(
        onLavenderContainer,
        other.onLavenderContainer,
        t,
      )!,
    );
  }
}

/// 普通 MaterialApp 未注册扩展时，按当前明暗模式使用完整的后备色组。
extension BrandColorsContext on BuildContext {
  BrandColors get brandColors {
    final theme = Theme.of(this);
    return theme.extension<BrandColors>() ??
        (theme.brightness == Brightness.dark
            ? BrandColors.dark
            : BrandColors.light);
  }
}
