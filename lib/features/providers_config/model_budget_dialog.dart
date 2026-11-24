import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/error/failure.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_dropdown.dart';
import '../../../data/datasources/local/model_catalog_cache.dart';
import '../../../data/models/model_catalog.dart';
import '../../../data/models/profile_model.dart';

typedef ModelBudgetOverride = ({int? contextWindow, int? maxOutputTokens});

class ModelBudgetDialog extends ConsumerStatefulWidget {
  const ModelBudgetDialog({
    required this.presetId,
    required this.model,
    this.onSave,
    super.key,
  });

  final String presetId;
  final ProfileModel model;
  final Future<void> Function(ModelBudgetOverride)? onSave;

  @override
  ConsumerState<ModelBudgetDialog> createState() => _ModelBudgetDialogState();
}

class _ModelBudgetDialogState extends ConsumerState<ModelBudgetDialog> {
  static const _auto = 'auto';
  static const _custom = 'custom';
  static const _windowPresets = [32768, 65536, 128000, 200000, 262144, 1000000];
  static const _outputPresets = [4096, 8192, 16384, 32768, 65536];

  late String _windowChoice = _initialChoice(
    widget.model.contextWindow,
    _windowPresets,
  );
  late String _outputChoice = _initialChoice(
    widget.model.maxOutputTokens,
    _outputPresets,
  );
  late final _window = TextEditingController(
    text: widget.model.contextWindow?.toString(),
  );
  late final _output = TextEditingController(
    text: widget.model.maxOutputTokens?.toString(),
  );
  bool _saving = false;
  String? _error;

  static String _initialChoice(int? value, List<int> presets) {
    if (value == null) return _auto;
    return presets.contains(value) ? value.toString() : _custom;
  }

  @override
  void dispose() {
    _window.dispose();
    _output.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final window = int.tryParse(
      _windowChoice == _custom ? _window.text.trim() : _windowChoice,
    );
    final output = int.tryParse(
      _outputChoice == _custom ? _output.text.trim() : _outputChoice,
    );
    if (_windowChoice != _auto && (window == null || window < 2048)) {
      setState(() => _error = '上下文窗口至少为 2,048 token');
      return;
    }
    if (_outputChoice != _auto && (output == null || output <= 0)) {
      setState(() => _error = '输出上限须为正整数');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final ModelCatalog catalog;
    try {
      catalog = await ref.read(modelCatalogProvider.future);
    } on Object {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '模型目录读取失败，请重试';
        });
      }
      return;
    }
    if (!mounted) return;
    final limits = resolveContextLimits(
      presetId: widget.presetId,
      modelId: widget.model.id,
      userContextWindow: window,
      userMaxOutputTokens: output,
      catalog: catalog,
    );
    final reserve =
        output ??
        limits.catalogMaxOutputTokens ??
        ModelCatalog.localDefaultOutputReserve;
    if (limits.contextWindow - 1024 <= reserve) {
      setState(() {
        _saving = false;
        _error = '上下文窗口须比输出预留多出 1,024 token 以上';
      });
      return;
    }
    final draft = (contextWindow: window, maxOutputTokens: output);
    try {
      if (window != widget.model.contextWindow ||
          output != widget.model.maxOutputTokens) {
        await widget.onSave?.call(draft);
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error is Failure ? error.userMessage : '模型限制保存失败，请重试';
        });
      }
      return;
    }
    if (mounted) Navigator.of(context).pop(draft);
  }

  Widget _field({
    required String label,
    required String autoLabel,
    required List<int> presets,
    required String choice,
    required TextEditingController controller,
    required ValueChanged<String> onChanged,
  }) {
    final format = MaterialLocalizations.of(context).formatDecimal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.s,
      children: [
        AppDropdown<String>(
          label: label,
          value: choice,
          options: {
            _auto: autoLabel,
            for (final value in presets) value.toString(): format(value),
            _custom: '自定义',
          },
          onChanged: _saving
              ? null
              : (value) {
                  if (value == _custom && int.tryParse(choice) != null) {
                    controller.text = choice;
                  }
                  setState(() {
                    onChanged(value);
                    _error = null;
                  });
                },
        ),
        if (choice == _custom)
          TextField(
            controller: controller,
            enabled: !_saving,
            keyboardType: TextInputType.number,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            decoration: InputDecoration(
              labelText: '自定义$label',
              suffixText: 'token',
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(modelCatalogProvider).value;
    final entry = catalog?.lookup(widget.presetId, widget.model.id);
    final format = MaterialLocalizations.of(context).formatDecimal;
    final autoWindow = switch ((catalog, entry?.contextWindow)) {
      (_, final int window) => '自动 · ${format(window)}',
      (null, _) => '自动',
      _ => '自动 · ${format(ModelCatalog.localDefaultWindow)}（本地默认）',
    };
    return AppDialog(
      title: '模型限制',
      description: widget.model.id,
      icon: LucideIcons.slidersHorizontal,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.m,
        children: [
          _field(
            label: '上下文窗口',
            autoLabel: autoWindow,
            presets: _windowPresets,
            choice: _windowChoice,
            controller: _window,
            onChanged: (value) => _windowChoice = value,
          ),
          _field(
            label: '输出上限',
            autoLabel: '自动 · 协议默认',
            presets: _outputPresets,
            choice: _outputChoice,
            controller: _output,
            onChanged: (value) => _outputChoice = value,
          ),
          if (entry?.maxOutputTokens case final int limit
              when _outputChoice == _auto)
            Text(
              '目录输出上限 ${format(limit)} token，用于上下文预留',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if (_error case final error?)
            Semantics(
              liveRegion: true,
              child: Text(
                error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? '保存中…' : '保存'),
        ),
      ],
    );
  }
}
