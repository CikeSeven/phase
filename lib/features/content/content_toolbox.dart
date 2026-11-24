import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/error/failure.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_loading_indicator.dart';
import '../../core/widgets/app_snack_bar.dart';
import '../../data/models/attachment.dart';
import 'content_file_saver.dart';

Future<void> copyContentText(BuildContext context, String text) async {
  String result;
  try {
    await Clipboard.setData(ClipboardData(text: text));
    result = '已复制';
  } on PlatformException {
    result = '复制失败，请重试';
  }
  if (context.mounted) _showFeedback(context, result);
}

void _showFeedback(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(buildAppSnackBar(content: Text(message)));
}

class ContentToolbox extends StatelessWidget {
  const ContentToolbox({
    this.text,
    this.attachment,
    this.onRegenerate,
    super.key,
  });

  final String? text;
  final Attachment? attachment;
  final VoidCallback? onRegenerate;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: AppSpacing.xs,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      if (text case final content? when content.trim().isNotEmpty)
        IconButton(
          key: const ValueKey('copy-message'),
          tooltip: '复制文本',
          onPressed: () => copyContentText(context, content),
          icon: const Icon(LucideIcons.copy, size: 20),
        ),
      if (attachment case final file?) _SaveButton(attachment: file),
      if (onRegenerate != null)
        IconButton(
          key: const ValueKey('regenerate-message'),
          tooltip: '重新生成',
          onPressed: onRegenerate,
          icon: const Icon(LucideIcons.rotateCw, size: 20),
        ),
    ],
  );
}

class _SaveButton extends StatefulWidget {
  const _SaveButton({required this.attachment});

  final Attachment attachment;

  @override
  State<_SaveButton> createState() => _SaveButtonState();
}

class _SaveButtonState extends State<_SaveButton> {
  bool _saving = false;

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final saved = await saveContentFile(widget.attachment);
      if (mounted && saved) _showFeedback(context, '已保存文件');
    } on Failure catch (error) {
      if (mounted) _showFeedback(context, error.userMessage);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => IconButton(
    key: ValueKey('save-content-${widget.attachment.id}'),
    tooltip: switch (widget.attachment.mimeType) {
      final mime when mime.startsWith('image/') => '保存图片',
      final mime when mime.startsWith('video/') => '保存视频',
      _ => '保存文件',
    },
    onPressed: _saving ? null : _save,
    icon: _saving
        ? const AppLoadingIndicator.small(semanticsLabel: '正在保存')
        : const Icon(LucideIcons.download, size: 20),
  );
}
