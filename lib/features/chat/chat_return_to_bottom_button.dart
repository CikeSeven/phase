import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../core/theme/app_control_style.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/frosted_surface.dart';

/// 只在用户朝最新消息滚动时浮现，玻璃与内容分别渐变，避免模糊层闪白。
class ChatReturnToBottomButton extends StatefulWidget {
  const ChatReturnToBottomButton({
    required this.visible,
    required this.onPressed,
    super.key,
  });

  final bool visible;
  final VoidCallback onPressed;

  @override
  State<ChatReturnToBottomButton> createState() =>
      _ChatReturnToBottomButtonState();
}

class _ChatReturnToBottomButtonState extends State<ChatReturnToBottomButton>
    with SingleTickerProviderStateMixin {
  late final _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    reverseDuration: const Duration(milliseconds: 180),
    value: widget.visible ? 1 : 0,
  );
  late final _opacity = CurvedAnimation(
    parent: _reveal,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  late final _space = CurvedAnimation(
    parent: _reveal,
    curve: Curves.easeOutBack,
    reverseCurve: Curves.easeInCubic,
  );
  bool _reduced = false;
  bool _launching = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = AppMotion.reduce(context);
    if (_reduced) _reveal.value = widget.visible ? 1 : 0;
  }

  @override
  void didUpdateWidget(covariant ChatReturnToBottomButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible == oldWidget.visible) return;
    if (widget.visible) _launching = false;
    if (_reduced) {
      _reveal.value = widget.visible ? 1 : 0;
    } else if (widget.visible) {
      _reveal.forward();
    } else {
      _reveal.reverse();
    }
  }

  @override
  void dispose() {
    _opacity.dispose();
    _space.dispose();
    _reveal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final highlight = dark ? colors.onSurface : colors.surfaceContainerLowest;
    return AnimatedBuilder(
      animation: _reveal,
      builder: (context, child) {
        if (_reveal.isDismissed) return const SizedBox.shrink();
        final travel = _launching ? AppSpacing.xl : AppSpacing.m;
        return IgnorePointer(
          ignoring: !widget.visible,
          child: ExcludeFocus(
            excluding: !widget.visible,
            child: ExcludeSemantics(
              excluding: !widget.visible,
              child: Transform.translate(
                offset: Offset(0, travel * (1 - _space.value)),
                transformHitTests: false,
                child: Transform.scale(
                  scale: 0.9 + 0.1 * _space.value,
                  transformHitTests: false,
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
      child: FrostedSurface(
        borderRadius: AppRadius.controlAll,
        blur: 20,
        color:
            (dark ? colors.surfaceContainerLow : colors.surfaceContainerLowest)
                .withValues(alpha: dark ? 0.54 : 0.38),
        borderColor: highlight.withValues(alpha: dark ? 0.20 : 0.72),
        revealAnimation: _opacity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: const [0, 0.5, 1],
              colors: [
                highlight.withValues(alpha: dark ? 0.06 : 0.18),
                highlight.withValues(alpha: dark ? 0.01 : 0.02),
                colors.primary.withValues(alpha: 0.03),
              ],
            ),
          ),
          child: IconButton(
            key: const ValueKey('chat-scroll-to-bottom'),
            tooltip: '回到底部',
            onPressed: () {
              _launching = true;
              widget.onPressed();
            },
            style:
                IconButton.styleFrom(
                  fixedSize: const Size(56, 48),
                  foregroundColor: colors.onSurface,
                  backgroundColor: Colors.transparent,
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.standard,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ).copyWith(
                  shape: AppControlStyle.shape(compact: true, active: true),
                  animationDuration: _reduced
                      ? Duration.zero
                      : AppMotion.effects,
                ),
            icon: const Icon(Symbols.arrow_downward, size: 24),
          ),
        ),
      ),
    );
  }
}
