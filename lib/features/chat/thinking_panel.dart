import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../core/theme/frosted_surface.dart';

/// 思考双通道的可折叠阅读区，手动选择优先于流式默认状态。
class ThinkingPanel extends StatefulWidget {
  const ThinkingPanel({
    required this.reasoning,
    required this.streaming,
    super.key,
  });

  final String reasoning;
  final bool streaming;

  @override
  State<ThinkingPanel> createState() => _ThinkingPanelState();
}

class _ThinkingPanelState extends State<ThinkingPanel>
    with AutomaticKeepAliveClientMixin {
  late bool _expanded = widget.streaming;
  bool _userToggled = false;

  @override
  bool get wantKeepAlive => _userToggled;

  @override
  void didUpdateWidget(covariant ThinkingPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_userToggled && oldWidget.streaming != widget.streaming) {
      _expanded = widget.streaming;
    }
  }

  void _toggle() {
    setState(() {
      _expanded = !_expanded;
      _userToggled = true;
    });
    updateKeepAlive();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final brand = context.brandColors;
    return FrostedSurface(
      blur: 0,
      borderRadius: AppRadius.mediumAll,
      color: brand.lavenderContainer.withValues(
        alpha: theme.brightness == Brightness.dark ? 0.60 : 0.64,
      ),
      borderColor: brand.lavender.withValues(alpha: 0.24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: _expanded,
            child: InkWell(
              borderRadius: AppRadius.mediumAll,
              onTap: _toggle,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.m),
                  child: Row(
                    children: [
                      Icon(
                        Symbols.psychology,
                        size: 20,
                        color: brand.onLavenderContainer,
                      ),
                      const SizedBox(width: AppSpacing.s),
                      Expanded(
                        child: Text(
                          widget.streaming ? '思考中…' : '已思考',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: brand.onLavenderContainer,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s),
                      Icon(
                        _expanded ? Symbols.expand_less : Symbols.expand_more,
                        size: 20,
                        color: brand.onLavenderContainer,
                      ),
                    ],
                  ),
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
                AppSpacing.m,
              ),
              child: Text(
                widget.reasoning,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: brand.onLavenderContainer,
                  height: 1.5,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
