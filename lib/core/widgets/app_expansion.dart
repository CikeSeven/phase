import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../theme/app_motion.dart';
import '../theme/app_spacing.dart';

/// 按完整内容尺寸布局，再裁剪展开高度，不逐帧挤压内部滚动视口。
class AppExpansionBody extends StatefulWidget {
  const AppExpansionBody({
    required this.expanded,
    required this.builder,
    super.key,
  });

  final bool expanded;
  final WidgetBuilder builder;

  @override
  State<AppExpansionBody> createState() => _AppExpansionBodyState();
}

class _AppExpansionBodyState extends State<AppExpansionBody>
    with SingleTickerProviderStateMixin {
  late final _progress = AnimationController(
    vsync: this,
    value: widget.expanded ? 1 : 0,
  );
  late bool _contentMounted = widget.expanded;
  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = AppMotion.reduce(context);
    if (_reduceMotion) _progress.value = widget.expanded ? 1 : 0;
  }

  @override
  void didUpdateWidget(covariant AppExpansionBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.expanded) _contentMounted = true;
    if (widget.expanded == oldWidget.expanded) return;
    if (_reduceMotion) {
      _progress.value = widget.expanded ? 1 : 0;
    } else if (widget.expanded) {
      _progress.animateTo(
        1,
        duration: AppMotion.expansionOpen,
        curve: AppMotion.expansionCurve,
      );
    } else {
      _progress.animateBack(
        0,
        duration: AppMotion.expansionClose,
        curve: AppMotion.expansionCurve,
      );
    }
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _progress,
      // 长文本和工具输出不随动画帧重建；首次展开才挂载，收起后保留状态。
      child: SizedBox(
        width: double.infinity,
        child: _contentMounted
            ? widget.builder(context)
            : const SizedBox.shrink(),
      ),
      builder: (context, child) {
        final hidden = !widget.expanded && _progress.value == 0;
        return Offstage(
          offstage: hidden,
          child: TickerMode(
            enabled: !hidden,
            child: ExcludeFocus(
              excluding: !widget.expanded,
              child: IgnorePointer(
                ignoring: !widget.expanded,
                child: ExcludeSemantics(
                  excluding: !widget.expanded,
                  child: SizeTransition(
                    sizeFactor: _progress,
                    alignment: Alignment.topCenter,
                    child: FadeTransition(
                      opacity: _progress,
                      child: Transform.translate(
                        offset: Offset(
                          0,
                          -AppSpacing.xs * (1 - _progress.value),
                        ),
                        child: child,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 与内容使用相同的时长和曲线，快速反向从当前角度继续。
class AppExpansionArrow extends StatelessWidget {
  const AppExpansionArrow({
    required this.expanded,
    required this.color,
    super.key,
  });

  final bool expanded;
  final Color color;

  @override
  Widget build(BuildContext context) => AnimatedRotation(
    turns: expanded ? 0.5 : 0,
    duration: AppMotion.reduce(context)
        ? Duration.zero
        : expanded
        ? AppMotion.expansionOpen
        : AppMotion.expansionClose,
    curve: AppMotion.expansionCurve,
    child: Icon(Symbols.expand_more_rounded, size: 18, color: color),
  );
}
