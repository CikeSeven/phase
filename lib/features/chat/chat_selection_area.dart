import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SelectedContent;

/// 会话内的临时选区；与菜单、侧栏共用当前页面的本地返回层级。
class ChatSelectionController extends ChangeNotifier {
  _ChatSelectionAreaState? _selectedArea;
  LocalHistoryEntry? _history;

  bool get hasSelection => _selectedArea != null;

  void _select(_ChatSelectionAreaState area) {
    if (_selectedArea == area) return;
    // SDK 已请求新选区的焦点，清理旧选区不撤销这次焦点交接。
    clearSelection(unfocus: false);
    _selectedArea = area;
    final route = ModalRoute.of(area.context);
    if (route != null) {
      late final LocalHistoryEntry entry;
      entry = LocalHistoryEntry(
        impliesAppBarDismissal: false,
        onRemove: () {
          if (_history != entry) return;
          _history = null;
          clearSelection();
        },
      );
      _history = entry;
      route.addLocalHistoryEntry(entry);
    }
    notifyListeners();
  }

  void _deselect(_ChatSelectionAreaState area) {
    if (_selectedArea != area) return;
    _selectedArea = null;
    final entry = _history;
    _history = null;
    entry?.remove();
    notifyListeners();
  }

  void clearSelection({bool unfocus = true}) {
    final area = _selectedArea;
    if (area == null) return;
    _deselect(area);
    if (area.mounted) area._clearSelection(unfocus: unfocus);
  }

  @override
  void dispose() {
    _selectedArea = null;
    final entry = _history;
    _history = null;
    entry?.remove();
    super.dispose();
  }
}

class ChatSelectionScope extends InheritedWidget {
  const ChatSelectionScope({
    required this.controller,
    required super.child,
    super.key,
  });

  final ChatSelectionController controller;

  static ChatSelectionController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<ChatSelectionScope>()
      ?.controller;

  @override
  bool updateShouldNotify(ChatSelectionScope oldWidget) =>
      controller != oldWidget.controller;
}

/// 保留 SDK 的长按、选择手柄和复制菜单，不让触摸横拖抢占阅读手势。
class ChatSelectionArea extends StatefulWidget {
  const ChatSelectionArea({required this.child, super.key});

  final Widget child;

  @override
  State<ChatSelectionArea> createState() => _ChatSelectionAreaState();
}

class _ChatSelectionAreaState extends State<ChatSelectionArea> {
  final _selectionKey = GlobalKey<SelectionAreaState>();
  final _focusNode = FocusNode(debugLabel: 'Chat message selection');
  ChatSelectionController? _controller;
  bool _hasSelection = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = ChatSelectionScope.maybeOf(context);
    if (_controller == controller) return;
    _controller?._deselect(this);
    _controller = controller;
    if (_hasSelection) _controller?._select(this);
  }

  void _onSelectionChanged(SelectedContent? content) {
    _hasSelection = content != null && content.plainText.isNotEmpty;
    if (_hasSelection) {
      _controller?._select(this);
    } else {
      _controller?._deselect(this);
    }
  }

  void _clearSelection({bool unfocus = true}) {
    final region = _selectionKey.currentState?.selectableRegion;
    region?.hideToolbar();
    region?.clearSelection();
    if (unfocus) _focusNode.unfocus();
  }

  @override
  void dispose() {
    _controller?._deselect(this);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SelectionArea(
    key: _selectionKey,
    focusNode: _focusNode,
    onSelectionChanged: _onSelectionChanged,
    child: _ChatSelectionGestures(child: widget.child),
  );
}

class _ChatSelectionGestures extends StatelessWidget {
  const _ChatSelectionGestures({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (Theme.of(context).platform != TargetPlatform.android) return child;
    final settings = MediaQuery.of(context).gestureSettings;
    // replaceGestureRecognizers 是 SDK 的布局期 API；此处只适配紧邻的
    // SelectionArea，不遍历或修改正文内的横滚、按钮和文本输入识别器。
    return LayoutBuilder(
      builder: (context, _) {
        final detector = context
            .findAncestorStateOfType<RawGestureDetectorState>()!;
        final gestures = Map<Type, GestureRecognizerFactory>.of(
          detector.widget.gestures,
        );
        if (gestures[TapAndHorizontalDragGestureRecognizer]
            case final GestureRecognizerFactory<
                  TapAndHorizontalDragGestureRecognizer
                >
                factory) {
          gestures[TapAndHorizontalDragGestureRecognizer] =
              GestureRecognizerFactoryWithHandlers<
                TapAndHorizontalDragGestureRecognizer
              >(factory.constructor, (instance) {
                factory.initializer(instance);
                // SDK 的 Android 选择器在普通横拖时也会抢先胜出，即便
                // 该次触摸不支持拖动选择；等待侧栏/局部横滚决定手势归属。
                instance
                  ..eagerVictoryOnDrag = false
                  ..gestureSettings = settings;
              });
        }
        if (gestures[LongPressGestureRecognizer]
            case final GestureRecognizerFactory<LongPressGestureRecognizer>
                factory) {
          gestures[LongPressGestureRecognizer] =
              GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
                factory.constructor,
                (instance) {
                  factory.initializer(instance);
                  instance.gestureSettings = settings;
                },
              );
        }
        detector.replaceGestureRecognizers(gestures);
        return child;
      },
    );
  }
}
