import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_control_style.dart';
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
import '../../../data/models/tool_source.dart';
import '../chat/chat_code_highlighter.dart';
import 'tool_call_display.dart';
import 'tool_diff.dart';
import 'tool_diff_view.dart';
import 'tool_presentation.dart';
import 'tool_screenshot_preview.dart';
import '../web_search/web_tool_result_view.dart';

/// 包装带高亮 TextSpan 的 Text 组件，同时保留 Text.data 满足测试与无障碍访问。
class HighlightedCodeText extends Text {
  const HighlightedCodeText(
    super.data, {
    required this.highlightSpan,
    super.key,
    super.style,
  });

  final InlineSpan highlightSpan;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: highlightSpan,
      textScaler: MediaQuery.textScalerOf(context),
      selectionRegistrar: SelectionContainer.maybeOf(context),
      selectionColor: DefaultSelectionStyle.of(context).selectionColor,
    );
  }
}

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
  final _inputController = ScrollController();
  final _outputController = ScrollController();
  bool _expanded = false;
  bool _userToggled = false;
  bool _followInput = true;
  bool _followOutput = true;
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
    } else if (_expanded &&
        ToolPresentation.isInFlight(widget.record.status) &&
        oldWidget.record.result != widget.record.result) {
      _scheduleScrollToEnd();
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
    if (_expanded && ToolPresentation.isInFlight(widget.record.status)) {
      _followInput = true;
      _followOutput = true;
      _scheduleScrollToEnd();
    }
  }

  void _scheduleScrollToEnd() {
    if (!mounted || !_expanded || _scrollToEndScheduled) {
      return;
    }
    _scrollToEndScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToEndScheduled = false;
      if (!mounted || !_expanded) return;

      if (_followInput && _inputController.hasClients) {
        final pos = _inputController.position;
        if ((pos.maxScrollExtent - pos.pixels).abs() > 0.5) {
          pos.jumpTo(pos.maxScrollExtent);
        }
      }
      if (_followOutput && _outputController.hasClients) {
        final pos = _outputController.position;
        if ((pos.maxScrollExtent - pos.pixels).abs() > 0.5) {
          pos.jumpTo(pos.maxScrollExtent);
        }
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _outputController.dispose();
    super.dispose();
  }

  bool _onInputScroll(ScrollNotification notification) =>
      _handleOverscroll(notification, (follow) => _followInput = follow);

  bool _onOutputScroll(ScrollNotification notification) =>
      _handleOverscroll(notification, (follow) => _followOutput = follow);

  bool _handleOverscroll(
    ScrollNotification notification,
    void Function(bool) setFollow,
  ) {
    if (notification.depth != 0) return false;
    if (notification is UserScrollNotification &&
        notification.direction != ScrollDirection.idle) {
      setFollow(false);
    } else if (notification is ScrollEndNotification) {
      setFollow(notification.metrics.extentAfter <= 1);
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

  static String? _extractRecordPath(ToolCallRecord record) {
    if (record.target case final String target when target.isNotEmpty) {
      return target;
    }
    for (final key in const [
      'path',
      'filePath',
      'file_path',
      'target',
      'uri',
      'file',
      'filename',
      'relativePath',
      'destination',
      'source',
    ]) {
      if (record.arguments[key] case final String path when path.isNotEmpty) {
        return path;
      }
    }
    return null;
  }

  static String _detectCallLanguage(ToolCallRecord record, String call) {
    if (record.toolName == 'shell') return 'bash';
    final trimmed = call.trim();
    if ((trimmed.startsWith('{') && trimmed.endsWith('}')) ||
        (trimmed.startsWith('[') && trimmed.endsWith(']'))) {
      return 'json';
    }
    if (trimmed.startsWith(r'$ ')) return 'bash';
    if (_extractRecordPath(record) case final String path) {
      return _detectLanguageFromPath(path);
    }
    if (record.source?.kind == ToolSourceKind.mcp) return 'json';
    return 'bash';
  }

  static String? _detectOutputLanguage(ToolCallRecord record, String output) {
    final trimmed = output.trim();
    if ((trimmed.startsWith('{') && trimmed.endsWith('}')) ||
        (trimmed.startsWith('[') && trimmed.endsWith(']'))) {
      return 'json';
    }
    if (_extractRecordPath(record) case final String path) {
      return _detectLanguageFromPath(path);
    }
    return null;
  }

  static String _detectLanguageFromPath(String path) {
    final cleanPath = path.split('?').first.split('#').first;
    final filename = cleanPath.split('/').last.toLowerCase();
    if (filename == 'dockerfile') return 'dockerfile';
    if (filename == 'makefile') return 'makefile';
    if (filename == 'cmakelists.txt') return 'makefile';
    if (filename == '.gitignore' ||
        filename == '.env' ||
        filename == '.bashrc' ||
        filename == '.zshrc') {
      return 'bash';
    }

    final dot = cleanPath.lastIndexOf('.');
    if (dot != -1 && dot < cleanPath.length - 1) {
      final ext = cleanPath.substring(dot + 1).toLowerCase();
      return switch (ext) {
        'py' || 'pyw' => 'python',
        'dart' => 'dart',
        'js' || 'mjs' || 'cjs' || 'jsx' => 'javascript',
        'ts' || 'mts' || 'cts' || 'tsx' => 'typescript',
        'json' || 'jsonc' || 'json5' => 'json',
        'yaml' || 'yml' || 'lock' => 'yaml',
        'sh' || 'bash' || 'zsh' || 'env' => 'bash',
        'rs' => 'rust',
        'go' || 'mod' => 'go',
        'c' || 'h' => 'c',
        'cpp' || 'cc' || 'cxx' || 'hpp' => 'cpp',
        'cs' => 'csharp',
        'java' || 'gradle' => 'java',
        'kt' || 'kts' => 'kotlin',
        'swift' => 'swift',
        'sql' => 'sql',
        'html' || 'htm' || 'xml' || 'svg' || 'plist' => 'xml',
        'md' || 'markdown' => 'markdown',
        'css' => 'css',
        'scss' || 'sass' => 'scss',
        'ini' || 'conf' || 'properties' || 'toml' => 'ini',
        'diff' || 'patch' => 'diff',
        _ => ext,
      };
    }
    return 'shell';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final record = widget.record;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final brand = context.brandColors;
    final isDark = theme.brightness == Brightness.dark;

    final failed = record.status == ToolCallStatus.failed;
    final succeeded = record.status == ToolCallStatus.succeeded;
    final inFlight = ToolPresentation.isInFlight(record.status);

    // 月色玻璃表面色彩层级
    final baseSurface = isDark
        ? colors.surfaceContainerLow
        : colors.surfaceContainerLowest;

    final Color cardBackground;
    final Color cardBorderColor;
    final Color badgeAccent;

    if (failed) {
      cardBackground = isDark
          ? Color.alphaBlend(
              colors.errorContainer.withValues(alpha: 0.16),
              baseSurface,
            )
          : Color.alphaBlend(
              colors.errorContainer.withValues(alpha: 0.26),
              baseSurface,
            );
      cardBorderColor = colors.error.withValues(alpha: isDark ? 0.35 : 0.40);
      badgeAccent = colors.error;
    } else if (inFlight) {
      cardBackground = isDark
          ? Color.alphaBlend(
              colors.primaryContainer.withValues(alpha: 0.14),
              baseSurface,
            )
          : Color.alphaBlend(
              colors.primaryContainer.withValues(alpha: 0.20),
              baseSurface,
            );
      cardBorderColor = colors.primary.withValues(alpha: isDark ? 0.30 : 0.35);
      badgeAccent = colors.primary;
    } else if (succeeded) {
      cardBackground = isDark
          ? Color.alphaBlend(
              brand.tealContainer.withValues(alpha: 0.14),
              baseSurface,
            )
          : Color.alphaBlend(
              brand.tealContainer.withValues(alpha: 0.24),
              baseSurface,
            );
      cardBorderColor = brand.teal.withValues(alpha: isDark ? 0.25 : 0.32);
      badgeAccent = brand.teal;
    } else {
      cardBackground = baseSurface;
      cardBorderColor = colors.outlineVariant.withValues(
        alpha: isDark ? 0.25 : 0.35,
      );
      badgeAccent = colors.onSurfaceVariant;
    }

    final statusColor = switch (record.status) {
      ToolCallStatus.rejected ||
      ToolCallStatus.cancelled => colors.onSurfaceVariant,
      _ => ToolPresentation.statusColor(context, record.status),
    };

    if (_expanded && !identical(record, _displayRecord)) {
      _display = ToolCallDisplay.fromRecord(record);
      _displayRecord = record;
    }
    final display = _display;
    final detail = ToolCallDisplay.detail(record, appName: widget.appName);
    final command = (record.toolName == 'shell');

    final artifacts = [
      for (final artifact in widget.artifacts)
        if (ToolCallDisplay.artifactLabel(record, artifact)
            case final String label)
          (artifact: artifact, label: label),
    ];

    // 精致的状态药丸徽标
    final statusPill = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: isDark ? 0.14 : 0.08),
        borderRadius: AppRadius.fullAll,
        border: Border.all(
          color: statusColor.withValues(alpha: isDark ? 0.25 : 0.18),
          width: 1,
        ),
      ),
      child: Row(
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
              size: 14,
              color: statusColor,
            ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            ToolPresentation.statusLabel(record.status),
            key: ValueKey('tool-status-${record.id}'),
            style: theme.textTheme.labelSmall?.copyWith(
              color: statusColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    final hasDiff = display?.diff != null;
    final hasCall = display?.call != null && display!.call!.isNotEmpty;
    final hasInput = hasDiff || hasCall;
    final hasOutput = display?.output != null;

    return Padding(
      padding: widget.grouped
          ? EdgeInsets.zero
          : const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Material(
        key: ValueKey('tool-card-${record.id}'),
        color: cardBackground,
        shape: widget.grouped
            ? null
            : RoundedRectangleBorder(
                borderRadius: AppRadius.mediumAll,
                side: BorderSide(color: cardBorderColor, width: 1),
              ),
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
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.m,
                      vertical: AppSpacing.s,
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final stacked =
                            constraints.maxWidth <
                            MediaQuery.textScalerOf(context).scale(14) * 18;

                        final titleColumn = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ToolCallDisplay.title(record),
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: colors.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (detail != null && (!command || !_expanded))
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  detail,
                                  key: ValueKey('tool-detail-${record.id}'),
                                  maxLines: _expanded && !command ? null : 2,
                                  overflow: _expanded && !command
                                      ? null
                                      : TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colors.onSurfaceVariant,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                          ],
                        );

                        return Row(
                          children: [
                            // 工具图标徽章容器
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: badgeAccent.withValues(
                                  alpha: isDark ? 0.14 : 0.09,
                                ),
                                borderRadius: AppRadius.smallAll,
                                border: Border.all(
                                  color: badgeAccent.withValues(
                                    alpha: isDark ? 0.25 : 0.18,
                                  ),
                                  width: 1,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                ToolPresentation.icon(record.toolName),
                                size: 18,
                                color: badgeAccent,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.m),
                            Expanded(
                              child: stacked
                                  ? Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        titleColumn,
                                        const SizedBox(height: AppSpacing.xs),
                                        statusPill,
                                      ],
                                    )
                                  : titleColumn,
                            ),
                            if (!stacked) ...[
                              const SizedBox(width: AppSpacing.s),
                              statusPill,
                            ],
                            const SizedBox(width: AppSpacing.s),
                            AppExpansionArrow(
                              expanded: _expanded,
                              color: colors.onSurfaceVariant,
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            AppExpansionBody(
              key: ValueKey('tool-expansion-${record.id}'),
              expanded: _expanded,
              builder: (context) {
                if (display == null) return const SizedBox.shrink();

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: colors.outlineVariant.withValues(
                        alpha: isDark ? 0.20 : 0.35,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.m),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 严重存储错误说明横幅
                          if (record.errorCode == 'storageError' &&
                              display.output !=
                                  ToolPresentation.storageFailureMessage) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.m,
                                vertical: AppSpacing.s,
                              ),
                              decoration: BoxDecoration(
                                color: colors.errorContainer.withValues(
                                  alpha: isDark ? 0.25 : 0.45,
                                ),
                                borderRadius: AppRadius.extraSmallAll,
                                border: Border.all(
                                  color: colors.error.withValues(
                                    alpha: isDark ? 0.3 : 0.4,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    LucideIcons.circleAlert,
                                    size: 16,
                                    color: colors.error,
                                  ),
                                  const SizedBox(width: AppSpacing.s),
                                  Expanded(
                                    child: Text(
                                      ToolPresentation.storageFailureMessage,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: colors.error,
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: AppSpacing.m),
                          ],

                          // 元数据标签信息
                          if (display.metadata case final String metadata
                              when metadata.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.s,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    LucideIcons.info,
                                    size: 14,
                                    color: colors.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                  Expanded(
                                    child: Text(
                                      metadata,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: colors.onSurfaceVariant,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // 输入/调用视窗（Diff、命令、调用参数，无多重嵌套卡片）
                          if (hasInput) ...[
                            // 顶部轻量操作栏
                            Row(
                              children: [
                                if (hasDiff)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colors.surfaceContainerHighest
                                          .withValues(
                                            alpha: isDark ? 0.35 : 0.6,
                                          ),
                                      borderRadius: AppRadius.extraSmallAll,
                                    ),
                                    child: Text(
                                      '+${display.diff!.where((l) => l.kind == ToolDiffKind.added).length} '
                                      '−${display.diff!.where((l) => l.kind == ToolDiffKind.removed).length}',
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: colors.onSurfaceVariant,
                                          ),
                                    ),
                                  )
                                else
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        command
                                            ? LucideIcons.terminal
                                            : LucideIcons.code,
                                        size: 14,
                                        color: colors.onSurfaceVariant,
                                      ),
                                      const SizedBox(width: AppSpacing.xs),
                                      Text(
                                        command ? '终端命令' : '调用参数',
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                              color: colors.onSurfaceVariant,
                                              fontWeight: FontWeight.w500,
                                            ),
                                      ),
                                    ],
                                  ),
                                const Spacer(),
                                IconButton(
                                  tooltip: display.copyLabel,
                                  constraints: const BoxConstraints(
                                    minWidth: 48,
                                    minHeight: 48,
                                  ),
                                  onPressed: () => _copy(
                                    context,
                                    display.copyText ?? display.call ?? '',
                                    display.copyLabel,
                                  ),
                                  icon: const Icon(LucideIcons.copy, size: 18),
                                ),
                              ],
                            ),

                            // 内容区（支持完整语法高亮，充分利用手机屏幕宽度）
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 240),
                              child: Scrollbar(
                                controller: _inputController,
                                thumbVisibility: true,
                                child: NotificationListener<ScrollNotification>(
                                  onNotification: _onInputScroll,
                                  child: SingleChildScrollView(
                                    key: PageStorageKey(
                                      'tool-input-${record.id}',
                                    ),
                                    controller: _inputController,
                                    primary: false,
                                    child: SelectionArea(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: AppSpacing.xs,
                                        ),
                                        child: hasDiff
                                            ? (display.diff!.isEmpty
                                                  ? const Text('（空文件）')
                                                  : ToolDiffView(
                                                      lines: display.diff!,
                                                      language: () {
                                                        if (_extractRecordPath(
                                                              record,
                                                            )
                                                            case final String
                                                                path) {
                                                          return _detectLanguageFromPath(
                                                            path,
                                                          );
                                                        }
                                                        return null;
                                                      }(),
                                                    ))
                                            : () {
                                                final callText =
                                                    display.call ?? '';
                                                final lang =
                                                    _detectCallLanguage(
                                                      record,
                                                      callText,
                                                    );
                                                final parsed =
                                                    ChatCodeHighlighter.parse(
                                                      lang,
                                                      callText,
                                                    );
                                                final baseStyle = theme
                                                    .textTheme
                                                    .bodySmall
                                                    ?.copyWith(
                                                      fontFamily:
                                                          kGptMarkdownMonoFontFamily,
                                                      package:
                                                          kGptMarkdownFontPackage,
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      height: 1.55,
                                                      color: colors.onSurface,
                                                    );
                                                final span =
                                                    ChatCodeHighlighter.render(
                                                      context,
                                                      parsed,
                                                      callText,
                                                      baseStyle!,
                                                    );
                                                return HighlightedCodeText(
                                                  callText,
                                                  highlightSpan: span,
                                                  key: ValueKey(
                                                    'tool-arguments-${record.id}',
                                                  ),
                                                  style: baseStyle,
                                                );
                                              }(),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],

                          // 两个视窗之间的分割线
                          if (hasInput && hasOutput)
                            Divider(
                              height: AppSpacing.l,
                              thickness: 1,
                              color: colors.outlineVariant.withValues(
                                alpha: isDark ? 0.20 : 0.35,
                              ),
                            ),

                          // 输出/结果视窗（无多重嵌套卡片）
                          if (hasOutput) ...[
                            // 输出顶部轻量操作栏
                            if (display.webSearch == null &&
                                display.webFetch == null)
                              Row(
                                children: [
                                  Icon(
                                    record.status == ToolCallStatus.failed
                                        ? LucideIcons.circleAlert
                                        : LucideIcons.cornerDownRight,
                                    size: 14,
                                    color:
                                        record.status == ToolCallStatus.failed
                                        ? colors.error
                                        : colors.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                  Text(
                                    record.status == ToolCallStatus.failed
                                        ? '错误输出'
                                        : (record.toolName == 'read_file'
                                              ? '文件内容'
                                              : '执行结果'),
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color:
                                          record.status == ToolCallStatus.failed
                                          ? colors.error
                                          : colors.onSurfaceVariant,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    tooltip: '复制输出',
                                    constraints: const BoxConstraints(
                                      minWidth: 48,
                                      minHeight: 48,
                                    ),
                                    onPressed: () =>
                                        _copy(context, display.output!, '复制输出'),
                                    icon: const Icon(
                                      LucideIcons.copy,
                                      size: 18,
                                    ),
                                  ),
                                ],
                              ),

                            // 输出内容区（支持语法高亮，去嵌套卡片）
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 240),
                              child: Scrollbar(
                                controller: _outputController,
                                thumbVisibility: true,
                                child: NotificationListener<ScrollNotification>(
                                  onNotification: _onOutputScroll,
                                  child: SingleChildScrollView(
                                    key: PageStorageKey(
                                      'tool-output-${record.id}',
                                    ),
                                    controller: _outputController,
                                    primary: false,
                                    child: SelectionArea(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: AppSpacing.xs,
                                        ),
                                        child:
                                            display.webSearch != null ||
                                                display.webFetch != null
                                            ? WebToolResultView(
                                                search: display.webSearch,
                                                fetch: display.webFetch,
                                              )
                                            : () {
                                                final outText = display.output!;
                                                final lang =
                                                    _detectOutputLanguage(
                                                      record,
                                                      outText,
                                                    );
                                                final parsed =
                                                    ChatCodeHighlighter.parse(
                                                      lang,
                                                      outText,
                                                    );
                                                final baseStyle = theme
                                                    .textTheme
                                                    .bodySmall
                                                    ?.copyWith(
                                                      fontFamily:
                                                          kGptMarkdownMonoFontFamily,
                                                      package:
                                                          kGptMarkdownFontPackage,
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      height: 1.55,
                                                      color:
                                                          record.status ==
                                                              ToolCallStatus
                                                                  .failed
                                                          ? colors.error
                                                          : colors.onSurface,
                                                    );
                                                final span =
                                                    ChatCodeHighlighter.render(
                                                      context,
                                                      parsed,
                                                      outText,
                                                      baseStyle!,
                                                    );
                                                return HighlightedCodeText(
                                                  outText,
                                                  highlightSpan: span,
                                                  key: ValueKey(
                                                    'tool-result-${record.id}',
                                                  ),
                                                  style: baseStyle,
                                                );
                                              }(),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],

                          // 截图附件预览
                          if (display.showScreenshots) ...[
                            for (final (:artifact, label: _) in artifacts)
                              if (artifact.isImage)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: AppSpacing.s,
                                  ),
                                  child: ToolScreenshotPreview(
                                    key: ValueKey(
                                      'tool-artifact-${artifact.id}',
                                    ),
                                    attachment: artifact,
                                    onOpen: widget.onOpenArtifact == null
                                        ? null
                                        : () =>
                                              widget.onOpenArtifact!(artifact),
                                  ),
                                ),
                            if (record.artifacts.isNotEmpty &&
                                !artifacts.any(
                                  (entry) => entry.artifact.isImage,
                                ))
                              const Padding(
                                padding: EdgeInsets.only(top: AppSpacing.s),
                                child: Text('截图附件暂不可用'),
                              ),
                          ],

                          // 文件/非图片附件按钮组
                          if (artifacts.any(
                            (entry) =>
                                !display.showScreenshots ||
                                !entry.artifact.isImage,
                          )) ...[
                            const SizedBox(height: AppSpacing.m),
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
                                            ? LucideIcons.image
                                            : LucideIcons.paperclip,
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
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
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
