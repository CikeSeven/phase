import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_icon_badge.dart';
import '../../../data/models/profile_model.dart';
import '../../../data/models/reasoning_effort.dart';

/// 添加模型草稿；重复校验读取当前列表，兼容弹窗期间完成的模型拉取。
class ProviderModelDialog extends StatefulWidget {
  const ProviderModelDialog({required this.containsId, super.key});

  final bool Function(String id) containsId;

  @override
  State<ProviderModelDialog> createState() => _ProviderModelDialogState();
}

class _ProviderModelDialogState extends State<ProviderModelDialog> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  bool _supportsReasoning = false;
  bool _switchTouched = false;
  bool _submitted = false;
  final Set<ReasoningEffort> _levels = ReasoningEffort.levels.toSet();

  @override
  void dispose() {
    _idController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_submitted || !_formKey.currentState!.validate()) return;
    _submitted = true;
    Navigator.of(context).pop(
      ProfileModel(
        id: _idController.text.trim(),
        supportsReasoning: _supportsReasoning,
        reasoningEfforts: _supportsReasoning
            ? ReasoningEffort.normalizeLevels(_levels)
            : const [],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: '添加模型',
      icon: Symbols.add,
      tone: AppTone.teal,
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              key: const ValueKey('new-model-id'),
              controller: _idController,
              autofocus: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(
                labelText: '模型 ID',
                hintText: '如：deepseek-reasoner',
              ),
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              validator: (value) {
                final id = value?.trim() ?? '';
                if (id.isEmpty) return '请输入模型 ID';
                if (widget.containsId(id)) return '该模型 ID 已存在';
                return null;
              },
              onChanged: (value) {
                if (!_switchTouched) {
                  setState(() {
                    _supportsReasoning = guessSupportsReasoning(value);
                  });
                }
              },
            ),
            const SizedBox(height: AppSpacing.l),
            MergeSemantics(
              child: Row(
                children: [
                  const Expanded(child: Text('支持推理')),
                  Switch(
                    key: const ValueKey('new-model-reasoning'),
                    value: _supportsReasoning,
                    onChanged: (value) => setState(() {
                      _supportsReasoning = value;
                      _switchTouched = true;
                    }),
                  ),
                ],
              ),
            ),
            if (_supportsReasoning) ...[
              const SizedBox(height: AppSpacing.s),
              Wrap(
                spacing: AppSpacing.s,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final effort in ReasoningEffort.levels)
                    FilterChip(
                      key: ValueKey('new-model-level-${effort.name}'),
                      label: Text(effort.label),
                      tooltip: '推理等级：${effort.label}',
                      selected: _levels.contains(effort),
                      onSelected: (_) => setState(() {
                        if (_levels.contains(effort)) {
                          // 空集合在存储语义里是「全部」，这里禁止清空以免歧义。
                          if (_levels.length > 1) _levels.remove(effort);
                        } else {
                          _levels.add(effort);
                        }
                      }),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const ValueKey('confirm-add-model'),
          onPressed: _submit,
          child: const Text('添加'),
        ),
      ],
    );
  }
}
