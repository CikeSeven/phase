import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gpt_markdown/custom_widgets/code_field.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/frosted_surface.dart';

/// 保留 Markdown 代码高亮，以可伸缩的语言标签和复制按钮替代固定宽度头部。
class ChatCodeBlock extends StatelessWidget {
  const ChatCodeBlock({required this.language, required this.code, super.key});

  final String language;
  final String code;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return FrostedSurface(
      blur: 0,
      borderRadius: AppRadius.mediumAll,
      color: colors.surfaceContainerHigh.withValues(alpha: 0.84),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.m),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    language.isEmpty ? '代码' : language,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '复制代码',
                  onPressed: () => _copy(context),
                  icon: const Icon(Symbols.content_copy, size: 20),
                ),
              ],
            ),
          ),
          CodeField(
            name: language,
            codes: code,
            style: CodeBlockStyle(
              backgroundColor: colors.surface.withValues(alpha: 0),
              textColor: colors.onSurface,
              borderRadius: Radius.zero,
              borderWidth: 0,
              fontSize: (theme.textTheme.bodyLarge?.fontSize ?? 16) - 1,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.m,
                0,
                AppSpacing.m,
                AppSpacing.m,
              ),
              showLanguageLabel: false,
              showCopyButton: false,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copy(BuildContext context) async {
    String feedback;
    try {
      await Clipboard.setData(ClipboardData(text: code));
      feedback = '代码已复制';
    } on PlatformException {
      feedback = '复制失败，请重试';
    }
    if (!context.mounted) return;
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(feedback)));
  }
}
