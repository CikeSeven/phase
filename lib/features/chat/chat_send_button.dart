import 'package:flutter/material.dart';
import 'package:material_loading_indicator/loading_indicator.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../core/theme/app_control_style.dart';
import '../../../core/theme/app_motion.dart';

/// 紧凑发送/停止按钮；生成指示与形状过渡不改变布局和触区。
class ChatSendButton extends StatelessWidget {
  const ChatSendButton({
    required this.isGenerating,
    required this.onPressed,
    super.key,
  });

  final bool isGenerating;
  final VoidCallback? onPressed;

  static const _surfaceSize = 40.0;

  @override
  Widget build(BuildContext context) {
    final reduced = AppMotion.reduce(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    // 中心跟随主题明暗，外围反衬；复用主题配色，浅色中心也不使用纯白。
    final colorStyle = isGenerating
        ? IconButton.styleFrom(
            backgroundColor: dark ? colors.primary : colors.onPrimaryContainer,
            foregroundColor: dark ? colors.onPrimary : colors.primaryContainer,
          )
        : const ButtonStyle();
    final icon = isGenerating
        ? const _GeneratingIndicator(key: ValueKey(true))
        : const Icon(Symbols.arrow_upward, key: ValueKey(false), size: 24);

    return IconButton.filled(
      tooltip: isGenerating ? '停止生成' : '发送',
      onPressed: onPressed,
      style: colorStyle.copyWith(
        minimumSize: const WidgetStatePropertyAll(Size.square(_surfaceSize)),
        maximumSize: const WidgetStatePropertyAll(Size.square(_surfaceSize)),
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        // 固定色面尺寸；SDK 的输入留白扩展到 56dp，并负责边缘命中。
        visualDensity: const VisualDensity(horizontal: 2, vertical: 2),
        tapTargetSize: MaterialTapTargetSize.padded,
        shape: AppControlStyle.shape(compact: true),
        animationDuration: reduced ? Duration.zero : AppMotion.effects,
      ),
      icon: ExcludeSemantics(
        child: SizedBox.square(
          dimension: 24,
          // 减少动画时直接替换，连正在退场的图标也立即清理。
          child: reduced
              ? icon
              : AnimatedSwitcher(
                  duration: AppMotion.effects,
                  transitionBuilder: _transition,
                  child: icon,
                ),
        ),
      ),
    );
  }

  static Widget _transition(Widget child, Animation<double> animation) =>
      FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          // 弹性只用于空间变化，透明度保持无回弹过渡。
          scale: animation.drive(
            Tween<double>(
              begin: 0.75,
              end: 1,
            ).chain(CurveTween(curve: Curves.easeOutBack)),
          ),
          child: child,
        ),
      );
}

class _GeneratingIndicator extends StatelessWidget {
  const _GeneratingIndicator({super.key});

  @override
  Widget build(BuildContext context) => OverflowBox(
    // 按真实的 40dp 容器比例绘制，仍在固定图标槽中居中，不改布局。
    minWidth: ChatSendButton._surfaceSize,
    maxWidth: ChatSendButton._surfaceSize,
    minHeight: ChatSendButton._surfaceSize,
    maxHeight: ChatSendButton._surfaceSize,
    child: RepaintBoundary(
      // 限制重绘范围；减少动画或上层离屏时保留静态形状，不持续 tick。
      child: TickerMode(
        enabled: !AppMotion.reduce(context),
        child: LoadingIndicator.contained(
          activeIndicatorColor: IconTheme.of(context).color,
          // 原生按钮已提供容器与 ink 反馈，不再叠一层不透明的圆形底。
          containerColor: Colors.transparent,
        ),
      ),
    ),
  );
}
