import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_icon_badge.dart';
import '../../../core/widgets/app_interactive_surface.dart';
import '../../../core/widgets/app_menu_anchor.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../projects/project_path_display.dart';

/// 文件与目录项组件；提供统一的类型徽标、状态文本与操作菜单。
class WorkspaceFileTile extends StatefulWidget {
  const WorkspaceFileTile({
    required this.name,
    required this.path,
    required this.size,
    required this.onTap,
    this.isDirectory = false,
    this.onExport,
    this.onPreview,
    this.isBusy = false,
    this.customSubtitle,
    this.customIcon,
    this.customTone,
    super.key,
  });

  final String name;
  final String path;
  final int size;
  final bool isDirectory;
  final VoidCallback? onTap;
  final VoidCallback? onExport;
  final VoidCallback? onPreview;
  final bool isBusy;
  final String? customSubtitle;
  final IconData? customIcon;
  final AppTone? customTone;

  @override
  State<WorkspaceFileTile> createState() => _WorkspaceFileTileState();
}

class _WorkspaceFileTileState extends State<WorkspaceFileTile> {
  final _menuController = MenuController();
  final _menuFocus = FocusNode();

  @override
  void dispose() {
    _menuFocus.dispose();
    super.dispose();
  }

  Future<void> _copyPath() async {
    await Clipboard.setData(ClipboardData(text: widget.path));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(buildAppSnackBar(content: Text('已复制路径「${widget.path}」')));
  }

  Future<void> _copyName() async {
    await Clipboard.setData(ClipboardData(text: widget.name));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(buildAppSnackBar(content: Text('已复制名称「${widget.name}」')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDir = widget.isDirectory || widget.size < 0;
    final tone =
        widget.customTone ??
        (isDir
            ? AppTone.primary
            : projectFileTone(widget.name, isDirectory: false));
    final icon =
        widget.customIcon ??
        (isDir
            ? LucideIcons.folder
            : projectFileIcon(widget.name, isDirectory: false));

    final subtitleText =
        widget.customSubtitle ??
        (isDir
            ? '文件夹'
            : '${projectFileTypeLabel(widget.name)} · ${formatFileSize(widget.size)}');

    const menuWidth = 180.0;

    return AppInteractiveSurface(
      color: colors.surfaceContainerLow,
      radius: AppRadius.medium,
      onTap: widget.isBusy ? null : widget.onTap,
      onLongPress: isDir || widget.isBusy ? null : _menuController.open,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.m,
          vertical: AppSpacing.s,
        ),
        child: Row(
          children: [
            AppIconBadge(icon: icon, tone: tone, size: 40, iconSize: 20),
            const SizedBox(width: AppSpacing.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: isDir ? FontWeight.w600 : FontWeight.w500,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitleText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (isDir) ...[
              const SizedBox(width: AppSpacing.s),
              Icon(
                LucideIcons.chevronRight,
                size: 20,
                color: colors.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ] else ...[
              if (widget.onExport != null) ...[
                IconButton(
                  tooltip: '导出文件',
                  onPressed: widget.isBusy ? null : widget.onExport,
                  icon: const Icon(LucideIcons.fileDown, size: 18),
                ),
              ],
              AppMenuAnchor(
                controller: _menuController,
                childFocusNode: _menuFocus,
                alignmentOffset: const Offset(-menuWidth, AppSpacing.xs),
                style: const MenuStyle(
                  alignment: AlignmentDirectional.bottomEnd,
                  minimumSize: WidgetStatePropertyAll(Size(menuWidth, 0)),
                  maximumSize: WidgetStatePropertyAll(
                    Size(menuWidth, double.infinity),
                  ),
                ),
                menuChildren: [
                  if (widget.onPreview != null)
                    AppMenuItemButton(
                      leadingIcon: const Icon(LucideIcons.eye, size: 18),
                      onPressed: widget.onPreview,
                      child: const Text('预览文件'),
                    ),
                  if (widget.onExport != null)
                    AppMenuItemButton(
                      leadingIcon: const Icon(LucideIcons.fileDown, size: 18),
                      onPressed: widget.onExport,
                      child: const Text('导出文件'),
                    ),
                  AppMenuItemButton(
                    leadingIcon: const Icon(LucideIcons.copy, size: 18),
                    onPressed: _copyPath,
                    child: const Text('复制相对路径'),
                  ),
                  AppMenuItemButton(
                    leadingIcon: const Icon(LucideIcons.copy, size: 18),
                    onPressed: _copyName,
                    child: const Text('复制文件名'),
                  ),
                ],
                builder: (context, controller, _) => IconButton(
                  tooltip: '更多操作',
                  onPressed: widget.isBusy ? null : controller.open,
                  icon: const Icon(LucideIcons.moreVertical, size: 18),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
