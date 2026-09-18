import 'dart:io';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_icon_badge.dart';
import 'artifact_text_sheet.dart';
import '../../../data/models/attachment.dart';

/// 查看一份工具产物：文本直接显示内容，图片显示缩略图。
///
/// 文件不在磁盘上时给出明确文案，不假装内容为空。
Future<void> showToolArtifact(BuildContext context, Attachment attachment) {
  final file = File(attachment.localPath);
  if (!file.existsSync()) {
    return showDialog<void>(
      context: context,
      builder: (context) => AppDialog(
        title: attachment.name,
        titleStyle: Theme.of(context).textTheme.bodyMedium,
        icon: Symbols.error,
        tone: AppTone.gold,
        description: '产物文件不存在，可能已被删除或移动。',
        content: _FileFacts(attachment: attachment),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
  if (attachment.isImage) {
    return showDialog<void>(
      context: context,
      builder: (context) => AppDialog(
        title: attachment.name,
        titleStyle: Theme.of(context).textTheme.bodyMedium,
        description: _sizeLabel(attachment.size),
        content: InteractiveViewer(
          child: Image.file(
            file,
            errorBuilder: (_, _, _) => const Padding(
              padding: EdgeInsets.all(AppSpacing.l),
              child: Text('图片文件已丢失'),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
  if (!attachment.mimeType.startsWith('text/')) {
    return showDialog<void>(
      context: context,
      builder: (context) => AppDialog(
        title: attachment.name,
        titleStyle: Theme.of(context).textTheme.bodyMedium,
        icon: Symbols.description,
        description: '这是二进制文件，不能按文本预览。',
        content: _FileFacts(attachment: attachment),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
  return _showTextPreview(context, attachment, file);
}

Future<void> _showTextPreview(
  BuildContext context,
  Attachment attachment,
  File file,
) async {
  final ({String text, int? next}) page;
  try {
    page = await readArtifactPage(file, 0);
  } on FileSystemException {
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AppDialog(
        title: attachment.name,
        titleStyle: Theme.of(context).textTheme.bodyMedium,
        icon: Symbols.error,
        tone: AppTone.gold,
        description: '读取产物文件失败。',
        content: _FileFacts(attachment: attachment),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
    return;
  }
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    // 拖动杆由 AppSheet 自己画，这里不能再让框架画一个（会变成两根）。
    builder: (context) => ArtifactTextSheet(
      attachment: attachment,
      initialText: page.text,
      nextOffset: page.next,
    ),
  );
}

/// 文件事实：名称、类型与大小，用于无法预览时说明这份产物是什么。
class _FileFacts extends StatelessWidget {
  const _FileFacts({required this.attachment});

  final Attachment attachment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(attachment.name, style: theme.textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '${attachment.mimeType} · ${_sizeLabel(attachment.size)}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

String _sizeLabel(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
