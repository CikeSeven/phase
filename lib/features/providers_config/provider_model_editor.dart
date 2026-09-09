import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_icon_badge.dart';
import '../../../core/widgets/app_section.dart';
import '../../../data/models/profile_model.dart';

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
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.m),
            itemBuilder: (context, index) {
              final model = models[index];
              final isDefault = widget.defaultModel == model.id;
              return AppCard(
                key: ValueKey('provider-model-${model.id}'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (isDefault) ...[
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: AppBadge(label: '默认'),
                      ),
                      const SizedBox(height: AppSpacing.s),
                    ],
                    Tooltip(
                      message: model.id,
                      child: Text(
                        model.id,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.m),
                    MergeSemantics(
                      child: Row(
                        children: [
                          const Expanded(child: Text('支持推理')),
                          Switch(
                            key: ValueKey('reasoning-${model.id}'),
                            value: model.supportsReasoning,
                            onChanged: widget.enabled
                                ? (value) => widget.onModelChanged(
                                    model.copyWith(supportsReasoning: value),
                                  )
                                : null,
                          ),
                        ],
                      ),
                    ),
                    const Divider(),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: AppSpacing.s,
                      runSpacing: AppSpacing.s,
                      children: [
                        TextButton.icon(
                          key: ValueKey('default-${model.id}'),
                          onPressed: widget.enabled && !isDefault
                              ? () => widget.onDefaultChanged(model.id)
                              : null,
                          icon: Icon(
                            isDefault
                                ? Symbols.check_circle
                                : Symbols.radio_button_unchecked,
                          ),
                          label: Text(isDefault ? '当前默认' : '设为默认'),
                        ),
                        TextButton.icon(
                          key: ValueKey('remove-${model.id}'),
                          onPressed: widget.enabled
                              ? () => widget.onRemove(model)
                              : null,
                          style: TextButton.styleFrom(
                            foregroundColor: theme.colorScheme.error,
                          ),
                          icon: const Icon(Symbols.delete),
                          label: const Text('移除'),
                        ),
                      ],
                    ),
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
