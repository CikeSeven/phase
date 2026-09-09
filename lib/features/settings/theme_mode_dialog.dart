import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../core/error/failure.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_icon_badge.dart';
import 'theme_mode_controller.dart';
import 'theme_preview.dart';

/// 主题模式的用户可见名称。
String themeModeLabel(ThemeMode mode) => switch (mode) {
  ThemeMode.system => '跟随系统',
  ThemeMode.light => '浅色',
  ThemeMode.dark => '深色',
};

/// 选择预览保持本地草稿，应用时才切换并持久化主题。
class ThemeModeDialog extends ConsumerStatefulWidget {
  const ThemeModeDialog({required this.initialMode, super.key});

  final ThemeMode initialMode;

  @override
  ConsumerState<ThemeModeDialog> createState() => _ThemeModeDialogState();
}

class _ThemeModeDialogState extends ConsumerState<ThemeModeDialog> {
  late ThemeMode _draft = widget.initialMode;
  bool _saving = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: !_saving,
      child: AppDialog(
        title: '选择外观',
        icon: null,
        tone: AppTone.lavender,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final mode in ThemeMode.values) ...[
              if (mode != ThemeMode.values.first)
                const SizedBox(height: AppSpacing.m),
              _ThemeModeOption(
                mode: mode,
                selected: mode == _draft,
                onTap: _saving
                    ? null
                    : () => setState(() {
                        _draft = mode;
                        _error = null;
                      }),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.l),
              Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const ValueKey('apply-theme'),
            onPressed: _saving ? null : _apply,
            child: Text(_saving ? '保存中…' : '应用主题'),
          ),
        ],
      ),
    );
  }

  Future<void> _apply() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(themeModeControllerProvider.notifier).setThemeMode(_draft);
      if (!mounted) return;
      setState(() => _saving = false);
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error is Failure
            ? '主题未能保存：${error.userMessage}'
            : '主题未能保存，请重试。';
      });
    }
  }
}

class _ThemeModeOption extends StatelessWidget {
  const _ThemeModeOption({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final ThemeMode mode;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      key: ValueKey('theme-option-${mode.name}'),
      selected: selected,
      button: true,
      child: Material(
        color: selected
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.72)
            : theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.4),
        borderRadius: AppRadius.mediumAll,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.m),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        themeModeLabel(mode),
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.s),
                      ExcludeSemantics(
                        child: ThemePreview(
                          key: ValueKey('theme-swatch-${mode.name}'),
                          mode: mode,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.s),
                if (selected)
                  Icon(
                    Symbols.check_circle,
                    color: theme.colorScheme.primary,
                    fill: 1,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
