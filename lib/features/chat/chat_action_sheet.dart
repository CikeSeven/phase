import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_interactive_surface.dart';

class ChatSheetAction<T> {
  const ChatSheetAction({
    required this.value,
    required this.label,
    required this.icon,
    this.key,
    this.description,
    this.enabled = true,
  });

  final T value;
  final String label;
  final IconData icon;
  final Key? key;
  final String? description;
  final bool enabled;
}

/// 消息操作与导出格式共用的紧凑面板；短窗口整体滚动，选择只返回一次。
class ChatActionSheet<T> extends StatefulWidget {
  const ChatActionSheet({
    required this.title,
    required this.actions,
    super.key,
  });

  final String title;
  final List<ChatSheetAction<T>> actions;

  @override
  State<ChatActionSheet<T>> createState() => _ChatActionSheetState<T>();
}

class _ChatActionSheetState<T> extends State<ChatActionSheet<T>> {
  bool _closing = false;

  void _select([T? value]) {
    if (_closing) return;
    _closing = true;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: LayoutBuilder(
        builder: (context, constraints) => ConstrainedBox(
          constraints: BoxConstraints(maxHeight: constraints.maxHeight * 0.85),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.l,
                0,
                AppSpacing.l,
                AppSpacing.l,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: AppSpacing.xs,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: AppSpacing.s),
                    child: Row(
                      children: [
                        Expanded(
                          child: Semantics(
                            header: true,
                            child: Text(
                              widget.title,
                              style: theme.textTheme.titleLarge,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: '关闭',
                          onPressed: _select,
                          icon: const Icon(Symbols.close),
                        ),
                      ],
                    ),
                  ),
                  for (final action in widget.actions)
                    AppInteractiveSurface(
                      key: action.key,
                      onTap: action.enabled
                          ? () => _select(action.value)
                          : null,
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.l),
                        child: Row(
                          children: [
                            ExcludeSemantics(
                              child: Icon(
                                action.icon,
                                size: 24,
                                color: action.enabled
                                    ? colors.onSurfaceVariant
                                    : colors.onSurface.withValues(alpha: 0.38),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.l),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    action.label,
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      color: action.enabled
                                          ? colors.onSurface
                                          : colors.onSurface.withValues(
                                              alpha: 0.38,
                                            ),
                                    ),
                                  ),
                                  if (action.description case final text?) ...[
                                    const SizedBox(height: AppSpacing.xs),
                                    Text(
                                      text,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: action.enabled
                                                ? colors.onSurfaceVariant
                                                : colors.onSurface.withValues(
                                                    alpha: 0.38,
                                                  ),
                                          ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
