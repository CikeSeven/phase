import 'package:flutter/widgets.dart';

/// DESIGN.md §4 的圆角档位（M3 shape scale）。
abstract final class AppRadius {
  /// 小按钮、Chip。
  static const double small = 8;

  /// 卡片、Dialog。
  static const double medium = 12;

  /// 聊天气泡。
  static const double large = 16;

  /// 输入栏、FAB、发送按钮（Stadium）。
  static const double full = 28;

  static const BorderRadius smallAll = BorderRadius.all(Radius.circular(small));
  static const BorderRadius mediumAll = BorderRadius.all(
    Radius.circular(medium),
  );
  static const BorderRadius largeAll = BorderRadius.all(Radius.circular(large));
  static const BorderRadius fullAll = BorderRadius.all(Radius.circular(full));
}
