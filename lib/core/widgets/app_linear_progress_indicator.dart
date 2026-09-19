import 'package:flutter/material.dart';
import 'package:m3e_progress_indicator/m3e_progress_indicator.dart';

import '../theme/app_motion.dart';

/// Expressive 波浪进度条；value 为 null 时表示未知总量，不推算百分比。
class AppLinearProgressIndicator extends StatefulWidget {
  const AppLinearProgressIndicator({
    super.key,
    this.value,
    this.semanticsLabel = '正在加载',
  }) : assert(value == null || (value >= 0 && value <= 1));

  final double? value;
  final String semanticsLabel;

  @override
  State<AppLinearProgressIndicator> createState() =>
      _AppLinearProgressIndicatorState();
}

class _AppLinearProgressIndicatorState extends State<AppLinearProgressIndicator>
    with SingleTickerProviderStateMixin {
  // 减少动画时冻结未知进度的线段；已知进度仍直接反映每次真实更新。
  late final _staticPosition = AnimationController(vsync: this, value: 0.5);

  @override
  void dispose() {
    _staticPosition.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final reduced = AppMotion.reduce(context);
    return Semantics(
      label: widget.semanticsLabel,
      value: widget.value == null ? '进行中' : '${(widget.value! * 100).floor()}%',
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: TickerMode(
            enabled: !reduced,
            child: SizedBox(
              height: 10,
              child: reduced
                  ? Center(
                      child: LinearProgressIndicator(
                        value: widget.value,
                        controller: widget.value == null
                            ? _staticPosition
                            : null,
                        color: colors.primary,
                        backgroundColor: colors.secondaryContainer,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    )
                  : M3ELinearWavyProgressIndicator(
                      value: widget.value,
                      color: colors.primary,
                      backgroundColor: colors.secondaryContainer,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
