import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/models/attachment.dart';
import '../../../data/models/tool_call_record.dart';
import 'tool_presentation.dart';

/// 聊天流内的工具卡片：工具名、状态、动作摘要与结果。
///
/// 状态从 [ToolCallRecord] 读，界面不另存一份业务副本。
class ToolCard extends StatelessWidget {
  const ToolCard({
    required this.record,
    this.artifacts = const [],
    this.onOpenArtifact,
    super.key,
  });

  final ToolCallRecord record;

  /// 产物附件（写文件、下载等），由调用方按记录的 artifacts 查好传入。
  final List<Attachment> artifacts;

  final void Function(Attachment attachment)? onOpenArtifact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final statusColor = ToolPresentation.statusColor(context, record.status);
    final inFlight = ToolPresentation.isInFlight(record.status);
    final summary = ToolPresentation.summary(record);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.l,
        vertical: AppSpacing.xs,
      ),
      child: Material(
        key: ValueKey('tool-card-${record.id}'),
        color: colors.surfaceContainerHigh.withValues(alpha: 0.72),
        borderRadius: AppRadius.mediumAll,
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    ToolPresentation.icon(record.toolName),
                    size: 18,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppSpacing.s),
                  Expanded(
                    child: Text(
                      ToolPresentation.toolLabel(record.toolName),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s),
                  if (inFlight)
                    SizedBox.square(
                      dimension: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: statusColor,
                      ),
                    )
                  else
                    Icon(
                      ToolPresentation.statusIcon(record.status),
                      size: 16,
                      color: statusColor,
                    ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    ToolPresentation.statusLabel(record.status),
                    key: ValueKey('tool-status-${record.id}'),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: statusColor,
                    ),
                  ),
                ],
              ),
              if ((record.target ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  record.target!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
              if (summary.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.s),
                Text(
                  summary,
                  key: ValueKey('tool-result-${record.id}'),
                  maxLines: record.status == ToolCallStatus.succeeded ? 3 : 6,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: record.status == ToolCallStatus.failed
                        ? colors.error
                        : colors.onSurface,
                  ),
                ),
              ],
              if (artifacts.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.s),
                Wrap(
                  spacing: AppSpacing.s,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final artifact in artifacts)
                      ActionChip(
                        key: ValueKey('tool-artifact-${artifact.id}'),
                        avatar: const Icon(Symbols.attach_file, size: 16),
                        label: Text(
                          artifact.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onPressed: onOpenArtifact == null
                            ? null
                            : () => onOpenArtifact!(artifact),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
