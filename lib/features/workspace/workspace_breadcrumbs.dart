import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../projects/project_path_display.dart';

/// 工作区路径面包屑导航条；支持各级目录直达与返回上一级。
class WorkspaceBreadcrumbs extends StatefulWidget {
  const WorkspaceBreadcrumbs({
    required this.currentPath,
    required this.rootLabel,
    required this.onNavigate,
    this.onGoUp,
    super.key,
  });

  final String currentPath;
  final String rootLabel;
  final ValueChanged<String> onNavigate;
  final VoidCallback? onGoUp;

  @override
  State<WorkspaceBreadcrumbs> createState() => _WorkspaceBreadcrumbsState();
}

class _WorkspaceBreadcrumbsState extends State<WorkspaceBreadcrumbs> {
  final _scroll = ScrollController();

  @override
  void didUpdateWidget(WorkspaceBreadcrumbs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentPath != oldWidget.currentPath) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final segments = splitProjectPath(widget.currentPath);
    final isRoot = segments.isEmpty;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow.withValues(alpha: 0.72),
        borderRadius: AppRadius.mediumAll,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          if (!isRoot && widget.onGoUp != null) ...[
            IconButton(
              tooltip: '返回上一级',
              onPressed: widget.onGoUp,
              icon: const Icon(LucideIcons.folderUp, size: 18),
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
          Expanded(
            child: SingleChildScrollView(
              controller: _scroll,
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _crumbItem(
                    label: widget.rootLabel,
                    icon: LucideIcons.folderRoot,
                    isActive: isRoot,
                    onTap: isRoot ? null : () => widget.onNavigate('.'),
                  ),
                  for (var i = 0; i < segments.length; i++) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs,
                      ),
                      child: Icon(
                        LucideIcons.chevronRight,
                        size: 14,
                        color: colors.onSurfaceVariant.withValues(alpha: 0.4),
                      ),
                    ),
                    _crumbItem(
                      label: segments[i],
                      isActive: i == segments.length - 1,
                      onTap: i == segments.length - 1
                          ? null
                          : () => widget.onNavigate(
                              segments.sublist(0, i + 1).join('/'),
                            ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _crumbItem({
    required String label,
    required bool isActive,
    IconData? icon,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final content = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 16,
              color: isActive ? colors.primary : colors.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              color: isActive ? colors.primary : colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) {
      return content;
    }

    return InkWell(
      borderRadius: AppRadius.smallAll,
      onTap: onTap,
      child: content,
    );
  }
}
