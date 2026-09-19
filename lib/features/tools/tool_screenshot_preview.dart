import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_interactive_surface.dart';
import '../../../data/models/attachment.dart';

class ToolScreenshotPreview extends StatelessWidget {
  const ToolScreenshotPreview({
    required this.attachment,
    this.onOpen,
    super.key,
  });

  final Attachment attachment;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.s),
    child: Semantics(
      label: '查看截图',
      button: onOpen != null,
      child: AppInteractiveSurface(
        onTap: onOpen,
        child: ClipRRect(
          borderRadius: AppRadius.smallAll,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220, minHeight: 48),
            child: Image.file(
              File(attachment.localPath),
              key: ValueKey('tool-screenshot-${attachment.id}'),
              fit: BoxFit.contain,
              cacheWidth: 600,
              excludeFromSemantics: true,
              errorBuilder: (_, _, _) => const Padding(
                padding: EdgeInsets.all(AppSpacing.m),
                child: Text('截图文件无法读取，可能已被删除或损坏。'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
