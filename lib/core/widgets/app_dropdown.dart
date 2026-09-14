import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/app_control_style.dart';
import '../theme/app_motion.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

class AppDropdown<T extends Enum> extends StatefulWidget {
  const AppDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    super.key,
  });

  final String label;
  final T value;
  final Map<T, String> options;
  final ValueChanged<T>? onChanged;

  @override
  State<AppDropdown<T>> createState() => _AppDropdownState<T>();
}

class _AppDropdownState<T extends Enum> extends State<AppDropdown<T>> {
  final _menu = MenuController();
  final _focus = FocusNode();
  LocalHistoryEntry? _history;
  AnimationStatus _animationStatus = AnimationStatus.dismissed;
  bool get _enabled => widget.onChanged != null;

  void _toggle() {
    if (!_enabled) return;
    _animationStatus.isForwardOrCompleted ? _menu.close() : _menu.open();
  }

  @override
  void didUpdateWidget(AppDropdown<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_enabled && _menu.isOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_enabled) _menu.close();
      });
    }
  }

  void _opened() {
    final route = ModalRoute.of(context);
    if (route == null) return;
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

  @override
  void dispose() {
    _closed();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final reduced = AppMotion.reduce(context);
    return LayoutBuilder(
      builder: (context, constraints) => MenuAnchor(
        controller: _menu,
        childFocusNode: _focus,
        animated: !reduced,
        onAnimationStatusChanged: (status) => _animationStatus = status,
        consumeOutsideTap: true,
        crossAxisUnconstrained: false,
        onOpen: _opened,
        onClose: _closed,
        alignmentOffset: const Offset(0, AppSpacing.xs),
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(colors.surfaceContainer),
          minimumSize: WidgetStatePropertyAll(Size(constraints.maxWidth, 0)),
          maximumSize: WidgetStatePropertyAll(
            Size(constraints.maxWidth, double.infinity),
          ),
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: AppRadius.largeAll),
          ),
        ),
        menuChildren: [
          for (final entry in widget.options.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: MenuItemButton(
                onPressed: !_enabled
                    ? null
                    : () {
                        if (mounted) widget.onChanged?.call(entry.key);
                      },
                style: ButtonStyle(
                  minimumSize: const WidgetStatePropertyAll(
                    Size(
                      AppControlStyle.touchTarget,
                      AppControlStyle.mediumHeight,
                    ),
                  ),
                  padding: const WidgetStatePropertyAll(
                    EdgeInsets.symmetric(
                      horizontal: AppSpacing.l,
                      vertical: AppSpacing.m,
                    ),
                  ),
                  shape: WidgetStateProperty.resolveWith(
                    (states) => RoundedRectangleBorder(
                      borderRadius:
                          !states.contains(WidgetState.disabled) &&
                              states.contains(WidgetState.pressed)
                          ? AppRadius.smallAll
                          : entry.key == widget.value
                          ? AppRadius.largeAll
                          : AppRadius.mediumAll,
                    ),
                  ),
                  backgroundColor: WidgetStatePropertyAll(
                    entry.key == widget.value
                        ? colors.primaryContainer
                        : colors.surfaceContainer,
                  ),
                  foregroundColor: WidgetStatePropertyAll(
                    entry.key == widget.value
                        ? colors.onPrimaryContainer
                        : colors.onSurface,
                  ),
                  iconColor: WidgetStatePropertyAll(colors.onPrimaryContainer),
                  textStyle: WidgetStatePropertyAll(theme.textTheme.bodyLarge),
                  animationDuration: reduced
                      ? Duration.zero
                      : AppMotion.effects,
                ),
                trailingIcon: SizedBox.square(
                  dimension: 24,
                  child: entry.key == widget.value
                      ? const ExcludeSemantics(
                          child: Icon(Symbols.check_circle, fill: 1),
                        )
                      : null,
                ),
                child: Semantics(
                  selected: entry.key == widget.value,
                  child: Text(entry.value),
                ),
              ),
            ),
        ],
        builder: (context, controller, _) => Semantics(
          button: true,
          enabled: _enabled,
          expanded: controller.isOpen,
          label: widget.label,
          value: widget.options[widget.value],
          child: Material(
            color: colors.surface.withValues(alpha: 0),
            borderRadius: AppRadius.mediumAll,
            child: InkWell(
              focusNode: _focus,
              canRequestFocus: _enabled,
              borderRadius: AppRadius.mediumAll,
              onFocusChange: (_) {
                if (mounted) setState(() {});
              },
              onTap: _enabled ? _toggle : null,
              child: ExcludeSemantics(
                child: InputDecorator(
                  isFocused: controller.isOpen || _focus.hasFocus,
                  decoration: InputDecoration(
                    enabled: _enabled,
                    labelText: widget.label,
                    suffixIcon: Icon(
                      controller.isOpen
                          ? Symbols.keyboard_arrow_up
                          : Symbols.keyboard_arrow_down,
                    ),
                  ),
                  child: Text(
                    widget.options[widget.value]!,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: _enabled
                          ? colors.onSurface
                          : colors.onSurface.withValues(alpha: 0.38),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
