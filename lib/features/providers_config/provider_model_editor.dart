import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_icon_badge.dart';
import '../../../core/widgets/app_section.dart';
import '../../../data/models/profile_model.dart';
import '../../../data/models/reasoning_effort.dart';

/// 用于 CustomScrollView 的模型管理分区，筛选后的条目惰性构建。
class ProviderModelEditor extends StatefulWidget {
  const ProviderModelEditor({
    required this.models,
    required this.defaultModel,
    required this.enabled,
    required this.onAdd,
    required this.onDefaultChanged,
    required this.onModelChanged,
    required this.onRemove,
    super.key,
  });

  final List<ProfileModel> models;
  final String? defaultModel;
  final bool enabled;
  final VoidCallback onAdd;
  final ValueChanged<String> onDefaultChanged;
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
              subtitle: '${widget.models.length} 个模型',
              action: TextButton.icon(
                key: const ValueKey('add-provider-model'),
                onPressed: widget.enabled ? widget.onAdd : null,
                icon: const Icon(Symbols.add),
                label: const Text('添加模型'),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: AppBadge(label: '默认模型', tone: AppTone.teal),
                        ),
                        const SizedBox(height: AppSpacing.s),
                        Text(
                          widget.defaultModel ??
                              (widget.models.isEmpty ? '未设置' : '自动使用首个模型'),
                          key: const ValueKey('default-model-summary'),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.l),
                  TextField(
                    key: const ValueKey('provider-model-search'),
                    controller: _searchController,
                    enabled: widget.enabled,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: '搜索模型',
                      hintText: '模型 ID',
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
                ],
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
            itemBuilder: (context, index) {
              final model = models[index];
              final isDefault = widget.defaultModel == model.id;
              return AppCard(
                key: ValueKey('provider-model-${model.id}'),
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.m,
                  AppSpacing.xs,
                  AppSpacing.xs,
                  AppSpacing.xs,
                ),
                borderRadius: AppRadius.mediumAll,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
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
                        if (isDefault)
                          const Padding(
                            padding: EdgeInsets.only(right: AppSpacing.xs),
                            child: AppBadge(label: '默认'),
                          ),
                        IconButton(
                          key: ValueKey('default-${model.id}'),
                          tooltip: isDefault ? '当前默认模型' : '设为默认模型',
                          onPressed: widget.enabled && !isDefault
                              ? () => widget.onDefaultChanged(model.id)
                              : null,
                          icon: Icon(
                            isDefault
                                ? Symbols.check_circle
                                : Symbols.radio_button_unchecked,
                          ),
                        ),
                        IconButton(
                          key: ValueKey('remove-${model.id}'),
                          tooltip: '移除模型',
                          onPressed: widget.enabled
                              ? () => widget.onRemove(model)
                              : null,
                          color: theme.colorScheme.error,
                          icon: const Icon(Symbols.delete),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.s),
                      child: Wrap(
                        spacing: AppSpacing.s,
                        runSpacing: AppSpacing.xs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          FilterChip(
                            key: ValueKey('reasoning-${model.id}'),
                            label: const Text('推理'),
                            tooltip: '该模型是否支持推理（思考）',
                            selected: model.supportsReasoning,
                            onSelected: widget.enabled
                                ? (value) => widget.onModelChanged(
                                    model.copyWith(supportsReasoning: value),
                                  )
                                : null,
                          ),
                          if (model.supportsReasoning)
                            for (final effort in ReasoningEffort.levels)
                              _LevelChip(
                                model: model,
                                effort: effort,
                                enabled: widget.enabled,
                                onChanged: widget.onModelChanged,
                              ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 单个推理等级的开关；最后一个已选等级不允许再取消，避免空集合。
class _LevelChip extends StatelessWidget {
  const _LevelChip({
    required this.model,
    required this.effort,
    required this.enabled,
    required this.onChanged,
  });

  final ProfileModel model;
  final ReasoningEffort effort;
  final bool enabled;
  final ValueChanged<ProfileModel> onChanged;

  @override
  Widget build(BuildContext context) {
    final allowed = model.allowedEfforts;
    final selected = allowed.contains(effort);
    final lastSelected = selected && allowed.length == 1;
    return FilterChip(
      key: ValueKey('reasoning-level-${model.id}-${effort.name}'),
      label: Text(effort.label),
      tooltip: lastSelected ? '至少保留一个推理等级' : '推理等级：${effort.label}',
      selected: selected,
      onSelected: enabled && !lastSelected
          ? (_) {
              final next = selected
                  ? allowed.where((level) => level != effort)
                  : [...allowed, effort];
              onChanged(
                model.copyWith(
                  reasoningEfforts: ReasoningEffort.normalizeLevels(next),
                ),
              );
            }
          : null,
    );
  }
}
