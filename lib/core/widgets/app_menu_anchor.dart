import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_motion.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

/// SDK MenuAnchor 的展开时长固定为 500ms，使用官方底层锚点定制短过渡。
class AppMenuAnchor extends StatefulWidget {
  const AppMenuAnchor({
    required this.controller,
    required this.menuChildren,
    required this.builder,
    this.childFocusNode,
    this.style = const MenuStyle(),
    this.alignmentOffset = Offset.zero,
    this.onOpen,
    this.onClose,
    this.onAnimationStatusChanged,
    super.key,
  });

  final MenuController controller;
  final List<Widget> menuChildren;
  final RawMenuAnchorChildBuilder builder;
  final FocusNode? childFocusNode;
  final MenuStyle style;
  final Offset alignmentOffset;
  final VoidCallback? onOpen;
  final VoidCallback? onClose;
  final ValueChanged<AnimationStatus>? onAnimationStatusChanged;

  @override
  State<AppMenuAnchor> createState() => _AppMenuAnchorState();
}

class _AppMenuAnchorState extends State<AppMenuAnchor>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(
    vsync: this,
    duration: AppMotion.menuOpen,
    reverseDuration: AppMotion.menuClose,
  )..addStatusListener(_statusChanged);
  late final _progress = CurvedAnimation(
    parent: _animation,
    curve: AppMotion.menuCurve,
    reverseCurve: AppMotion.menuReverseCurve,
  );
  late final _scale = Tween(begin: 0.96, end: 1.0).animate(_progress);
  final _menuFocus = FocusScopeNode();
  final _scroll = ScrollController();
  VoidCallback? _hideOverlay;
  bool _reduced = false;

  bool get _interactive => _animation.status.isForwardOrCompleted;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = AppMotion.reduce(context);
    _animation.duration = _reduced ? Duration.zero : AppMotion.menuOpen;
    _animation.reverseDuration = _reduced ? Duration.zero : AppMotion.menuClose;
    if (_reduced && _animation.isAnimating) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _reduced) _animation.value = _interactive ? 1 : 0;
      });
    }
  }

  void _statusChanged(AnimationStatus status) {
    setState(() {});
    widget.onAnimationStatusChanged?.call(status);
    if (status == AnimationStatus.dismissed) _finishClose();
  }

  void _open(Offset? position, VoidCallback showOverlay) {
    // 反向展开沿用当前浮层和进度，不重建内容，也不遗留上次收起的回调。
    _hideOverlay = null;
    if (!widget.controller.isOpen) {
      showOverlay();
    } else if (!_interactive) {
      widget.onOpen?.call();
    }
    if (!_interactive) _animation.forward();
  }

  void _close(VoidCallback hideOverlay) {
    if (!widget.controller.isOpen) return;
    _hideOverlay = hideOverlay;
    if (_menuFocus.hasFocus) widget.childFocusNode?.requestFocus();
    if (_animation.status == AnimationStatus.reverse) return;
    if (_reduced || _animation.value == 0) {
      _animation.value = 0;
      _finishClose();
    } else {
      _animation.reverse();
    }
  }

  void _finishClose() {
    final hide = _hideOverlay;
    _hideOverlay = null;
    hide?.call();
  }

  void _moveFocus({required bool forward}) {
    if (!_interactive || _menuFocus.context == null) return;
    if (_menuFocus.hasFocus) {
      forward ? _menuFocus.nextFocus() : _menuFocus.previousFocus();
    } else {
      final policy = FocusTraversalGroup.of(_menuFocus.context!);
      final node = forward
          ? policy.findFirstFocus(_menuFocus, ignoreCurrentFocus: true)
          : policy.findLastFocus(_menuFocus, ignoreCurrentFocus: true);
      node?.requestFocus();
    }
  }

  Widget _shortcuts(Widget child) => CallbackShortcuts(
    bindings: {
      if (widget.controller.isOpen) ...{
        const SingleActivator(LogicalKeyboardKey.escape):
            widget.controller.close,
        const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
            _moveFocus(forward: true),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
            _moveFocus(forward: false),
      },
    },
    child: child,
  );

  @override
  void dispose() {
    _hideOverlay = null;
    _progress.dispose();
    _animation.dispose();
    _menuFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RawMenuAnchor(
    controller: widget.controller,
    childFocusNode: widget.childFocusNode,
    consumeOutsideTaps: true,
    onOpenRequested: _open,
    onCloseRequested: _close,
    onOpen: widget.onOpen,
    onClose: widget.onClose,
    builder: (context, controller, child) =>
        _shortcuts(widget.builder(context, controller, child)),
    overlayBuilder: _buildOverlay,
  );

  Widget _buildOverlay(BuildContext context, RawMenuOverlayInfo info) {
    final theme = Theme.of(context);
    final style = widget.style.merge(MenuTheme.of(context).style);
    final direction = Directionality.of(context);
    final media = MediaQuery.of(context);
    final viewport = media.padding.deflateRect(
      media.viewInsets.deflateRect(Offset.zero & info.overlaySize),
    );
    final screens = DisplayFeatureSubScreen.subScreensInBounds(
      viewport,
      DisplayFeatureSubScreen.avoidBounds(media),
    );
    final screen = screens.reduce(
      (a, b) =>
          (a.center - info.anchorRect.center).distanceSquared <=
              (b.center - info.anchorRect.center).distanceSquared
          ? a
          : b,
    );
    final bounds = screen.deflate(AppSpacing.s);
    return CustomSingleChildLayout(
      delegate: _MenuLayout(
        anchor: info.anchorRect,
        bounds: bounds,
        alignment: style.alignment ?? AlignmentDirectional.bottomStart,
        offset: widget.alignmentOffset,
        position: info.position,
        direction: direction,
      ),
      child: TapRegion(
        groupId: info.tapRegionGroupId,
        consumeOutsideTaps: true,
        onTapOutside: (_) => widget.controller.close(),
        child: ExcludeSemantics(
          excluding: !_interactive,
          child: ExcludeFocus(
            excluding: !_interactive,
            child: IgnorePointer(
              ignoring: !_interactive,
              child: Semantics(
                scopesRoute: true,
                explicitChildNodes: true,
                child: FocusTraversalGroup(
                  child: FocusScope(
                    node: _menuFocus,
                    skipTraversal: true,
                    child: _shortcuts(_buildPanel(theme, style)),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPanel(ThemeData theme, MenuStyle style) {
    final minimum = style.minimumSize?.resolve({}) ?? Size.zero;
    final maximum =
        style.maximumSize?.resolve({}) ??
        const Size(double.infinity, double.infinity);
    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: minimum.width,
        minHeight: minimum.height,
        maxWidth: maximum.width,
        maxHeight: maximum.height,
      ),
      child: FadeTransition(
        opacity: _progress,
        alwaysIncludeSemantics: true,
        child: ScaleTransition(
          scale: _scale,
          // 动画只改变合成属性，菜单按最终尺寸布局，文字不逐帧重排。
          child: RepaintBoundary(
            child: IntrinsicWidth(
              child: Material(
                color:
                    style.backgroundColor?.resolve({}) ??
                    theme.colorScheme.surfaceContainer,
                surfaceTintColor:
                    style.surfaceTintColor?.resolve({}) ?? Colors.transparent,
                shadowColor: style.shadowColor?.resolve({}),
                elevation: style.elevation?.resolve({}) ?? 2,
                shape:
                    style.shape?.resolve({}) ??
                    const RoundedRectangleBorder(
                      borderRadius: AppRadius.largeAll,
                    ),
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding:
                      style.padding?.resolve({}) ??
                      const EdgeInsets.all(AppSpacing.s),
                  child: ScrollConfiguration(
                    behavior: ScrollConfiguration.of(context).copyWith(
                      scrollbars: false,
                      overscroll: false,
                      physics: const ClampingScrollPhysics(),
                    ),
                    child: Scrollbar(
                      controller: _scroll,
                      thumbVisibility:
                          _animation.status == AnimationStatus.completed,
                      child: SingleChildScrollView(
                        controller: _scroll,
                        primary: false,
                        child: ListBody(children: widget.menuChildren),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 保留 Material 条目样式；RawMenuAnchor 不会替条目自动关闭菜单。
class AppMenuItemButton extends StatelessWidget {
  const AppMenuItemButton({
    required this.onPressed,
    required this.child,
    this.style,
    this.leadingIcon,
    this.trailingIcon,
    super.key,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final ButtonStyle? style;
  final Widget? leadingIcon;
  final Widget? trailingIcon;

  @override
  Widget build(BuildContext context) => MenuItemButton(
    closeOnActivate: false,
    overflowAxis: Axis.vertical,
    style: style,
    leadingIcon: leadingIcon,
    trailingIcon: trailingIcon,
    onPressed: onPressed == null
        ? null
        : () {
            if (!context.mounted) return;
            final anchor = context
                .findAncestorStateOfType<_AppMenuAnchorState>();
            if (anchor == null || !anchor._interactive) return;
            anchor.widget.controller.close();
            FocusManager.instance.applyFocusChangesIfNeeded();
            onPressed?.call();
          },
    child: child,
  );
}

class _MenuLayout extends SingleChildLayoutDelegate {
  const _MenuLayout({
    required this.anchor,
    required this.bounds,
    required this.alignment,
    required this.offset,
    required this.position,
    required this.direction,
  });

  final Rect anchor;
  final Rect bounds;
  final AlignmentGeometry alignment;
  final Offset offset;
  final Offset? position;
  final TextDirection direction;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.loose(
        Size(math.max(0, bounds.width), math.max(0, bounds.height)),
      );

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final rtl = direction == TextDirection.rtl;
    final directionalOffset = alignment is AlignmentDirectional && rtl
        ? Offset(-offset.dx, offset.dy)
        : offset;
    final origin = position == null
        ? alignment.resolve(direction).withinRect(anchor) + directionalOffset
        : anchor.topLeft + position!;
    var x = origin.dx - (rtl && position == null ? childSize.width : 0);
    var y = origin.dy;
    if (position == null && y + childSize.height > bounds.bottom) {
      y = anchor.top - childSize.height - offset.dy;
    } else if (position == null && y < bounds.top) {
      y = anchor.bottom + offset.dy;
    }
    x = x.clamp(
      bounds.left,
      math.max(bounds.left, bounds.right - childSize.width),
    );
    y = y.clamp(
      bounds.top,
      math.max(bounds.top, bounds.bottom - childSize.height),
    );
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(_MenuLayout oldDelegate) =>
      anchor != oldDelegate.anchor ||
      bounds != oldDelegate.bounds ||
      alignment != oldDelegate.alignment ||
      offset != oldDelegate.offset ||
      position != oldDelegate.position ||
      direction != oldDelegate.direction;
}
