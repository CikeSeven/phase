import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_control_style.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_icon_badge.dart';
import '../../../core/widgets/app_interactive_surface.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../../core/widgets/app_menu_anchor.dart';
import '../../../data/models/tool_call_record.dart';
import 'command_api.g.dart';
import 'command_channel_driver.dart';

enum CommandChannelAction { open, authorize, initialize, copySetup, retry }

/// 两张卡片共用菜单入口，派发前用当前状态核对菜单中的可用动作。
List<CommandChannelAction> commandChannelActions(
  ExecutionChannel channel,
  String? state,
) => switch (state) {
  'notInstalled' || 'notRunning' => const [CommandChannelAction.open],
  'permissionRequired' => [
    CommandChannelAction.authorize,
    CommandChannelAction.open,
    if (channel == ExecutionChannel.termux) CommandChannelAction.copySetup,
  ],
  'initializationRequired' => [
    CommandChannelAction.initialize,
    CommandChannelAction.open,
    if (channel == ExecutionChannel.termux) CommandChannelAction.copySetup,
  ],
  'ready' => [
    CommandChannelAction.open,
    CommandChannelAction.initialize,
    if (channel == ExecutionChannel.termux) CommandChannelAction.copySetup,
  ],
  'unsupported' => const [],
  _ => const [CommandChannelAction.retry],
};

class CommandChannelCard extends StatefulWidget {
  const CommandChannelCard({
    required this.channel,
    required this.enabled,
    required this.locked,
    required this.loading,
    required this.status,
    required this.onEnabled,
    required this.onAction,
    super.key,
  });

  final ExecutionChannel channel;
  final bool enabled;
  final bool locked;
  final bool loading;
  final CommandChannelStatus? status;
  final ValueChanged<bool>? onEnabled;
  final ValueChanged<CommandChannelAction> onAction;

  @override
  State<CommandChannelCard> createState() => _CommandChannelCardState();
}

class _CommandChannelCardState extends State<CommandChannelCard> {
  final _menu = MenuController();
  final _menuFocus = FocusNode();
  LocalHistoryEntry? _history;

  bool get _termux => widget.channel == ExecutionChannel.termux;
  String get _name => _termux ? 'Termux' : 'Shizuku';

  String _actionLabel(CommandChannelAction action) => switch (action) {
    CommandChannelAction.open =>
      widget.status?.state == 'notInstalled' ? '下载' : '打开应用',
    CommandChannelAction.authorize => '授权',
    CommandChannelAction.initialize =>
      !_termux
          ? '连接'
          : widget.status?.state == 'ready'
          ? '重新初始化'
          : '初始化',
    CommandChannelAction.copySetup => '复制外部调用设置',
    CommandChannelAction.retry => '重试',
  };

  IconData _actionIcon(CommandChannelAction action) => switch (action) {
    CommandChannelAction.open =>
      widget.status?.state == 'notInstalled'
          ? Symbols.download
          : Symbols.open_in_new,
    CommandChannelAction.authorize => Symbols.key,
    CommandChannelAction.initialize => _termux ? Symbols.build : Symbols.link,
    CommandChannelAction.copySetup => Symbols.content_copy,
    CommandChannelAction.retry => Symbols.refresh,
  };

  void _menuOpened() {
    final route = ModalRoute.of(context);
    if (route == null || _history != null) return;
    late final LocalHistoryEntry entry;
    entry = LocalHistoryEntry(
      impliesAppBarDismissal: false,
      onRemove: () {
        if (_history == entry) {
          _history = null;
          _menu.close();
        }
      },
    );
    _history = entry;
    route.addLocalHistoryEntry(entry);
  }

  void _menuClosed() {
    final entry = _history;
    _history = null;
    entry?.remove();
  }

  @override
  void didUpdateWidget(CommandChannelCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.locked || oldWidget.status?.state != widget.status?.state) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _menu.close();
        _menuClosed();
      });
    }
  }

  @override
  void dispose() {
    _menuClosed();
    _menuFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final actions = commandChannelActions(widget.channel, widget.status?.state);
    final canOpen = !widget.locked && actions.isNotEmpty;

    return AppMenuAnchor(
      controller: _menu,
      childFocusNode: _menuFocus,
      onOpen: _menuOpened,
      onClose: _menuClosed,
      alignmentOffset: const Offset(0, AppSpacing.xs),
      style: const MenuStyle(
        minimumSize: WidgetStatePropertyAll(Size(200, 0)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: AppRadius.largeAll),
        ),
      ),
      menuChildren: [
        for (final action in actions)
          AppMenuItemButton(
            leadingIcon: Icon(_actionIcon(action), size: 20),
            onPressed: widget.locked ? null : () => widget.onAction(action),
            child: Text(_actionLabel(action)),
          ),
      ],
      builder: (context, controller, _) => Semantics(
        expanded: controller.isOpen,
        hint: canOpen ? '打开$_name操作' : null,
        child: AppInteractiveSurface(
          focusNode: _menuFocus,
          color: colors.surfaceContainer,
          onTap: canOpen
              ? () => controller.isOpen ? controller.close() : controller.open()
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.l,
              vertical: AppSpacing.m,
            ),
            child: _content(context, hasActions: actions.isNotEmpty),
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, {required bool hasActions}) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final titleStyle = theme.textTheme.titleMedium!;
    final painter = TextPainter(
      text: TextSpan(text: _name, style: titleStyle),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final minWidth =
        40 +
        AppSpacing.m +
        painter.width +
        AppSpacing.s +
        24 +
        (_termux ? 0 : 60 + AppSpacing.s);
    painter.dispose();

    final toggle = _termux ? null : _shizukuSwitch(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = toggle != null && constraints.maxWidth < minWidth;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AppControlStyle.touchTarget,
              ),
              child: Row(
                children: [
                  AppIconBadge(
                    icon: _termux
                        ? Symbols.terminal
                        : Symbols.admin_panel_settings,
                    size: 40,
                    iconSize: 22,
                  ),
                  const SizedBox(width: AppSpacing.m),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_name, style: titleStyle),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          widget.status?.message ?? '状态不可用',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s),
                  if (toggle != null && !stacked) ...[
                    toggle,
                    const SizedBox(width: AppSpacing.s),
                  ],
                  AppDelayedLoadingIndicator(
                    loading: widget.loading,
                    semanticsLabel: '正在配置 $_name',
                    placeholder: hasActions
                        ? ExcludeSemantics(
                            child: Icon(
                              Symbols.chevron_right,
                              size: 20,
                              color: colors.onSurfaceVariant,
                            ),
                          )
                        : null,
                  ),
                ],
              ),
            ),
            if (stacked)
              Align(alignment: AlignmentDirectional.centerEnd, child: toggle),
          ],
        );
      },
    );
  }

  Widget _shizukuSwitch(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final canToggle =
        widget.enabled || hasShizukuCommandPermission([?widget.status]);
    return SizedBox(
      width: 60,
      child: GestureDetector(
        // 禁用开关的触区不应退回到卡片的菜单操作。
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: !canToggle ? () {} : null,
        child: Semantics(
          container: true,
          label: '启用 Shizuku 命令与文件传输',
          child: Switch(
            value: widget.enabled,
            // 临时操作锁保持外观稳定；真正未授权时弱化并禁止开启。
            thumbColor: WidgetStateProperty.resolveWith(
              (states) => !canToggle
                  ? colors.onSurface.withValues(alpha: 0.38)
                  : states.contains(WidgetState.selected)
                  ? colors.onPrimary
                  : colors.outline,
            ),
            trackColor: WidgetStateProperty.resolveWith(
              (states) => !canToggle
                  ? colors.onSurface.withValues(alpha: 0.12)
                  : states.contains(WidgetState.selected)
                  ? colors.primary
                  : colors.surfaceContainerHighest,
            ),
            trackOutlineColor: WidgetStateProperty.resolveWith(
              (states) => !canToggle
                  ? colors.onSurface.withValues(alpha: 0.12)
                  : states.contains(WidgetState.selected)
                  ? Colors.transparent
                  : colors.outline,
            ),
            onChanged: widget.locked || !canToggle ? null : widget.onEnabled,
          ),
        ),
      ),
    );
  }
}
