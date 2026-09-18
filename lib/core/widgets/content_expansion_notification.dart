import 'package:flutter/widgets.dart';

/// 用户展开或收起内容前，通知阅读区保留标题的位置。
class ContentExpansionNotification extends Notification {
  const ContentExpansionNotification({required this.anchor});

  final BuildContext anchor;
}
