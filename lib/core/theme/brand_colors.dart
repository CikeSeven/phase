import 'package:flutter/material.dart';

/// 品牌辅助色「月华金」，基准 `#C9A227`。
///
/// 不经 `ColorScheme.fromSeed`，以 [ThemeExtension] 挂入主题（DESIGN.md §2.1）。
/// 用于品牌标识、选中态强调、置顶标记等低频场景，每屏至多一处金色元素。
@immutable
class BrandColors extends ThemeExtension<BrandColors> {
  const BrandColors({
    required this.gold,
    required this.onGold,
    required this.goldContainer,
    required this.onGoldContainer,
  });

  final Color gold;
  final Color onGold;
  final Color goldContainer;
  final Color onGoldContainer;

  /// 浅色主题取值：金色压深以保证白底对比度。
  static const light = BrandColors(
    gold: Color(0xFF8A6D00),
    onGold: Color(0xFFFFFFFF),
    goldContainer: Color(0xFFF4E5B0),
    onGoldContainer: Color(0xFF4A3C00),
  );

  /// 深色主题取值：金色提亮以浮出深色 surface。
  static const dark = BrandColors(
    gold: Color(0xFFE3C24A),
    onGold: Color(0xFF3A2E00),
    goldContainer: Color(0xFF554A12),
    onGoldContainer: Color(0xFFF0DA9A),
  );

  @override
  BrandColors copyWith({
    Color? gold,
    Color? onGold,
    Color? goldContainer,
    Color? onGoldContainer,
  }) {
    return BrandColors(
      gold: gold ?? this.gold,
      onGold: onGold ?? this.onGold,
      goldContainer: goldContainer ?? this.goldContainer,
      onGoldContainer: onGoldContainer ?? this.onGoldContainer,
    );
  }

  @override
  BrandColors lerp(ThemeExtension<BrandColors>? other, double t) {
    if (other is! BrandColors) {
      return this;
    }
    return BrandColors(
      gold: Color.lerp(gold, other.gold, t)!,
      onGold: Color.lerp(onGold, other.onGold, t)!,
      goldContainer: Color.lerp(goldContainer, other.goldContainer, t)!,
      onGoldContainer: Color.lerp(
        onGoldContainer,
        other.onGoldContainer,
        t,
      )!,
    );
  }
}

/// 金色一律经此扩展取用（DESIGN.md §2.2 取色纪律）。
extension BrandColorsContext on BuildContext {
  BrandColors get brandColors => Theme.of(this).extension<BrandColors>()!;
}
