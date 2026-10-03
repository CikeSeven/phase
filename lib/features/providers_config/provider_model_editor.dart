import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_section.dart';
import '../../../data/datasources/local/model_catalog_cache.dart';
import '../../../data/models/model_catalog.dart';
import '../../../data/models/profile_model.dart';

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
              presetId: widget.presetId,
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
              selectedIcon: const Icon(Symbols.check, size: selectedIconSize),
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

/// 单个模型的预算参数；目录值不改变协议请求。
///
/// 上下文窗口与输出上限的提示来自 models.dev 目录（命中时）或本地默认；
/// 目录值只做提示与校验基线，绝不回写用户输入。
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
  late final _maxOutputController = TextEditingController(
    text: widget.model.maxOutputTokens?.toString() ?? '',
  );

  late final _contextController = TextEditingController(
    text: widget.model.contextWindow?.toString() ?? '',
  );
  String? _budgetError;
  int _applyRevision = 0;

  @override
  void dispose() {
    _maxOutputController.dispose();
    _contextController.dispose();
    super.dispose();
  }

  ModelCatalogEntry? _lookup(ModelCatalog catalog) =>
      catalog.lookup(widget.presetId, widget.model.id);

  Future<void> _apply() async {
    final revision = ++_applyRevision;
    ModelCatalog catalog;
    try {
      catalog = await ref.read(modelCatalogProvider.future);
    } on Object {
      if (mounted && revision == _applyRevision) {
        setState(() => _budgetError = '模型目录读取失败，请重试。');
      }
      return;
    }
    if (!mounted || !widget.enabled || revision != _applyRevision) return;
    // 首次加载期间提交也按最终目录校验，不能用临时默认放行无效预算。
    final entry = _lookup(catalog);
    final maxOutput = int.tryParse(_maxOutputController.text.trim());
    final rawWindow = _contextController.text.trim();
    final window = int.tryParse(rawWindow);
    final rawOutput = _maxOutputController.text.trim();
    final fallbackWindow =
        entry?.contextWindow ?? ModelCatalog.localDefaultWindow;
    final fallbackOutput =
        entry?.maxOutputTokens ?? ModelCatalog.localDefaultOutputReserve;
    if ((rawWindow.isNotEmpty && (window == null || window < 2048)) ||
        (rawOutput.isNotEmpty && (maxOutput == null || maxOutput <= 0)) ||
        ((window ?? fallbackWindow) <= (maxOutput ?? fallbackOutput) + 1024)) {
      setState(() => _budgetError = '窗口至少 2048，且需大于输出预留加 1024；输出上限须为正整数');
      return;
    }
    setState(() => _budgetError = null);
    widget.onModelChanged(
      widget.model.withSettings(
        contextWindow: window,
        clearContextWindow: rawWindow.isEmpty,
        clearMaxOutputTokens: rawOutput.isEmpty,
        maxOutputTokens: maxOutput,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entry = _lookup(
      ref.watch(modelCatalogProvider).value ?? ModelCatalog.empty,
    );
    final catalogWindow = entry?.contextWindow;
    final catalogOutput = entry?.maxOutputTokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.m,
        AppSpacing.s,
        AppSpacing.s,
        0,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final minimumWidth =
              MediaQuery.textScalerOf(context).scale(80) + AppSpacing.m * 2;
          final halfWidth = (constraints.maxWidth - AppSpacing.s) / 2;
          final fieldWidth = halfWidth >= minimumWidth
              ? halfWidth
              : constraints.maxWidth;
          return Wrap(
            spacing: AppSpacing.s,
            runSpacing: AppSpacing.m,
            children: [
              SizedBox(
                width: fieldWidth,
                child: TextField(
                  key: ValueKey('context-window-${widget.model.id}'),
                  controller: _contextController,
                  enabled: widget.enabled,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => _apply(),
                  onTapOutside: (_) {
                    FocusScope.of(context).unfocus();
                    _apply();
                  },
                  decoration: InputDecoration(
                    labelText: '上下文窗口',
                    hintText:
                        '${catalogWindow ?? ModelCatalog.localDefaultWindow}',
                    errorText: _budgetError,
                    errorMaxLines: 3,
                    isDense: true,
                    contentPadding: const EdgeInsets.all(AppSpacing.m),
                    labelStyle: theme.textTheme.bodyMedium,
                    hintStyle: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              SizedBox(
                width: fieldWidth,
                child: TextField(
                  key: ValueKey('max-output-${widget.model.id}'),
                  controller: _maxOutputController,
                  enabled: widget.enabled,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _apply(),
                  onTapOutside: (_) {
                    FocusScope.of(context).unfocus();
                    _apply();
                  },
                  decoration: InputDecoration(
                    labelText: '输出上限',
                    hintText:
                        '${catalogOutput ?? ModelCatalog.localDefaultOutputReserve}',
                    isDense: true,
                    contentPadding: const EdgeInsets.all(AppSpacing.m),
                    labelStyle: theme.textTheme.bodyMedium,
                    hintStyle: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
