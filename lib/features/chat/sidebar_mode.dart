import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'sidebar_mode.g.dart';

enum SidebarMode { chat, projects }

@Riverpod(keepAlive: true)
class SidebarModeController extends _$SidebarModeController {
  @override
  SidebarMode build() => SidebarMode.chat;

  void select(SidebarMode mode) => state = mode;
}
