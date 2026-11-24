import 'dart:io';

import 'package:flutter/material.dart';

import '../content/attachment_image_frame.dart';

import '../../../core/theme/app_motion.dart';
import '../../../core/widgets/app_option_sheet.dart';

import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_icon_badge.dart';
import '../content/content_toolbox.dart';
import 'artifact_text_sheet.dart';
import '../../../data/models/attachment.dart';

/// 查看一份工具产物：文本直接显示内容，图片显示缩略图。
///
/// 文件不在磁盘上时给出明确文案，不假装内容为空。
Future<void> showToolArtifact(
  BuildContext context,
  Attachment attachment, {
  Object? heroTag,
}) {
  final file = File(attachment.localPath);
  if (!file.existsSync()) {
    return showAppDialog<void>(
      context: context,
      builder: (context) => AppDialog(
        title: attachment.name,
        titleStyle: Theme.of(context).textTheme.bodyMedium,
        icon: LucideIcons.circleAlert,
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
    final reduced = AppMotion.reduce(context);
    return Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        transitionDuration: reduced ? Duration.zero : AppMotion.pageOpen,
        reverseTransitionDuration: reduced
            ? Duration.zero
            : AppMotion.pageClose,
        pageBuilder: (context, _, _) {
          final image = Image.file(
            file,
            frameBuilder: attachmentImageFrame,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const Text('图片文件已丢失'),
          );
          return Scaffold(
            appBar: AppBar(
              title: Text(attachment.name),
              actions: [ContentToolbox(attachment: attachment)],
            ),
            body: SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: InteractiveViewer(
                        child: heroTag == null || reduced
                            ? image
                            : Hero(
                                tag: heroTag,
                                createRectTween: (begin, end) =>
                                    _ImageFlightRect(begin: begin, end: end),
                                child: image,
                              ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.s),
                    child: Text(_sizeLabel(attachment.size)),
                  ),
                ],
              ),
            ),
          );
        },
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }
  if (!attachment.mimeType.startsWith('text/')) {
    return showAppDialog<void>(
      context: context,
      builder: (context) => AppDialog(
        title: attachment.name,
        titleStyle: Theme.of(context).textTheme.bodyMedium,
        icon: attachment.mimeType.startsWith('video/')
            ? LucideIcons.video
            : LucideIcons.fileText,
        content: _FileFacts(attachment: attachment),
        actions: [
          if (attachment.mimeType.startsWith('video/'))
            ContentToolbox(attachment: attachment),
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

class _ImageFlightRect extends RectTween {
  _ImageFlightRect({super.begin, super.end});
  @override
  Rect? lerp(double t) => super.lerp(Curves.easeOutCubic.transform(t));
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
    await showAppDialog<void>(
      context: context,
      builder: (context) => AppDialog(
        title: attachment.name,
        titleStyle: Theme.of(context).textTheme.bodyMedium,
        icon: LucideIcons.circleAlert,
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
  await showAppOptionSheet<void>(
    context: context,
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
