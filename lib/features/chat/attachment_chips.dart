import 'dart:io';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/models/attachment.dart';

/// 输入栏上方的附件草稿条：横向滚动，图片缩略图/文件名 + 移除按钮。
class AttachmentChips extends StatelessWidget {
  const AttachmentChips({
    required this.attachments,
    required this.onRemove,
    super.key,
  });

  final List<Attachment> attachments;
  final ValueChanged<Attachment> onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView.separated(
        key: const ValueKey('attachment-chips'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(top: AppSpacing.s),
        itemCount: attachments.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.s),
        itemBuilder: (context, index) {
          final attachment = attachments[index];
          return _Chip(
            key: ValueKey('attachment-${attachment.id}'),
            attachment: attachment,
            onRemove: () => onRemove(attachment),
          );
        },
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.attachment, required this.onRemove, super.key});

  final Attachment attachment;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Material(
      color: colors.surfaceContainerHigh,
      borderRadius: AppRadius.smallAll,
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (attachment.isImage)
            Image.file(
              File(attachment.localPath),
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.square(
                dimension: 48,
                child: Icon(Symbols.broken_image),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.only(left: AppSpacing.s),
              child: Icon(Symbols.description, size: 20),
            ),
          if (!attachment.isImage) ...[
            const SizedBox(width: AppSpacing.xs),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: Text(
                attachment.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium,
              ),
            ),
            // 文档抽取失败：给出真实原因，而不是让内容悄悄缺失。
            if (attachment.extractionError != null) ...[
              const SizedBox(width: AppSpacing.xs),
              Tooltip(
                message: attachment.extractionError!,
                child: Icon(
                  Symbols.warning,
                  key: ValueKey('attachment-warning-${attachment.id}'),
                  size: 16,
                  color: colors.error,
                ),
              ),
            ],
          ],
          IconButton(
            tooltip: '移除附件',
            color: colors.error,
            onPressed: onRemove,
            icon: const Icon(Symbols.close, size: 18),
          ),
        ],
      ),
    );
  }
}

/// 消息气泡里的附件展示：图片缩略图（点开大图预览）与文件标签。
class MessageAttachments extends StatelessWidget {
  const MessageAttachments({required this.attachments, super.key});

  final List<Attachment> attachments;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.s,
      runSpacing: AppSpacing.s,
      children: [
        for (final attachment in attachments)
          if (attachment.isImage)
            GestureDetector(
              key: ValueKey('message-attachment-${attachment.id}'),
              onTap: () => _previewImage(context, attachment),
              child: ClipRRect(
                borderRadius: AppRadius.smallAll,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 160,
                    maxHeight: 160,
                  ),
                  child: Image.file(
                    File(attachment.localPath),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        _fileFallback(context, attachment),
                  ),
                ),
              ),
            )
          else
            _fileFallback(context, attachment),
      ],
    );
  }

  Widget _fileFallback(BuildContext context, Attachment attachment) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHigh,
      borderRadius: AppRadius.smallAll,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Symbols.description, size: 18),
            const SizedBox(width: AppSpacing.xs),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: Text(
                attachment.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _previewImage(BuildContext context, Attachment attachment) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: InteractiveViewer(
          child: Image.file(
            File(attachment.localPath),
            errorBuilder: (_, _, _) => const Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: Text('图片文件已丢失'),
            ),
          ),
        ),
      ),
    );
  }
}
