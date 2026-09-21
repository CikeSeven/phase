import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_section.dart';
import '../../../data/models/profile_model.dart';
import 'provider_ui.dart';

/// 用于 CustomScrollView 的模型管理分区，筛选后的条目惰性构建。
///
/// 每个模型左侧的勾选框控制「启用」：只有启用的模型才出现在聊天页
/// 的模型选择列表。
class ProviderModelEditor extends StatefulWidget {
  const ProviderModelEditor({
    required this.models,
    required this.enabled,
    required this.onAdd,
    required this.onModelChanged,
    required this.onRemove,
    super.key,
  });

  final List<ProfileModel> models;

  /// 表单是否可编辑，由页面的提交、弹层和删除状态决定。
  final bool enabled;
  final VoidCallback onAdd;
  final ValueChanged<ProfileModel> onModelChanged;
  final ValueChanged<ProfileModel> onRemove;

  @override
  State<ProviderModelEditor> createState() => _ProviderModelEditorState();
}

class _ProviderModelEditorState extends State<ProviderModelEditor> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = _searchController.text.trim().toLowerCase();
    final models = widget.models
        .where((model) => model.id.toLowerCase().contains(query))
        .toList();
    final enabledCount = widget.models.where((model) => model.enabled).length;
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.l,
              AppSpacing.xl,
              AppSpacing.l,
              AppSpacing.m,
            ),
            child: AppSection(
              title: '模型管理',
              subtitle: '启用 $enabledCount / ${widget.models.length} 个模型',
              action: TextButton.icon(
                key: const ValueKey('add-provider-model'),
                onPressed: widget.enabled ? widget.onAdd : null,
                icon: const Icon(Symbols.add),
                label: const Text('添加模型'),
              ),
              child: TextField(
                key: const ValueKey('provider-model-search'),
                controller: _searchController,
                enabled: widget.enabled,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: '搜索模型',
                  hintText: '模型 ID',
                  helperText: '勾选的模型才会出现在聊天模型列表',
                  prefixIcon: const Icon(Symbols.search),
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: '清除模型搜索',
                          onPressed: widget.enabled
                              ? () => setState(_searchController.clear)
                              : null,
                          icon: const Icon(Symbols.close),
                        ),
                ),
              ),
            ),
          ),
        ),
        if (models.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.l,
                0,
                AppSpacing.l,
                AppSpacing.xl,
              ),
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      widget.models.isEmpty ? '暂无模型' : '没有匹配的模型',
                      style: theme.textTheme.titleMedium,
                    ),
                    if (query.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.s),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: widget.enabled
                              ? () => setState(_searchController.clear)
                              : null,
                          child: const Text('显示全部模型'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.l,
            0,
            AppSpacing.l,
            AppSpacing.xl,
          ),
          sliver: SliverList.separated(
            itemCount: models.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.s),
            itemBuilder: (context, index) => _ModelCard(
              key: ValueKey('provider-model-${models[index].id}'),
              model: models[index],
              enabled: widget.enabled,
              onModelChanged: widget.onModelChanged,
              onRemove: widget.onRemove,
            ),
          ),
        ),
      ],
    );
  }
}

/// 单个模型的紧凑卡片：左侧勾选框控制启用，下方是能力开关。
class _ModelCard extends StatelessWidget {
  const _ModelCard({
    required this.model,
    required this.enabled,
    required this.onModelChanged,
    required this.onRemove,
    super.key,
  });

  final ProfileModel model;

  /// 表单是否可编辑，由页面的提交、弹层和删除状态决定。
  final bool enabled;
  final ValueChanged<ProfileModel> onModelChanged;
  final ValueChanged<ProfileModel> onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.fromLTRB(0, 0, AppSpacing.xs, AppSpacing.s),
      borderRadius: AppRadius.mediumAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Checkbox(
                key: ValueKey('enabled-${model.id}'),
                value: model.enabled,
                semanticLabel: '启用该模型',
                onChanged: enabled
                    ? (value) => onModelChanged(
                        model.withSettings(enabled: value ?? false),
                      )
                    : null,
              ),
              Expanded(
                child: Tooltip(
                  message: model.id,
                  child: Text(
                    model.id,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ),
              IconButton(
                key: ValueKey('remove-${model.id}'),
                tooltip: '移除模型',
                onPressed: enabled ? () => onRemove(model) : null,
                color: theme.colorScheme.error,
                icon: const Icon(Symbols.delete),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.m,
              right: AppSpacing.s,
            ),
            child: Wrap(
              spacing: AppSpacing.s,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                CapabilityChip(
                  key: ValueKey('tools-${model.id}'),
                  icon: Symbols.build,
                  label: '工具',
                  tooltip: '该模型是否支持工具调用',
                  selected: model.supportsTools,
                  onSelected: enabled
                      ? (value) => onModelChanged(
                          model.withSettings(supportsTools: value),
                        )
                      : null,
                ),
                CapabilityChip(
                  key: ValueKey('images-${model.id}'),
                  icon: Symbols.image,
                  label: '图片',
                  tooltip: '该模型是否支持图片输入',
                  selected: model.supportsImages,
                  onSelected: enabled
                      ? (value) => onModelChanged(
                          model.withSettings(supportsImages: value),
                        )
                      : null,
                ),
              ],
            ),
          ),
          // 采样参数：留空表示不下发，由服务端默认决定。
          _ModelParameters(
            model: model,
            enabled: enabled,
            onModelChanged: onModelChanged,
          ),
        ],
      ),
    );
  }
}

/// 单个模型的采样参数：温度与输出上限，留空即不下发。
class _ModelParameters extends StatefulWidget {
  const _ModelParameters({
    required this.model,
    required this.enabled,
    required this.onModelChanged,
  });

  final ProfileModel model;
  final bool enabled;
  final ValueChanged<ProfileModel> onModelChanged;

  @override
  State<_ModelParameters> createState() => _ModelParametersState();
}

class _ModelParametersState extends State<_ModelParameters> {
  late final _temperatureController = TextEditingController(
    text: widget.model.temperature?.toString() ?? '',
  );
  late final _maxOutputController = TextEditingController(
    text: widget.model.maxOutputTokens?.toString() ?? '',
  );

  late final _contextController = TextEditingController(
    text: widget.model.contextWindow?.toString() ?? '',
  );
  String? _budgetError;

  @override
  void dispose() {
    _temperatureController.dispose();
    _maxOutputController.dispose();
    _contextController.dispose();
    super.dispose();
  }

  void _apply() {
    final temperature = double.tryParse(_temperatureController.text.trim());
    final maxOutput = int.tryParse(_maxOutputController.text.trim());
    final rawWindow = _contextController.text.trim();
    final window = int.tryParse(rawWindow);
    final rawOutput = _maxOutputController.text.trim();
    if ((rawWindow.isNotEmpty && (window == null || window < 2048)) ||
        (rawOutput.isNotEmpty && (maxOutput == null || maxOutput <= 0)) ||
        ((window ?? 32768) <= (maxOutput ?? 4096) + 1024)) {
      setState(() => _budgetError = '窗口至少 2048，且需大于输出预留加 1024；输出上限须为正整数');
      return;
    }
    setState(() => _budgetError = null);
    widget.onModelChanged(
      widget.model.withSettings(
        contextWindow: window,
        clearContextWindow: rawWindow.isEmpty,
        clearMaxOutputTokens: rawOutput.isEmpty,
        temperature: temperature,
        maxOutputTokens: maxOutput,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.m,
        AppSpacing.xs,
        AppSpacing.s,
        0,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final minimumWidth =
              MediaQuery.textScalerOf(context).scale(96) + AppSpacing.xxl;
          final halfWidth = (constraints.maxWidth - AppSpacing.s) / 2;
          final fieldWidth = halfWidth >= minimumWidth
              ? halfWidth
              : constraints.maxWidth;
          return Wrap(
            spacing: AppSpacing.s,
            runSpacing: AppSpacing.m,
            children: [
              SizedBox(
                width: constraints.maxWidth,
                child: TextField(
                  key: ValueKey('context-window-${widget.model.id}'),
                  controller: _contextController,
                  enabled: widget.enabled,
                  keyboardType: TextInputType.number,
                  onSubmitted: (_) => _apply(),
                  onTapOutside: (_) {
                    FocusScope.of(context).unfocus();
                    _apply();
                  },
                  decoration: InputDecoration(
                    labelText: '上下文窗口',
                    hintText: '本地默认 32768',
                    helperText: '用于本地保守预算，不是 API 用量。未设输出上限时预留 4096。',
                    helperMaxLines: 3,
                    errorText: _budgetError,
                    errorMaxLines: 3,
                  ),
                ),
              ),
              SizedBox(
                width: fieldWidth,
                child: TextField(
                  key: ValueKey('temperature-${widget.model.id}'),
                  controller: _temperatureController,
                  enabled: widget.enabled,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => _apply(),
                  onTapOutside: (_) {
                    FocusScope.of(context).unfocus();
                    _apply();
                  },
                  decoration: const InputDecoration(
                    labelText: '温度',
                    hintText: '默认',
                    isDense: true,
                    helperText: '0–2，留空由服务端决定',
                    helperStyle: TextStyle(fontSize: 11),
                    helperMaxLines: 3,
                  ),
                  style: theme.textTheme.bodySmall,
                ),
              ),
              SizedBox(
                width: fieldWidth,
                child: TextField(
                  key: ValueKey('max-output-${widget.model.id}'),
                  controller: _maxOutputController,
                  enabled: widget.enabled,
                  keyboardType: TextInputType.number,
                  onSubmitted: (_) => _apply(),
                  onTapOutside: (_) {
                    FocusScope.of(context).unfocus();
                    _apply();
                  },
                  decoration: const InputDecoration(
                    labelText: '输出上限',
                    hintText: '默认',
                    isDense: true,
                    helperText: 'token 数，留空用默认',
                    helperStyle: TextStyle(fontSize: 11),
                    helperMaxLines: 3,
                  ),
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
