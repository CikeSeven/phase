import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_interactive_surface.dart';

enum AttachmentSource { camera, gallery, file }

Future<AttachmentSource?> showAttachmentSourceSheet(BuildContext context) =>
    showModalBottomSheet<AttachmentSource>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => const AttachmentSourceSheet(),
    );

/// 三个附件来源按内容展开；短窗口可滚动，大字号切成横向条目。
class AttachmentSourceSheet extends StatefulWidget {
  const AttachmentSourceSheet({super.key});

  @override
  State<AttachmentSourceSheet> createState() => _AttachmentSourceSheetState();
}

class _AttachmentSourceSheetState extends State<AttachmentSourceSheet> {
  bool _closing = false;

  void _select(AttachmentSource? source) {
    if (_closing) return;
    _closing = true;
    Navigator.of(context).pop(source);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.75,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            0,
            AppSpacing.xl,
            AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text('添加附件', style: theme.textTheme.titleLarge),
                    ),
                  ),
                  IconButton(
                    tooltip: '关闭',
                    onPressed: () => _select(null),
                    icon: const Icon(Symbols.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.l),
              LayoutBuilder(
                builder: (context, constraints) {
                  final vertical =
                      constraints.maxWidth <
                      3 * (64 + MediaQuery.textScalerOf(context).scale(14));
                  final choices = [
                    for (final (source, label, icon) in [
                      (
                        AttachmentSource.camera,
                        '拍照',
                        Symbols.photo_camera_rounded,
                      ),
                      (
                        AttachmentSource.gallery,
                        '相册',
                        Symbols.photo_library_rounded,
                      ),
                      (
                        AttachmentSource.file,
                        '文件',
                        Symbols.folder_open_rounded,
                      ),
                    ])
                      AppInteractiveSurface(
                        key: ValueKey('attach-${source.name}'),
                        color: colors.primaryContainer.withValues(alpha: 0.55),
                        onTap: () => _select(source),
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.l),
                          child: vertical
                              ? Row(
                                  children: [
                                    _SourceIcon(icon),
                                    const SizedBox(width: AppSpacing.l),
                                    Expanded(
                                      child: Text(
                                        label,
                                        style: theme.textTheme.titleSmall,
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _SourceIcon(icon),
                                    const SizedBox(height: AppSpacing.m),
                                    Text(
                                      label,
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.titleSmall,
                                    ),
                                  ],
                                ),
                        ),
                      ),
                  ];
                  return vertical
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          spacing: AppSpacing.s,
                          children: choices,
                        )
                      : Row(
                          spacing: AppSpacing.s,
                          children: [
                            for (final choice in choices)
                              Expanded(child: choice),
                          ],
                        );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SourceIcon extends StatelessWidget {
  const _SourceIcon(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Icon(
      icon,
      size: 24,
      fill: 1,
      weight: 500,
      color: Theme.of(context).colorScheme.onPrimaryContainer,
    ),
  );
}
