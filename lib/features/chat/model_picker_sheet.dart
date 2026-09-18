import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../core/error/failure.dart';
import '../../../core/theme/app_control_style.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_icon_badge.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../../core/widgets/app_selection_surface.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../data/models/profile_model.dart';
import '../../../data/models/provider_profile.dart';
import '../../../data/models/reasoning_effort.dart';
import '../../../data/repositories/provider_profile_repository.dart';
import 'model_selection.dart';

/// 打开模型与推理等级面板；只有确认才保存本轮选择。
Future<void> showModelPickerSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0),
    builder: (context) => const ModelPickerSheet(),
  );
}

/// 可搜索的本地模型列表与独立于列表的推理、确认操作。
class ModelPickerSheet extends ConsumerStatefulWidget {
  const ModelPickerSheet({super.key});

  @override
  ConsumerState<ModelPickerSheet> createState() => _ModelPickerSheetState();
}

class _ModelPickerSheetState extends ConsumerState<ModelPickerSheet> {
  final _searchController = TextEditingController();

  /// 键盘拉起时 AppSheet 会切换紧凑分支，搜索框靠 GlobalKey 跨分支保住焦点。
  final _searchFieldKey = GlobalKey();
  final _listController = ScrollController();
  final _headerKeys = <String, GlobalKey>{};
  final _estimatedOffsets = <String, double>{};
  ChatModelSelection? _initialSelection;
  String? _draftProfileId;
  String? _draftModel;
  ReasoningEffort _draftEffort = ReasoningEffort.off;
  String _query = '';
  String? _saveError;
  bool _initialized = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual(modelSelectionProvider, (_, next) {
      if (!mounted ||
          _initialized ||
          next.isLoading ||
          next.hasError ||
          !next.hasValue) {
        return;
      }
      final selection = next.value;
      setState(() {
        _initialized = true;
        _initialSelection = selection;
        _draftProfileId = selection?.profile.id;
        _draftModel = selection?.model;
        _draftEffort = selection?.effort ?? ReasoningEffort.off;
      });
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _listController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profiles = ref.watch(providerProfilesProvider);
    final selection = ref.watch(modelSelectionProvider);
    final entries = _entriesFor(profiles.value ?? const []);
    final draft = _selectedEntry(entries);

    return PopScope(
      canPop: !_saving,
      child: AppSheet(
        title: '选择模型',
        titleTrailing: _initialized && draft?.model != null
            ? _buildDraftTrailing(draft!)
            : null,
        showClose: !_saving,
        footer: _initialized && !profiles.hasError && entries.isNotEmpty
            ? _buildFooter(draft)
            : null,
        child: profiles.when(
          data: (profiles) {
            if (profiles.isEmpty) {
              return _buildStatus(
                icon: Symbols.cloud,
                title: '暂无服务商',
                action: FilledButton.tonalIcon(
                  onPressed: () => _openConfiguration(),
                  icon: const Icon(Symbols.add),
                  label: const Text('去配置服务商'),
                ),
              );
            }
            if (!_initialized) {
              if (selection.hasError) {
                return _buildLoadError(selection.error!);
              }
              return _loading();
            }
            return _buildModels(entries, draft);
          },
          loading: _loading,
          error: (error, _) => _buildLoadError(error),
        ),
      ),
    );
  }

  List<_PickerEntry> _entriesFor(List<ProviderProfile> profiles) {
    final entries = <_PickerEntry>[];
    for (final profile in profiles) {
      final models = <String, ProfileModel>{};
      for (final model in profile.enabledModels) {
        // 只有编辑页勾选启用的模型才进入选择列表。
        if (model.enabled) models.putIfAbsent(model.id, () => model);
      }
      final initial = _initialSelection;
      String? manualModel;
      if (initial != null &&
          initial.profile.id == profile.id &&
          !models.containsKey(initial.model)) {
        // 当前选择不在启用列表里（手输模型或已被取消勾选）：保留为可确认项，
        // 沿用它在本次选择中的能力标记。
        manualModel = initial.model;
        models[initial.model] = ProfileModel(
          id: initial.model,
          supportsReasoning: initial.supportsReasoning,
          supportsImages: initial.supportsImages,
        );
      }
      if (models.isEmpty) {
        entries.add((profile: profile, model: null, manual: false));
      } else {
        for (final model in models.values) {
          entries.add((
            profile: profile,
            model: model,
            manual: model.id == manualModel,
          ));
        }
      }
    }
    return entries;
  }

  _PickerEntry? _selectedEntry(List<_PickerEntry> entries) {
    for (final entry in entries) {
      if (entry.model != null &&
          entry.profile.id == _draftProfileId &&
          entry.model!.id == _draftModel) {
        return entry;
      }
    }
    return null;
  }

  Widget _buildModels(List<_PickerEntry> entries, _PickerEntry? draft) {
    final query = _query.trim().toLowerCase();
    final searching = query.isNotEmpty;
    final profiles = <ProviderProfile>[
      ...{for (final entry in entries) entry.profile.id: entry.profile}.values,
    ];
    // 搜索时列表与标签都只保留命中的服务商与模型。
    final visible = searching
        ? [
            for (final entry in entries)
              if (entry.model != null &&
                  _entryMatches(entry.profile, entry.model, query))
                entry,
          ]
        : entries;
    final visibleProfiles = [
      for (final profile in profiles)
        if (visible.any((entry) => entry.profile.id == profile.id)) profile,
    ];

    // 单一平铺列表：服务商名称作分组标题，标题位置记入估算偏移供标签跳转。
    final items = <Object>[];
    final counts = <String, int>{};
    _estimatedOffsets.clear();
    var offset = 0.0;
    for (final profile in visibleProfiles) {
      _estimatedOffsets[profile.id] = offset;
      items.add(profile);
      offset += _estimatedHeaderExtent;
      for (final entry in visible) {
        if (entry.profile.id != profile.id) continue;
        items.add(entry);
        if (entry.model != null) {
          counts[profile.id] = (counts[profile.id] ?? 0) + 1;
        }
        offset += _estimatedOptionExtent;
      }
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.l,
            0,
            AppSpacing.l,
            AppSpacing.m,
          ),
          child: KeyedSubtree(
            key: const ValueKey('model-search'),
            child: TextField(
              key: _searchFieldKey,
              controller: _searchController,
              enabled: !_saving,
              textInputAction: TextInputAction.search,
              onChanged: (value) => setState(() => _query = value),
              onSubmitted: (_) => FocusScope.of(context).unfocus(),
              decoration: InputDecoration(
                hintText: '搜索模型或服务商',
                prefixIcon: const Icon(Symbols.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: '清除搜索',
                        onPressed: _clearSearch,
                        icon: const Icon(Symbols.close),
                      ),
              ),
            ),
          ),
        ),
        if (visibleProfiles.isNotEmpty)
          _buildProviderTabs(visibleProfiles, counts, _draftProfileId),
        Expanded(
          child: visible.isEmpty
              ? _buildStatus(
                  icon: Symbols.search_off,
                  title: '没有找到模型',
                  action: TextButton(
                    onPressed: _clearSearch,
                    child: const Text('清除搜索'),
                  ),
                )
              : ListView.builder(
                  key: const ValueKey('model-list'),
                  controller: _listController,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.l,
                    0,
                    AppSpacing.l,
                    AppSpacing.l,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    if (item is ProviderProfile) {
                      return _buildProviderHeading(item);
                    }
                    final entry = item as _PickerEntry;
                    return Padding(
                      key: ValueKey((entry.profile.id, entry.model?.id)),
                      padding: const EdgeInsets.only(bottom: AppSpacing.s),
                      child: entry.model == null
                          ? _buildUnconfiguredProfile(entry.profile)
                          : _buildModelOption(entry),
                    );
                  },
                ),
        ),
      ],
    );
  }

  static const _estimatedHeaderExtent = 40.0;
  static const _estimatedOptionExtent = 64.0;

  Widget _buildProviderHeading(ProviderProfile profile) {
    return Padding(
      key: _headerKeys.putIfAbsent(profile.id, GlobalKey.new),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s,
        AppSpacing.m,
        AppSpacing.s,
        AppSpacing.s,
      ),
      child: Semantics(
        header: true,
        child: Text(
          profile.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleSmall
              ?.copyWith(color: context.brandColors.teal),
        ),
      ),
    );
  }

  /// 标签点击只滚动定位到对应分组，不改草稿。
  void _scrollToProvider(String profileId) {
    FocusScope.of(context).unfocus();
    final offset = _estimatedOffsets[profileId];
    if (offset == null || !_listController.hasClients) return;
    final position = _listController.position;
    final maxExtent = position.hasContentDimensions
        ? position.maxScrollExtent
        : offset;
    // 条目高度不固定：先跳到估算位置，再对标题做精确对齐。
    _listController.jumpTo(offset.clamp(0.0, maxExtent));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final context = _headerKeys[profileId]?.currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          alignment: 0,
          duration: AppMotion.reduce(context)
              ? Duration.zero
              : const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  /// 标题右侧的紧凑摘要：待确认/当前徽标 + 草稿模型 id。
  Widget _buildDraftTrailing(_PickerEntry draft) {
    final theme = Theme.of(context);
    final changed =
        draft.profile.id != _initialSelection?.profile.id ||
        draft.model?.id != _initialSelection?.model ||
        _draftEffort != _initialSelection?.effort;
    return Row(
      key: const ValueKey('model-draft-summary'),
      children: [
        AppBadge(label: changed ? '待确认' : '当前'),
        const SizedBox(width: AppSpacing.s),
        // 占满剩余宽度，在真实边界截断，不与标题五五分。
        Expanded(
          child: Text(
            draft.model!.id,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
        ),
      ],
    );
  }

  Widget _buildProviderTabs(
    List<ProviderProfile> profiles,
    Map<String, int> counts,
    String? selectedProfileId,
  ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final scaler = MediaQuery.textScalerOf(context);
    final tabHeight = (AppSpacing.s * 2 + scaler.scale(14) * 1.35).clamp(
      AppControlStyle.touchTarget,
      double.infinity,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s),
      child: SizedBox(
        height: tabHeight,
        child: ListView.separated(
          key: const ValueKey('provider-list'),
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
          itemCount: profiles.length,
          separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.s),
          itemBuilder: (context, index) {
            final profile = profiles[index];
            final selected = profile.id == selectedProfileId;
            final foreground = _saving
                ? colors.onSurface.withValues(alpha: 0.38)
                : selected
                ? colors.onPrimaryContainer
                : colors.onSurface;
            return Semantics(
              key: ValueKey(('provider-tab', profile.id)),
              selected: selected,
              button: true,
              label: profile.name,
              child: FilledButton.tonal(
                onPressed: _saving ? null : () => _scrollToProvider(profile.id),
                style: AppControlStyle.compact.copyWith(
                  animationDuration: AppMotion.reduce(context)
                      ? Duration.zero
                      : AppMotion.effects,
                  shape: AppControlStyle.shape(compact: true, active: selected),
                  padding: const WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: AppSpacing.m),
                  ),
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.disabled)) return null;
                    return selected
                        ? colors.primaryContainer.withValues(alpha: 0.72)
                        : colors.surfaceContainerHigh.withValues(alpha: 0.6);
                  }),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 64,
                    maxWidth: 200,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          profile.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: foreground,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        '${counts[profile.id] ?? 0}',
                        maxLines: 1,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: selected || _saving
                              ? foreground
                              : colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildModelOption(_PickerEntry entry) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final model = entry.model!;
    final selected =
        entry.profile.id == _draftProfileId && model.id == _draftModel;
    final foreground = selected ? colors.onPrimaryContainer : colors.onSurface;
    final metadata = [
      if (model.supportsReasoning) '支持推理',
      if (model.supportsTools) '支持工具',
      if (model.supportsImages) '支持图片',
      if (entry.manual) '当前手动模型',
    ];
    return Semantics(
      key: ValueKey(('model-option', entry.profile.id, model.id)),
      selected: selected,
      button: true,
      label: entry.profile.name,
      child: AppSelectionSurface(
        selected: selected,
        onTap: _saving ? null : () => _choose(entry),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.m),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        model.id,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: foreground,
                        ),
                      ),
                      if (metadata.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          metadata.join(' · '),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: selected
                                ? foreground
                                : colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.m),
                SizedBox.square(
                  dimension: 24,
                  child: selected
                      ? Icon(Symbols.check_circle, color: foreground, fill: 1)
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUnconfiguredProfile(ProviderProfile profile) {
    final theme = Theme.of(context);
    return Padding(
      key: ValueKey(('empty-profile', profile.id)),
      padding: const EdgeInsets.all(AppSpacing.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('暂无模型', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.s),
          TextButton.icon(
            onPressed: _saving ? null : () => _openConfiguration(profile.id),
            icon: const Icon(Symbols.edit),
            label: const Text('配置模型'),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(_PickerEntry? draft) {
    final theme = Theme.of(context);
    final brand = context.brandColors;
    final model = draft?.model;
    return Column(
      key: const ValueKey('model-picker-footer'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (model?.supportsReasoning == true) ...[
          Row(
            children: [
              Text('推理等级', style: theme.textTheme.labelLarge),
              const Spacer(),
              Text(
                _draftEffort.label,
                key: const ValueKey('reasoning-effort-label'),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: brand.onLavenderContainer,
                ),
              ),
            ],
          ),
          // 统一提供全部等级：最左关闭，最右最高，是否合规由服务商服务器判断。
          Row(
            children: [
              Text('关', style: theme.textTheme.bodySmall),
              Expanded(
                child: Slider(
                  key: const ValueKey('reasoning-effort-slider'),
                  value: _draftEffort.index.toDouble(),
                  max: (ReasoningEffort.values.length - 1).toDouble(),
                  divisions: ReasoningEffort.values.length - 1,
                  label: _draftEffort.label,
                  activeColor: brand.lavender,
                  onChanged: _saving
                      ? null
                      : (value) => setState(() {
                          _draftEffort = ReasoningEffort.values[value.round()];
                          _saveError = null;
                        }),
                ),
              ),
              Text('最高', style: theme.textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: AppSpacing.s),
        ],
        if (_saveError != null) ...[
          Semantics(
            liveRegion: true,
            child: Text(
              _saveError!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s),
        ],
        OverflowBar(
          alignment: MainAxisAlignment.spaceBetween,
          overflowAlignment: OverflowBarAlignment.end,
          spacing: AppSpacing.s,
          overflowSpacing: AppSpacing.s,
          children: [
            TextButton(
              onPressed: _saving ? null : () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton.icon(
              key: const ValueKey('confirm-model-selection'),
              onPressed: _saving || draft == null
                  ? null
                  : () => _confirm(draft),
              icon: _saving
                  ? SizedBox.square(
                      dimension: 18,
                      child: AppLoadingIndicator(
                        color: theme.colorScheme.onPrimary,
                      ),
                    )
                  : const Icon(Symbols.check),
              label: Text(_saving ? '保存中…' : '确认选择'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatus({
    required IconData icon,
    required String title,
    required Widget action,
  }) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIconBadge(icon: icon, tone: AppTone.teal),
            const SizedBox(height: AppSpacing.l),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.l),
            action,
          ],
        ),
      ),
    );
  }

  Widget _buildLoadError(Object error) {
    return AppEmptyState(
      icon: Symbols.error_outline,
      title: '无法加载模型',
      message: error is Failure ? error.userMessage : '读取本地配置失败，请重试。',
      action: FilledButton.tonalIcon(
        onPressed: () {
          ref.invalidate(providerProfilesProvider);
          ref.invalidate(modelSelectionProvider);
        },
        icon: const Icon(Symbols.refresh),
        label: const Text('重试'),
      ),
    );
  }

  Widget _loading() =>
      const Center(child: AppLoadingIndicator(semanticsLabel: '正在加载模型'));

  void _clearSearch() {
    _searchController.clear();
    setState(() => _query = '');
  }

  void _choose(_PickerEntry entry) {
    FocusScope.of(context).unfocus();
    setState(() {
      _draftProfileId = entry.profile.id;
      _draftModel = entry.model!.id;
      _saveError = null;
    });
  }

  void _openConfiguration([String? profileId]) {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.push(
      profileId == null
          ? '/settings/providers'
          : '/settings/providers/${Uri.encodeComponent(profileId)}',
    );
  }

  Future<void> _confirm(_PickerEntry draft) async {
    final effort = _draftEffort;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      await ref
          .read(modelSelectionProvider.notifier)
          .select(draft.profile.id, draft.model!.id, effort: effort);
      if (!mounted) return;
      setState(() => _saving = false);
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError = error is Failure
            ? '未能完整保存选择：${error.userMessage}'
            : '未能完整保存选择，请重试。';
      });
    }
  }
}

typedef _PickerEntry = ({
  ProviderProfile profile,
  ProfileModel? model,
  bool manual,
});

/// 关键词命中：服务商名称、服务商 id 或模型 id 其一即可（query 已转小写）。
bool _entryMatches(ProviderProfile profile, ProfileModel? model, String query) {
  return profile.name.toLowerCase().contains(query) ||
      profile.id.toLowerCase().contains(query) ||
      (model?.id.toLowerCase().contains(query) ?? false);
}
