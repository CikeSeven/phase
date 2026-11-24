import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/widgets/app_completion_mark.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_control_style.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_section.dart';
import '../../core/widgets/settings_list_item.dart';
import '../../../data/datasources/local/model_catalog_cache.dart';
import '../../../data/models/model_catalog.dart';
import '../../../data/models/profile_model.dart';
import '../../core/widgets/app_dialog.dart';
import 'model_budget_dialog.dart';

/// 用于 CustomScrollView 的模型管理分区，筛选后的条目惰性构建。
///
/// 每个模型左侧的勾选框控制「启用」：只有启用的模型才出现在聊天页
/// 的模型选择列表。
class ProviderModelEditor extends StatefulWidget {
  const ProviderModelEditor({
    required this.presetId,
    required this.models,
    required this.enabled,
    required this.onAdd,
    required this.onModelChanged,
    required this.onRemove,
    super.key,
  });

  /// 同名模型并列时的目录偏好，不限制按模型名匹配的范围。
  final String presetId;
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
                icon: const Icon(LucideIcons.plus),
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
                  prefixIcon: const Icon(LucideIcons.search),
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: '清除模型搜索',
                          onPressed: widget.enabled
                              ? () => setState(_searchController.clear)
                              : null,
                          icon: const Icon(LucideIcons.x),
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
            itemBuilder: (context, index) => SettingsListItem.wrap(
              _ModelCard(
                key: ValueKey('provider-model-${models[index].id}'),
                presetId: widget.presetId,
                model: models[index],
                enabled: widget.enabled,
                onModelChanged: widget.onModelChanged,
                onRemove: widget.onRemove,
              ),
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
    required this.presetId,
    required this.model,
    required this.enabled,
    required this.onModelChanged,
    required this.onRemove,
    super.key,
  });

  final String presetId;
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
              Stack(
                alignment: Alignment.center,
                children: [
                  Checkbox(
                    key: ValueKey('enabled-${model.id}'),
                    value: model.enabled,
                    checkColor: Colors.transparent,
                    semanticLabel: '启用该模型',
                    onChanged: enabled
                        ? (value) => onModelChanged(
                            model.withSettings(enabled: value ?? false),
                          )
                        : null,
                  ),
                  IgnorePointer(
                    child: AppCompletionMark(
                      animate: false,
                      checked: model.enabled,
                      color: enabled
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.surface,
                    ),
                  ),
                ],
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
                icon: const Icon(LucideIcons.trash2),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.m,
              right: AppSpacing.s,
            ),
            child: _ModelCapabilities(
              model: model,
              enabled: enabled,
              onModelChanged: onModelChanged,
            ),
          ),
          _ModelParameters(
            presetId: presetId,
            model: model,
            enabled: enabled,
            onModelChanged: onModelChanged,
          ),
        ],
      ),
    );
  }
}

enum _ModelCapability { tools, images }

/// 两项能力独立选择，允许全部关闭，不把它们当作互斥选项。
class _ModelCapabilities extends StatelessWidget {
  const _ModelCapabilities({
    required this.model,
    required this.enabled,
    required this.onModelChanged,
  });

  final ProfileModel model;
  final bool enabled;
  final ValueChanged<ProfileModel> onModelChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const selectedIconSize = 14.0;
    final style = theme.textTheme.labelMedium?.copyWith(
      fontWeight: FontWeight.w500,
    );
    final painter = TextPainter(
      text: TextSpan(text: '工具', style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final segmentWidth = math.max(
      72.0,
      painter.width +
          AppSpacing.m +
          AppSpacing.l +
          selectedIconSize +
          AppSpacing.s,
    );
    painter.dispose();
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontal = constraints.maxWidth >= segmentWidth * 2;
        return Align(
          alignment: AlignmentDirectional.centerStart,
          child: SizedBox(
            width: horizontal
                ? segmentWidth * 2
                : math.min(segmentWidth, constraints.maxWidth),
            child: SegmentedButton<_ModelCapability>(
              key: ValueKey('capabilities-${model.id}'),
              segments: [
                ButtonSegment(
                  value: _ModelCapability.tools,
                  label: Text('工具', key: ValueKey('tools-${model.id}')),
                  tooltip: '该模型是否支持工具调用',
                ),
                ButtonSegment(
                  value: _ModelCapability.images,
                  label: Text('图片', key: ValueKey('images-${model.id}')),
                  tooltip: '该模型是否支持图片输入',
                ),
              ],
              selected: {
                if (model.supportsTools) _ModelCapability.tools,
                if (model.supportsImages) _ModelCapability.images,
              },
              multiSelectionEnabled: true,
              emptySelectionAllowed: true,
              direction: horizontal ? Axis.horizontal : Axis.vertical,
              selectedIcon: const Icon(
                LucideIcons.check,
                size: selectedIconSize,
              ),
              onSelectionChanged: enabled
                  ? (values) => onModelChanged(
                      model.withSettings(
                        supportsTools: values.contains(_ModelCapability.tools),
                        supportsImages: values.contains(
                          _ModelCapability.images,
                        ),
                      ),
                    )
                  : null,
              style: SegmentedButton.styleFrom(
                textStyle: style,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s,
                  vertical: AppSpacing.xs,
                ),
                tapTargetSize: MaterialTapTargetSize.padded,
                side: BorderSide.none,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 每个模型展示当前限制，具体覆盖值在弹窗中一次保存。
class _ModelParameters extends ConsumerStatefulWidget {
  const _ModelParameters({
    required this.presetId,
    required this.model,
    required this.enabled,
    required this.onModelChanged,
  });

  final String presetId;
  final ProfileModel model;
  final bool enabled;
  final ValueChanged<ProfileModel> onModelChanged;

  @override
  ConsumerState<_ModelParameters> createState() => _ModelParametersState();
}

class _ModelParametersState extends ConsumerState<_ModelParameters> {
  bool _editing = false;

  Future<void> _edit() async {
    if (_editing) return;
    _editing = true;
    try {
      final draft = await showAppDialog<ModelBudgetOverride>(
        context: context,
        builder: (context) =>
            ModelBudgetDialog(presetId: widget.presetId, model: widget.model),
      );
      if (!mounted || !widget.enabled || draft == null) return;
      final model = widget.model;
      if (model.contextWindow == draft.contextWindow &&
          model.maxOutputTokens == draft.maxOutputTokens) {
        return;
      }
      widget.onModelChanged(
        model.withSettings(
          contextWindow: draft.contextWindow,
          clearContextWindow: draft.contextWindow == null,
          maxOutputTokens: draft.maxOutputTokens,
          clearMaxOutputTokens: draft.maxOutputTokens == null,
        ),
      );
    } finally {
      _editing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(modelCatalogProvider).value;
    final model = widget.model;
    final format = MaterialLocalizations.of(context).formatDecimal;
    final window = model.contextWindow;
    final output = model.maxOutputTokens;
    final automaticWindow = catalog == null
        ? '自动'
        : '自动 · ${format(catalog.lookup(widget.presetId, model.id)?.contextWindow ?? ModelCatalog.localDefaultWindow)}';
    final summaryStyle = Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.m,
        right: AppSpacing.s,
        top: AppSpacing.s,
      ),
      child: InkWell(
        key: ValueKey('model-limits-${model.id}'),
        borderRadius: AppRadius.smallAll,
        onTap: widget.enabled ? _edit : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppControlStyle.touchTarget,
          ),
          child: Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: AppSpacing.m,
                  runSpacing: AppSpacing.xs,
                  children: [
                    Text(
                      '上下文窗口 ${window == null ? automaticWindow : format(window)}',
                      style: summaryStyle,
                    ),
                    Text(
                      '输出上限 ${output == null ? '自动' : format(output)}',
                      style: summaryStyle,
                    ),
                  ],
                ),
              ),
              if (widget.enabled) ...[
                const SizedBox(width: AppSpacing.s),
                const ExcludeSemantics(
                  child: Icon(LucideIcons.slidersHorizontal, size: 20),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
