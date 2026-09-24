import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/error/failure.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_menu_anchor.dart';
import '../../../data/models/permission_mode.dart';
import 'chat_controller.dart';

/// 输入栏的小型权限选择菜单；返回仅关闭当前菜单，不离开会话。
class PermissionModeMenu extends ConsumerStatefulWidget {
  const PermissionModeMenu({super.key, required this.submitting});

  final bool submitting;

  @override
  ConsumerState<PermissionModeMenu> createState() => _PermissionModeMenuState();
}

class _PermissionModeMenuState extends ConsumerState<PermissionModeMenu> {
  final _menu = MenuController();
  final _focus = FocusNode();
  LocalHistoryEntry? _history;
  AnimationStatus _animation = AnimationStatus.dismissed;

  void _opened() {
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

  void _closed() {
    final entry = _history;
    _history = null;
    entry?.remove();
  }

  void _closeAfterBuild() {
    if (!_menu.isOpen) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _menu.close();
    });
  }

  @override
  void dispose() {
    _closed();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _select(PermissionMode mode, String? conversationId) async {
    final state = ref.read(chatControllerProvider);
    if (widget.submitting ||
        state.isGenerating ||
        state.savingPermissionMode ||
        ref.read(activeConversationProvider).conversationId != conversationId) {
      return;
    }
    try {
      await ref.read(chatControllerProvider.notifier).setPermissionMode(mode);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error is Failure ? error.userMessage : '保存权限模式失败，请重试'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final permissions = ref.watch(conversationPermissionsProvider);
    final state = ref.watch(
      chatControllerProvider.select(
        (s) => (s.isGenerating, s.savingPermissionMode),
      ),
    );
    final active = ref.watch(activeConversationProvider);
    ref.listen(activeConversationProvider, (_, _) => _closeAfterBuild());
    final enabled =
        !widget.submitting &&
        !state.$1 &&
        !state.$2 &&
        !permissions.isLoading &&
        !permissions.hasError;
    if (!enabled) _closeAfterBuild();
    final mode = permissions.value?.mode;
    final colors = Theme.of(context).colorScheme;
    final reduced = AppMotion.reduce(context);
    final media = MediaQuery.of(context);
    final width = math.min(304.0 * 2 / 3, media.size.width - AppSpacing.xl);
    final label = permissions.hasError ? '重试权限模式' : mode?.label ?? '读取权限模式…';
    return AppMenuAnchor(
      controller: _menu,
      childFocusNode: _focus,
      onAnimationStatusChanged: (value) => _animation = value,
      onOpen: _opened,
      onClose: _closed,
      alignmentOffset: Offset(-width / 2, AppSpacing.xs),
      style: MenuStyle(
        alignment: AlignmentDirectional.bottomCenter,
        backgroundColor: WidgetStatePropertyAll(colors.surfaceContainer),
        minimumSize: WidgetStatePropertyAll(Size(width, 0)),
        maximumSize: WidgetStatePropertyAll(
          Size(
            width,
            math.max(
              48,
              media.size.height -
                  media.viewInsets.bottom -
                  media.padding.vertical -
                  AppSpacing.xl,
            ),
          ),
        ),
        shape: const WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: AppRadius.mediumAll),
        ),
      ),
      menuChildren: [
        for (final option in PermissionMode.values)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: AppMenuItemButton(
              key: ValueKey('permission-mode-${option.name}'),
              onPressed: enabled
                  ? () => _select(option, active.conversationId)
                  : null,
              style: ButtonStyle(
                minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
                padding: const WidgetStatePropertyAll(
                  EdgeInsets.symmetric(
                    horizontal: AppSpacing.m,
                    vertical: AppSpacing.s,
                  ),
                ),
                backgroundColor: WidgetStatePropertyAll(
                  option == mode
                      ? colors.primaryContainer
                      : colors.surfaceContainer,
                ),
                foregroundColor: WidgetStatePropertyAll(
                  option == mode ? colors.onPrimaryContainer : colors.onSurface,
                ),
                shape: WidgetStateProperty.resolveWith(
                  (states) => RoundedRectangleBorder(
                    borderRadius: states.contains(WidgetState.pressed)
                        ? AppRadius.extraSmallAll
                        : option == mode
                        ? AppRadius.controlAll
                        : AppRadius.smallAll,
                  ),
                ),
                animationDuration: reduced ? Duration.zero : AppMotion.effects,
              ),
              trailingIcon: SizedBox.square(
                dimension: 20,
                child: option == mode
                    ? const ExcludeSemantics(
                        child: Icon(Symbols.check_circle, fill: 1, size: 20),
                      )
                    : null,
              ),
              child: Semantics(
                selected: option == mode,
                child: SizedBox(
                  width: math.max(48, width - 76),
                  child: Text(option.label),
                ),
              ),
            ),
          ),
      ],
      builder: (context, controller, _) => LayoutBuilder(
        builder: (context, constraints) => Semantics(
          label: '权限模式',
          value: label,
          expanded: controller.isOpen,
          child: TextButton(
            key: const ValueKey('chat-agent-mode'),
            focusNode: _focus,
            onPressed: enabled
                ? () => _animation.isForwardOrCompleted
                      ? _menu.close()
                      : _menu.open()
                : permissions.hasError &&
                      !state.$1 &&
                      !state.$2 &&
                      !widget.submitting
                ? () {
                    final id = active.conversationId;
                    if (id != null) {
                      ref.invalidate(conversationThreadProvider(id));
                    }
                  }
                : null,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (MediaQuery.textScalerOf(context).scale(14) * label.length +
                        64 <=
                    constraints.maxWidth) ...[
                  const Icon(Symbols.keyboard_arrow_up, size: 18),
                  const SizedBox(width: AppSpacing.s),
                ],
                Flexible(
                  child: Text(label, maxLines: 2, textAlign: TextAlign.center),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
