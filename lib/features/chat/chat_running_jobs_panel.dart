import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../data/models/command_task.dart';
import '../tasks/command_task_controller.dart';
import '../tasks/task_presentation.dart';

/// 从编辑框上方伸出的后台任务运行面板。
///
/// 拥有与编辑框区分的高级色块背景与边距，顶部标题与列表之间具有清晰分割。
/// 单任务展示命令、耗时与停止按钮；多任务收起时展示运行中数量，点击面板直接展开；展开时点击标题直接收起。
class ChatRunningJobsPanel extends ConsumerStatefulWidget {
  const ChatRunningJobsPanel({super.key, this.isInputFocused = false});

  /// 输入框是否处于聚焦状态；聚焦输入时自动收起展开的任务面板，避免挤压输入法。
  final bool isInputFocused;

  @override
  ConsumerState<ChatRunningJobsPanel> createState() =>
      _ChatRunningJobsPanelState();
}

class _ChatRunningJobsPanelState extends ConsumerState<ChatRunningJobsPanel>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _expanded = false;
  final Set<String> _expandedCommands = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (!mounted) return;
    // 当键盘弹起且当前焦点处于输入树中时，主动收起展开面板，防止编辑框被挤到键盘下方。
    final bottomInset = View.of(context).viewInsets.bottom;
    if (bottomInset > 0 && (_expanded || _expandedCommands.isNotEmpty)) {
      if (FocusScope.of(context).hasFocus) {
        setState(() {
          _expanded = false;
          _expandedCommands.clear();
        });
      }
    }
  }

  @override
  void didUpdateWidget(covariant ChatRunningJobsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 用户点击编辑框获取焦点时，自动收起任务详情，确保输入法弹出后编辑框完全可见。
    if (widget.isInputFocused && !oldWidget.isInputFocused) {
      if (_expanded || _expandedCommands.isNotEmpty) {
        setState(() {
          _expanded = false;
          _expandedCommands.clear();
        });
      }
    }
  }

  void _syncTimer(bool hasActive) {
    if (hasActive && _timer == null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!hasActive && _timer != null) {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _toggleCommand(String taskId) {
    setState(() {
      if (_expandedCommands.contains(taskId)) {
        _expandedCommands.remove(taskId);
      } else {
        _expandedCommands.add(taskId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tasksState = ref.watch(commandTaskControllerProvider);
    final activeTasks = tasksState.tasks
        .where((task) => task.status.active)
        .toList();

    _syncTimer(activeTasks.isNotEmpty);

    if (activeTasks.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final brand = context.brandColors;
    final isDark = theme.brightness == Brightness.dark;

    // 与下方纯净输入区域形成鲜明颜色区分的高级容器底色
    final panelBg = isDark
        ? Color.alphaBlend(
            colors.primaryContainer.withValues(alpha: 0.28),
            colors.surfaceContainerHighest.withValues(alpha: 0.70),
          )
        : Color.alphaBlend(
            brand.tealContainer.withValues(alpha: 0.50),
            colors.surfaceContainerLow,
          );
    final panelBorderColor = (isDark ? colors.outlineVariant : brand.teal)
        .withValues(alpha: isDark ? 0.35 : 0.40);

    final panelContent = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!_expanded)
          _buildCompactBar(context, activeTasks)
        else
          _buildExpandedList(context, activeTasks),
      ],
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 向上凸出且向下方（编辑框背后）延伸的背景层，实现从编辑框底部伸出来的效果
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          bottom: -28,
          child: Container(
            decoration: BoxDecoration(
              color: panelBg,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.large),
              ),
              border: Border(
                top: BorderSide(color: panelBorderColor, width: 1),
                left: BorderSide(color: panelBorderColor, width: 1),
                right: BorderSide(color: panelBorderColor, width: 1),
              ),
            ),
          ),
        ),
        // 凸出可见区域的具体任务内容，确定真实的布局高度，动画不会裁切外部背景层
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          child: panelContent,
        ),
      ],
    );
  }

  Widget _buildCompactBar(BuildContext context, List<CommandTask> activeTasks) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final brand = context.brandColors;

    // 多任务收起状态：左对齐展示「x 个后台任务运行中」，点击整行直接展开
    if (activeTasks.length > 1) {
      return Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: const ValueKey('running-jobs-compact-multi'),
          onTap: () {
            FocusScope.of(context).unfocus();
            setState(() => _expanded = true);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.m + 2,
              vertical: 14,
            ),
            child: Row(
              children: [
                _buildIndicator(brand.teal),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${activeTasks.length} 个后台任务运行中',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 单任务收起状态：展示具体命令、耗时与最右侧停止按钮，点击面板可展开长命令
    final task = activeTasks.first;
    final isExpandedCmd = _expandedCommands.contains(task.id);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          type: MaterialType.transparency,
          child: InkWell(
            key: ValueKey('running-job-compact-${task.id}'),
            onTap: () {
              FocusScope.of(context).unfocus();
              _toggleCommand(task.id);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.m + 2,
                vertical: 14,
              ),
              child: Row(
                children: [
                  _buildIndicator(brand.teal),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      task.command,
                      key: ValueKey('running-job-command-${task.id}'),
                      maxLines: isExpandedCmd ? null : 1,
                      overflow: isExpandedCmd
                          ? TextOverflow.visible
                          : TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w500,
                        color: colors.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest.withValues(
                        alpha: 0.6,
                      ),
                      borderRadius: AppRadius.fullAll,
                    ),
                    child: Text(
                      taskDuration(task),
                      key: ValueKey('running-job-duration-${task.id}'),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  IconButton(
                    key: ValueKey('running-job-stop-${task.id}'),
                    tooltip: '停止任务',
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    icon: Icon(
                      LucideIcons.square,
                      size: 14,
                      color: colors.error,
                    ),
                    onPressed: () => ref
                        .read(commandTaskControllerProvider.notifier)
                        .stop(task.id),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (isExpandedCmd)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.m,
              0,
              AppSpacing.m,
              AppSpacing.s,
            ),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.s),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest.withValues(alpha: 0.45),
                borderRadius: AppRadius.smallAll,
              ),
              child: SelectableText(
                task.command,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  color: colors.onSurface,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildExpandedList(
    BuildContext context,
    List<CommandTask> activeTasks,
  ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final dividerColor = colors.outlineVariant.withValues(
      alpha: isDark ? 0.35 : 0.45,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 顶部标题部分：内边距充足，不与边框贴在一起；点击标题行直接收起，不需要收起按钮
        Material(
          type: MaterialType.transparency,
          child: InkWell(
            key: const ValueKey('running-jobs-collapse-button'),
            onTap: () => setState(() => _expanded = false),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.m + 2,
                vertical: 14,
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.terminal, size: 16, color: colors.primary),
                  const SizedBox(width: 12),
                  Text(
                    '后台任务 (${activeTasks.length})',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // 标题与任务列表之间的清晰分割线
        Divider(height: 1, thickness: 1, color: dividerColor),

        // 任务列表部分：背景保持一致
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.viewInsetsOf(context).bottom > 0 ? 100 : 180,
          ),
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.m,
              vertical: AppSpacing.xs,
            ),
            itemCount: activeTasks.length,
            separatorBuilder: (_, _) => Divider(
              height: 1,
              thickness: 0.5,
              color: dividerColor.withValues(alpha: 0.5),
            ),
            itemBuilder: (context, index) {
              final task = activeTasks[index];
              final isExpandedCmd = _expandedCommands.contains(task.id);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            borderRadius: AppRadius.extraSmallAll,
                            onTap: () {
                              FocusScope.of(context).unfocus();
                              _toggleCommand(task.id);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.xs,
                                horizontal: 2,
                              ),
                              child: Text(
                                task.command,
                                key: ValueKey('running-job-command-${task.id}'),
                                maxLines: isExpandedCmd ? null : 1,
                                overflow: isExpandedCmd
                                    ? TextOverflow.visible
                                    : TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w500,
                                  color: colors.onSurface,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.s,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colors.surfaceContainerHighest.withValues(
                              alpha: 0.6,
                            ),
                            borderRadius: AppRadius.fullAll,
                          ),
                          child: Text(
                            taskDuration(task),
                            key: ValueKey('running-job-duration-${task.id}'),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colors.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        IconButton(
                          key: ValueKey('running-job-stop-${task.id}'),
                          tooltip: '停止任务',
                          visualDensity: VisualDensity.compact,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          icon: Icon(
                            LucideIcons.square,
                            size: 14,
                            color: colors.error,
                          ),
                          onPressed: () => ref
                              .read(commandTaskControllerProvider.notifier)
                              .stop(task.id),
                        ),
                      ],
                    ),
                    if (isExpandedCmd)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xs),
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.s),
                          decoration: BoxDecoration(
                            color: colors.surfaceContainerHighest.withValues(
                              alpha: 0.45,
                            ),
                            borderRadius: AppRadius.smallAll,
                          ),
                          child: SelectableText(
                            task.command,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontFamily: 'monospace',
                              color: colors.onSurface,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildIndicator(Color color) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.6),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}
