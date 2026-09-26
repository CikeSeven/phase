import '../commands/system_channel_tools.dart';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_control_style.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../core/widgets/app_expansion.dart';
import '../../../core/widgets/app_interactive_surface.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/content_expansion_notification.dart';
import '../../../data/models/attachment.dart';
import '../../../data/models/tool_call_record.dart';
import 'tool_call_display.dart';
import 'tool_diff.dart';
import 'tool_diff_view.dart';
import 'tool_presentation.dart';
import 'tool_screenshot_preview.dart';

/// 默认收起为工具名与状态；展开后查看完整输入、输出和产物。
///
/// 状态从 [ToolCallRecord] 读，界面不另存一份业务副本。
class ToolCard extends StatefulWidget {
  const ToolCard({
    required this.record,
    this.appName,
    this.artifacts = const [],
    this.onOpenArtifact,
    this.grouped = false,
    super.key,
  });

  final ToolCallRecord record;
  final String? appName;

  /// 连续卡片组由外层统一提供圆角与外间距。
  final bool grouped;

  /// 产物附件（写文件、下载等），由调用方按记录的 artifacts 查好传入。
  final List<Attachment> artifacts;

  final void Function(Attachment attachment)? onOpenArtifact;

  @override
  State<ToolCard> createState() => _ToolCardState();
}

class _ToolCardState extends State<ToolCard>
    with AutomaticKeepAliveClientMixin {
  final _headerKey = GlobalKey();
  final _contentController = ScrollController();
  bool _expanded = false;
  bool _userToggled = false;
  bool _followContent = true;
  bool _scrollToEndScheduled = false;
  ToolCallRecord? _displayRecord;
  ToolCallDisplay? _display;

  @override
  bool get wantKeepAlive => _userToggled;

  @override
  void didUpdateWidget(covariant ToolCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.record.id != widget.record.id) {
      _expanded = false;
      _userToggled = false;
      _display = null;
      _displayRecord = null;
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
    if (_expanded) {
      _followContent = true;
      _scheduleScrollToEnd();
    }
  }

  void _scheduleScrollToEnd() {
    if (!mounted || !_expanded || !_followContent || _scrollToEndScheduled) {
      return;
    }
    _scrollToEndScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToEndScheduled = false;
      if (!mounted ||
          !_expanded ||
          !_followContent ||
          !_contentController.hasClients) {
        return;
      }
      final position = _contentController.position;
      if ((position.maxScrollExtent - position.pixels).abs() > 0.5) {
        position.jumpTo(position.maxScrollExtent);
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  bool _onContentScroll(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    if (notification is UserScrollNotification &&
        notification.direction != ScrollDirection.idle) {
      _followContent = false;
    } else if (notification is ScrollEndNotification) {
      _followContent = notification.metrics.extentAfter <= 1;
    }
    if (notification is! OverscrollNotification) return false;
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
    final brand = context.brandColors;
    final failed = record.status == ToolCallStatus.failed;
    final cardForeground = failed
        ? brand.onLavenderContainer
        : brand.onTealContainer;
    // 有色底面上的中性状态用辅助文字色，避免 outline 对比度不足。
    final statusColor = switch (record.status) {
      ToolCallStatus.rejected ||
      ToolCallStatus.cancelled => colors.onSurfaceVariant,
      _ => ToolPresentation.statusColor(context, record.status),
    };
    final inFlight = ToolPresentation.isInFlight(record.status);
    if (_expanded && !identical(record, _displayRecord)) {
      _display = ToolCallDisplay.fromRecord(record);
      _displayRecord = record;
    }
    // 收起动画继续呈现最后一次展开的内容，不在动画开始时清空。
    final display = _display;
    final detail = ToolCallDisplay.detail(record, appName: widget.appName);
    final command = isCommandToolName(record.toolName);
    final artifacts = [
      for (final artifact in widget.artifacts)
        if (ToolCallDisplay.artifactLabel(record, artifact)
            case final String label)
          (artifact: artifact, label: label),
    ];
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
      padding: widget.grouped
          ? EdgeInsets.zero
          : const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Material(
        key: ValueKey('tool-card-${record.id}'),
        color: failed ? brand.lavenderContainer : brand.tealContainer,
        borderRadius: widget.grouped ? BorderRadius.zero : AppRadius.mediumAll,
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
                radius: widget.grouped ? 0 : AppRadius.medium,
                animateShape: !widget.grouped,
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
                      final title = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ToolCallDisplay.title(record),
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: cardForeground,
                            ),
                          ),
                          if (detail != null)
                            AppExpansionBody(
                              expanded: !command || !_expanded,
                              builder: (context) => Padding(
                                padding: const EdgeInsets.only(
                                  top: AppSpacing.xs,
                                ),
                                child: AnimatedSize(
                                  duration: AppMotion.reduce(context)
                                      ? Duration.zero
                                      : _expanded
                                      ? AppMotion.expansionOpen
                                      : AppMotion.expansionClose,
                                  curve: AppMotion.expansionCurve,
                                  alignment: Alignment.topLeft,
                                  child: Text(
                                    detail,
                                    key: ValueKey('tool-detail-${record.id}'),
                                    maxLines: _expanded && !command ? null : 2,
                                    overflow: _expanded && !command
                                        ? null
                                        : TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                      return Row(
                        children: [
                          Icon(
                            ToolPresentation.icon(record.toolName),
                            size: 18,
                            color: cardForeground,
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
                          AppExpansionArrow(
                            expanded: _expanded,
                            color: cardForeground,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
            AppExpansionBody(
              key: ValueKey('tool-expansion-${record.id}'),
              expanded: _expanded,
              builder: (context) => display == null
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.m,
                        0,
                        AppSpacing.m,
                        AppSpacing.s,
                      ),
                      child: _ToolCardContent(
                        scrollKey: PageStorageKey('tool-content-${record.id}'),
                        controller: _contentController,
                        onScroll: _onContentScroll,
                        onMetricsChanged: _scheduleScrollToEnd,
                        children: [
                          if (record.errorCode == 'storageError' &&
                              display.output !=
                                  ToolPresentation.storageFailureMessage) ...[
                            Text(
                              ToolPresentation.storageFailureMessage,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.error,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.s),
                          ],
                          if (display.metadata case final String metadata
                              when metadata.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.s,
                              ),
                              child: Text(
                                metadata,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ),
                          if (display.diff != null)
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '+${display.diff!.where((l) => l.kind == ToolDiffKind.added).length} '
                                    '−${display.diff!.where((l) => l.kind == ToolDiffKind.removed).length}',
                                    style: theme.textTheme.labelMedium,
                                  ),
                                ),
                                IconButton(
                                  tooltip: display.copyLabel,
                                  onPressed: () => _copy(
                                    context,
                                    display.copyText!,
                                    display.copyLabel,
                                  ),
                                  icon: const Icon(
                                    Symbols.content_copy,
                                    size: 18,
                                  ),
                                ),
                              ],
                            ),
                          if (display.diff case final diff?)
                            if (diff.isEmpty)
                              const Text('（空文件）')
                            else
                              ToolDiffView(lines: diff)
                          else if (display.call case final String call
                              when call.isNotEmpty)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: AppSpacing.s,
                                    ),
                                    child: Text(
                                      call,
                                      key: ValueKey(
                                        'tool-arguments-${record.id}',
                                      ),
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            fontFamily: 'monospace',
                                            fontWeight: FontWeight.w600,
                                            height: 1.6,
                                          ),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: display.copyLabel,
                                  onPressed: () => _copy(
                                    context,
                                    display.copyText ?? call,
                                    display.copyLabel,
                                  ),
                                  icon: const Icon(
                                    Symbols.content_copy,
                                    size: 18,
                                  ),
                                ),
                              ],
                            ),
                          if (display.output case final String output) ...[
                            if (display.diff == null &&
                                !(display.call?.isNotEmpty ?? false))
                              Align(
                                alignment: Alignment.centerRight,
                                child: IconButton(
                                  tooltip: '复制输出',
                                  onPressed: () =>
                                      _copy(context, output, '复制输出'),
                                  icon: const Icon(
                                    Symbols.content_copy,
                                    size: 18,
                                  ),
                                ),
                              ),
                            if (display.diff != null ||
                                (display.call?.isNotEmpty ?? false))
                              Divider(
                                height: AppSpacing.xl,
                                thickness: 2,
                                radius: AppRadius.fullAll,
                                color: cardForeground.withValues(alpha: 0.2),
                              ),
                            Text(
                              output,
                              key: ValueKey('tool-result-${record.id}'),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                height: 1.5,
                                color: record.status == ToolCallStatus.failed
                                    ? colors.error
                                    : colors.onSurface,
                              ),
                            ),
                          ],
                          if (display.showScreenshots) ...[
                            for (final (:artifact, label: _) in artifacts)
                              if (artifact.isImage)
                                ToolScreenshotPreview(
                                  key: ValueKey('tool-artifact-${artifact.id}'),
                                  attachment: artifact,
                                  onOpen: widget.onOpenArtifact == null
                                      ? null
                                      : () => widget.onOpenArtifact!(artifact),
                                ),
                            if (record.artifacts.isNotEmpty &&
                                !artifacts.any(
                                  (entry) => entry.artifact.isImage,
                                ))
                              const Text('截图附件暂不可用'),
                          ],
                          if (artifacts.any(
                            (entry) =>
                                !display.showScreenshots ||
                                !entry.artifact.isImage,
                          )) ...[
                            const SizedBox(height: AppSpacing.xs),
                            Wrap(
                              spacing: AppSpacing.s,
                              runSpacing: AppSpacing.xs,
                              children: [
                                for (final (:artifact, :label) in artifacts)
                                  if (!display.showScreenshots ||
                                      !artifact.isImage)
                                    FilledButton.tonalIcon(
                                      key: ValueKey(
                                        'tool-artifact-${artifact.id}',
                                      ),
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
                                        label,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      onPressed: widget.onOpenArtifact == null
                                          ? null
                                          : () => widget.onOpenArtifact!(
                                              artifact,
                                            ),
                                    ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolCardContent extends StatelessWidget {
  const _ToolCardContent({
    required this.children,
    required this.scrollKey,
    required this.controller,
    required this.onScroll,
    required this.onMetricsChanged,
  });

  final List<Widget> children;
  final PageStorageKey<String> scrollKey;
  final ScrollController controller;
  final bool Function(ScrollNotification) onScroll;
  final VoidCallback onMetricsChanged;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxHeight: 320),
    child: Scrollbar(
      controller: controller,
      thumbVisibility: true,
      child: NotificationListener<ScrollMetricsNotification>(
        onNotification: (notification) {
          if (notification.depth == 0) onMetricsChanged();
          return false;
        },
        child: NotificationListener<ScrollNotification>(
          onNotification: onScroll,
          child: SingleChildScrollView(
            key: scrollKey,
            controller: controller,
            primary: false,
            child: SelectionArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _copy(BuildContext context, String text, String label) async {
  String feedback;
  try {
    await Clipboard.setData(ClipboardData(text: text));
    feedback = '已$label';
  } on PlatformException {
    feedback = '复制失败，请重试';
  }
  if (!context.mounted) return;
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(buildAppSnackBar(content: Text(feedback)));
}
