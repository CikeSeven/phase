import 'app_interactive_surface.dart';

/// 主题、模型等选择面的共同反馈，不持有或提前提交业务选择。
class AppSelectionSurface extends AppInteractiveSurface {
  const AppSelectionSurface({
    required bool selected,
    required super.onTap,
    required super.child,
    super.key,
    super.color,
    super.onLongPress,
  }) : super(selected: selected);
}
