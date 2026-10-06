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
    final textStyle = theme.textTheme.bodyMedium!.copyWith(
      fontSize: 14,
      height: 1.45,
      color: colors.onSurface,
    );
    final headerColor = Color.alphaBlend(
      colors.primary.withValues(alpha: 0.08),
      colors.surfaceContainerHigh,
    );

    // 表格块嵌在 Markdown 的 WidgetSpan 中，由外层统一缩放。
    return MediaQuery.withNoTextScaling(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
        child: Material(
          color: colors.surfaceContainerLowest,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.controlAll,
            side: BorderSide(
              color: colors.outlineVariant.withValues(alpha: 0.45),
              width: 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: ChatMarkdownScrollView(
            child: Table(
              textDirection: config.textDirection,
              // 使用自然列宽，配合横向滚动视图保证单元格内容清晰可读。
              defaultColumnWidth: const IntrinsicColumnWidth(),
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              border: TableBorder(
                horizontalInside: BorderSide(
                  color: colors.outlineVariant.withValues(alpha: 0.3),
                  width: 1,
                ),
                verticalInside: BorderSide(
                  color: colors.outlineVariant.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
              children: [
                for (final (index, row) in rows.indexed)
                  TableRow(
                    decoration: BoxDecoration(
                      color: row.isHeader
                          ? headerColor
                          : index.isEven
                          ? colors.surfaceContainerLowest
                          : colors.surfaceContainerLow.withValues(alpha: 0.45),
                    ),
                    children: [
                      for (final field in row.fields)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.l,
                            vertical: AppSpacing.m,
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
                                color: row.isHeader
                                    ? colors.onSurface
                                    : colors.onSurface.withValues(alpha: 0.9),
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
