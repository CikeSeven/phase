import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import 'chat_markdown_scroll_view.dart';

class ChatMarkdownTable extends StatelessWidget {
  const ChatMarkdownTable({
    required this.rows,
    required this.config,
    super.key,
  });

  final List<CustomTableRow> rows;
  final GptMarkdownConfig config;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textStyle = theme.textTheme.bodyLarge!.copyWith(
      fontSize: 15,
      height: 1.5,
      color: colors.onSurface,
    );
    final headerColor = Color.alphaBlend(
      colors.primary.withValues(alpha: 0.08),
      colors.surfaceContainerLow,
    );
    // 块嵌在 Markdown 的 WidgetSpan 中，由外层段落统一缩放一次。
    return MediaQuery.withNoTextScaling(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
        child: Material(
          color: colors.surfaceContainerLowest,
          borderRadius: AppRadius.controlAll,
          clipBehavior: Clip.antiAlias,
          child: ChatMarkdownScrollView(
            child: Table(
              textDirection: config.textDirection,
              // 横向约束无上限，使用自然列宽而不是挤窄或截断单元格。
              defaultColumnWidth: const IntrinsicColumnWidth(),
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              border: TableBorder(
                horizontalInside: BorderSide(
                  color: colors.outlineVariant.withValues(alpha: 0.6),
                ),
              ),
              children: [
                for (final (index, row) in rows.indexed)
                  TableRow(
                    decoration: BoxDecoration(
                      color: row.isHeader
                          ? headerColor
                          : index.isEven
                          ? colors.surfaceContainerLow
                          : colors.surfaceContainerLowest,
                    ),
                    children: [
                      for (final field in row.fields)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.m,
                            vertical: AppSpacing.s,
                          ),
                          child: MdWidget(
                            context,
                            field.data.trim(),
                            false,
                            config: config.copyWith(
                              scope: MarkdownScope.tableCell,
                              textAlign: field.alignment,
                              style: textStyle.copyWith(
                                fontWeight: row.isHeader
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
