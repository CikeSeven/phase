import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// 默认收起为工具名与状态；展开后查看完整输入、输出和产物。
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
  final _headerKey = GlobalKey();
  final _inputController = ScrollController();
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
    _inputController.dispose();
    _outputController.dispose();
    super.dispose();
  }

  bool _onContentOverscroll(OverscrollNotification notification) {
    if (notification.depth != 0) return false;
    // 内容滚到边界后，继续拖动交给聊天列表，避免手势卡在卡片内。
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
    final output = _expanded ? ToolPresentation.outputText(record) : '';
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
                        ToolPresentation.recordLabel(record),
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
                    _ToolContentSection(
                      title: '输入参数',
                      text: ToolPresentation.inputText(record),
                      textKey: ValueKey('tool-arguments-${record.id}'),
                      scrollKey: PageStorageKey('tool-input-${record.id}'),
                      controller: _inputController,
                      maxHeight: 160,
                      onOverscroll: _onContentOverscroll,
                    ),
                    const SizedBox(height: AppSpacing.s),
                    _ToolContentSection(
                      title: '输出内容',
                      text: output,
                      textKey: ValueKey('tool-result-${record.id}'),
                      scrollKey: PageStorageKey('tool-output-${record.id}'),
                      controller: _outputController,
                      maxHeight: 240,
                      onOverscroll: _onContentOverscroll,
                      isError: record.status == ToolCallStatus.failed,
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

class _ToolContentSection extends StatelessWidget {
  const _ToolContentSection({
    required this.title,
    required this.text,
    required this.textKey,
    required this.scrollKey,
    required this.controller,
    required this.maxHeight,
    required this.onOverscroll,
    this.isError = false,
  });

  final String title;
  final String text;
  final Key textKey;
  final PageStorageKey<String> scrollKey;
  final ScrollController controller;
  final double maxHeight;
  final bool Function(OverscrollNotification) onOverscroll;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
            IconButton(
              tooltip: '复制$title',
              onPressed: () => _copy(context),
              icon: const Icon(Symbols.content_copy, size: 18),
            ),
          ],
        ),
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Scrollbar(
            controller: controller,
            thumbVisibility: true,
            child: NotificationListener<OverscrollNotification>(
              onNotification: onOverscroll,
              child: SingleChildScrollView(
                key: scrollKey,
                controller: controller,
                primary: false,
                padding: const EdgeInsets.only(right: AppSpacing.s),
                child: SelectionArea(
                  child: Text(
                    text,
                    key: textKey,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      color: isError ? colors.error : colors.onSurface,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _copy(BuildContext context) async {
    String feedback;
    try {
      await Clipboard.setData(ClipboardData(text: text));
      feedback = '已复制$title';
    } on PlatformException {
      feedback = '复制失败，请重试';
    }
    if (!context.mounted) return;
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(feedback)));
  }
}
