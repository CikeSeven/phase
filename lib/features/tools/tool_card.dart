import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_control_style.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_interactive_surface.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../../core/widgets/content_expansion_notification.dart';
import '../../../data/models/attachment.dart';
import '../../../data/models/tool_call_record.dart';
import 'tool_presentation.dart';

/// 默认收起为工具名与状态；展开后滚动查看完整结果和产物。
///
/// 状态从 [ToolCallRecord] 读，界面不另存一份业务副本。
class ToolCard extends StatefulWidget {
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
  State<ToolCard> createState() => _ToolCardState();
}

class _ToolCardState extends State<ToolCard>
    with AutomaticKeepAliveClientMixin {
  static const _maxOutputHeight = 240.0;

  final _headerKey = GlobalKey();
  final _outputController = ScrollController();
  bool _expanded = false;
  bool _userToggled = false;

  @override
  bool get wantKeepAlive => _userToggled;

  @override
  void didUpdateWidget(covariant ToolCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.record.id != widget.record.id) {
      _expanded = false;
      _userToggled = false;
      updateKeepAlive();
    }
  }

  void _toggle() {
    ContentExpansionNotification(anchor: _headerKey.currentContext!)
        .dispatch(context);
    setState(() {
      _expanded = !_expanded;
      _userToggled = true;
    });
    updateKeepAlive();
  }

  @override
  void dispose() {
    _outputController.dispose();
    super.dispose();
  }

  bool _onOutputOverscroll(OverscrollNotification notification) {
    if (notification.depth != 0) return false;
    // 输出滚到边界后，继续拖动交给聊天列表，避免手势卡在卡片内。
    final outer = Scrollable.maybeOf(context)?.position;
    if (outer == null || !outer.hasContentDimensions) return false;
    final target = (outer.pixels + notification.overscroll).clamp(
      outer.minScrollExtent,
      outer.maxScrollExtent,
    );
    if ((target - outer.pixels).abs() > 0.5) outer.jumpTo(target);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final record = widget.record;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final statusColor = ToolPresentation.statusColor(context, record.status);
    final inFlight = ToolPresentation.isInFlight(record.status);
    final output = ToolPresentation.outputText(record);
    final status = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (inFlight)
          AppLoadingIndicator.small(
            color: statusColor,
            semanticsLabel: ToolPresentation.statusLabel(record.status),
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
          style: theme.textTheme.labelMedium?.copyWith(color: statusColor),
        ),
      ],
    );

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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              key: _headerKey,
              expanded: _expanded,
              child: AppInteractiveSurface(
                key: ValueKey('tool-toggle-${record.id}'),
                onTap: _toggle,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.m,
                    vertical: AppSpacing.s,
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // 大字号或窄容器把状态放到下一行，避免工具名被挤成竖排。
                      final stacked =
                          constraints.maxWidth <
                          MediaQuery.textScalerOf(context).scale(14) * 18;
                      final title = Text(
                        ToolPresentation.toolLabel(record.toolName),
                        style: theme.textTheme.labelLarge,
                      );
                      return Row(
                        children: [
                          Icon(
                            ToolPresentation.icon(record.toolName),
                            size: 18,
                            color: colors.onSurfaceVariant,
                          ),
                          const SizedBox(width: AppSpacing.s),
                          Expanded(
                            child: stacked
                                ? Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      title,
                                      const SizedBox(height: AppSpacing.xs),
                                      status,
                                    ],
                                  )
                                : title,
                          ),
                          if (!stacked) ...[
                            const SizedBox(width: AppSpacing.s),
                            status,
                          ],
                          const SizedBox(width: AppSpacing.s),
                          Icon(
                            _expanded
                                ? Symbols.expand_less_rounded
                                : Symbols.expand_more_rounded,
                            size: 18,
                            color: colors.onSurfaceVariant,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
            if (_expanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.m,
                  0,
                  AppSpacing.m,
                  AppSpacing.s,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (record.errorCode == 'storageError' &&
                        output != ToolPresentation.storageFailureMessage) ...[
                      Text(
                        ToolPresentation.storageFailureMessage,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.error,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s),
                    ],
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxHeight: _maxOutputHeight,
                      ),
                      child: Scrollbar(
                        controller: _outputController,
                        thumbVisibility: true,
                        child: NotificationListener<OverscrollNotification>(
                          onNotification: _onOutputOverscroll,
                          child: SingleChildScrollView(
                            key: PageStorageKey('tool-output-${record.id}'),
                            controller: _outputController,
                            primary: false,
                            padding: const EdgeInsets.only(right: AppSpacing.s),
                            child: Text(
                              output,
                              key: ValueKey('tool-result-${record.id}'),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: record.status == ToolCallStatus.failed
                                    ? colors.error
                                    : colors.onSurface,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (widget.artifacts.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Wrap(
                        spacing: AppSpacing.s,
                        runSpacing: AppSpacing.xs,
                        children: [
                          for (final artifact in widget.artifacts)
                            FilledButton.tonalIcon(
                              key: ValueKey('tool-artifact-${artifact.id}'),
                              style: AppControlStyle.compact.copyWith(
                                textStyle: WidgetStatePropertyAll(
                                  theme.textTheme.bodySmall,
                                ),
                                padding: const WidgetStatePropertyAll(
                                  EdgeInsets.symmetric(
                                    horizontal: AppSpacing.m,
                                    vertical: AppSpacing.s,
                                  ),
                                ),
                              ),
                              icon: Icon(
                                artifact.isImage
                                    ? Symbols.image
                                    : Symbols.attach_file,
                                size: 18,
                              ),
                              label: Text(
                                artifact.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onPressed: widget.onOpenArtifact == null
                                  ? null
                                  : () => widget.onOpenArtifact!(artifact),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
