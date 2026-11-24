import 'dart:io';

import 'package:flutter/material.dart';

import '../content/attachment_image_frame.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../content/attachment_image_preview.dart';
import '../../../data/models/attachment.dart';

class ToolScreenshotPreview extends StatelessWidget {
  const ToolScreenshotPreview({
    required this.attachment,
    this.onOpen,
    this.onOpenImage,
    this.semanticsLabel = '查看截图',
    super.key,
  });

  final Attachment attachment;
  final VoidCallback? onOpen;
  final ValueChanged<Object>? onOpenImage;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.s),
    child: Semantics(
      label: semanticsLabel,
      button: onOpen != null || onOpenImage != null,
      child: AttachmentImagePreview(
        attachment: attachment,
        onOpen: onOpenImage ?? (onOpen == null ? null : (_) => onOpen!()),
        child: ClipRRect(
          borderRadius: AppRadius.smallAll,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220, minHeight: 48),
            child: AspectRatio(
              aspectRatio:
                  (attachment.width ?? 0) > 0 && (attachment.height ?? 0) > 0
                  ? attachment.width! / attachment.height!
                  : 16 / 9,
              child: Image.file(
                File(attachment.localPath),
                frameBuilder: attachmentImageFrame,
                key: ValueKey('tool-screenshot-${attachment.id}'),
                fit: BoxFit.contain,
                cacheWidth: 600,
                excludeFromSemantics: true,
                errorBuilder: (_, _, _) => const Padding(
                  padding: EdgeInsets.all(AppSpacing.m),
                  child: Text('图片文件无法读取，可能已被删除或损坏。'),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
