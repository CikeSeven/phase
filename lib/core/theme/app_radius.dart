import 'package:flutter/widgets.dart';

/// DESIGN.md §4 的圆角档位。
///
/// 相月使用更舒展的圆角作为视觉识别，组件仍按尺寸选择档位，避免
/// 所有元素都使用同一个超大圆角。
abstract final class AppRadius {
  /// 小按钮、Chip、列表项。
  static const double small = 12;

  /// 输入框、卡片。
  static const double medium = 20;

  /// 聊天气泡、磨砂面板。
  static const double large = 28;

  /// 页面级面板、Dialog。
  static const double extraLarge = 36;

  /// 输入栏、FAB、发送按钮。
  static const double full = 40;

  static const BorderRadius smallAll = BorderRadius.all(Radius.circular(small));
  static const BorderRadius mediumAll = BorderRadius.all(
    Radius.circular(medium),
  );
  static const BorderRadius largeAll = BorderRadius.all(Radius.circular(large));
  static const BorderRadius extraLargeAll = BorderRadius.all(
    Radius.circular(extraLarge),
  );
  static const BorderRadius fullAll = BorderRadius.all(Radius.circular(full));
}
