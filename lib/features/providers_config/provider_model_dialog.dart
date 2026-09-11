import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_icon_badge.dart';
import '../../../data/models/profile_model.dart';
import 'provider_ui.dart';

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
  bool _supportsReasoning = true;
  bool _supportsTools = true;
  bool _supportsImages = true;
  bool _submitted = false;

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
        supportsTools: _supportsTools,
        supportsImages: _supportsImages,
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
            ),
            const SizedBox(height: AppSpacing.l),
            Wrap(
              spacing: AppSpacing.s,
              runSpacing: AppSpacing.xs,
              children: [
                CapabilityChip(
                  key: const ValueKey('new-model-reasoning'),
                  icon: Symbols.psychology,
                  label: '推理',
                  tooltip: '该模型是否支持推理（思考）',
                  selected: _supportsReasoning,
                  onSelected: (value) => setState(() {
                    _supportsReasoning = value;
                  }),
                ),
                CapabilityChip(
                  key: const ValueKey('new-model-tools'),
                  icon: Symbols.build,
                  label: '工具',
                  tooltip: '该模型是否支持工具调用',
                  selected: _supportsTools,
                  onSelected: (value) => setState(() {
                    _supportsTools = value;
                  }),
                ),
                CapabilityChip(
                  key: const ValueKey('new-model-images'),
                  icon: Symbols.image,
                  label: '图片',
                  tooltip: '该模型是否支持图片输入',
                  selected: _supportsImages,
                  onSelected: (value) => setState(() {
                    _supportsImages = value;
                  }),
                ),
              ],
            ),
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
