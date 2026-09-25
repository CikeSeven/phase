import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../../core/widgets/app_section.dart';
import '../../../data/models/workspace.dart';
import '../commands/command_channels_controller.dart';
import 'workspace_controller.dart';

/// 保存反馈限于选择区，不改变页面顶栏高度或其他环境卡片。
class PrimaryEnvironmentSelector extends ConsumerWidget {
  const PrimaryEnvironmentSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(defaultPrimaryEnvironmentProvider);
    final channels = ref.watch(commandChannelsControllerProvider);
    final termuxAuthorized = channels.value?.termuxAuthorized == true;
    final locked = state.saving || channels.value?.busy == true;
    final theme = Theme.of(context);
    return AppSection(
      title: '新会话主环境',
      action: AppDelayedLoadingIndicator(
        loading: state.saving,
        semanticsLabel: '正在保存主环境',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _EnvironmentSegments(
            selected: state.environment,
            termuxAuthorized: termuxAuthorized,
            onSelected: locked
                ? null
                : ref.read(defaultPrimaryEnvironmentProvider.notifier).select,
          ),
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.s),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  state.error!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EnvironmentSegments extends StatelessWidget {
  const _EnvironmentSegments({
    required this.selected,
    required this.termuxAuthorized,
    required this.onSelected,
  });

  final PrimaryEnvironment selected;
  final bool termuxAuthorized;
  final ValueChanged<PrimaryEnvironment>? onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final style = theme.textTheme.labelLarge!.copyWith(
      fontWeight: FontWeight.w500,
    );
    final textScaler = MediaQuery.textScalerOf(context);
    const iconSize = 18.0;
    var labelWidth = 0.0;
    for (final environment in PrimaryEnvironment.values) {
      final painter = TextPainter(
        text: TextSpan(text: environment.label, style: style),
        textDirection: Directionality.of(context),
        textScaler: textScaler,
      )..layout();
      labelWidth = math.max(labelWidth, painter.width);
      painter.dispose();
    }
    // 固定组宽，避免勾图标移到另一标签时改变控件宽度。
    final segmentWidth = math.max(
      100.0,
      labelWidth + AppSpacing.l * 2 + iconSize + AppSpacing.s,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontal = constraints.maxWidth >= segmentWidth * 2;
        return Align(
          alignment: AlignmentDirectional.centerStart,
          child: SizedBox(
            width: horizontal
                ? segmentWidth * 2
                : math.min(segmentWidth, constraints.maxWidth),
            child: SegmentedButton<PrimaryEnvironment>(
              segments: [
                const ButtonSegment(
                  value: PrimaryEnvironment.ubuntu,
                  label: Text('Ubuntu'),
                ),
                ButtonSegment(
                  value: PrimaryEnvironment.termux,
                  enabled: termuxAuthorized,
                  label: Text(
                    'Termux',
                    // 真正未授权与临时保存锁区分，避免锁定全组时灰闪。
                    style: termuxAuthorized
                        ? null
                        : TextStyle(
                            color: colors.onSurface.withValues(alpha: 0.38),
                          ),
                  ),
                ),
              ],
              selected: {selected},
              onSelectionChanged: onSelected == null
                  ? null
                  : (values) => onSelected!(values.single),
              direction: horizontal ? Axis.horizontal : Axis.vertical,
              selectedIcon: Icon(
                Symbols.check,
                size: iconSize,
                color:
                    selected == PrimaryEnvironment.termux && !termuxAuthorized
                    ? colors.onSurface.withValues(alpha: 0.38)
                    : colors.onPrimaryContainer,
              ),
              style:
                  SegmentedButton.styleFrom(
                    textStyle: style,
                    foregroundColor: colors.onSurfaceVariant,
                    selectedForegroundColor: colors.onPrimaryContainer,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.l,
                      vertical: AppSpacing.s,
                    ),
                    side: BorderSide(color: colors.outline),
                    shape: const StadiumBorder(),
                    tapTargetSize: MaterialTapTargetSize.padded,
                    animationDuration: AppMotion.reduce(context)
                        ? Duration.zero
                        : AppMotion.effects,
                  ).copyWith(
                    // 临时保存锁不改变颜色，读屏与点击仍按禁用状态处理。
                    backgroundColor: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected)
                          ? colors.primaryContainer
                          : colors.surfaceContainerLow,
                    ),
                    foregroundColor: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected)
                          ? colors.onPrimaryContainer
                          : colors.onSurfaceVariant,
                    ),
                  ),
            ),
          ),
        );
      },
    );
  }
}
