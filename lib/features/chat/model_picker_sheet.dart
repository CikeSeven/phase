import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../core/error/failure.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_icon_badge.dart';
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
        subtitle: '选择模型与推理等级，确认后用于对话',
        showClose: !_saving,
        footer: _initialized && !profiles.hasError && entries.isNotEmpty
            ? _buildFooter(draft)
            : null,
        child: profiles.when(
          data: (profiles) {
            if (profiles.isEmpty) {
              return AppEmptyState(
                icon: Symbols.cloud,
                tone: AppTone.teal,
                title: '还没有配置服务商',
                message: '连接一个 AI 服务商，就能在这里选择对话模型。',
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
      for (final model in profile.modelCandidates) {
        models.putIfAbsent(model.id, () => model);
      }
      final initial = _initialSelection;
      String? manualModel;
      if (initial != null &&
          initial.profile.id == profile.id &&
          !models.containsKey(initial.model)) {
        manualModel = initial.model;
        models[initial.model] = ProfileModel(
          id: initial.model,
          supportsReasoning: initial.supportsReasoning,
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
    final matches = entries.where((entry) {
      return entry.profile.name.toLowerCase().contains(query) ||
          entry.profile.id.toLowerCase().contains(query) ||
          (entry.model?.id.toLowerCase().contains(query) ?? false);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.l,
            0,
            AppSpacing.l,
            AppSpacing.m,
          ),
          child: TextField(
            key: const ValueKey('model-search'),
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
        Expanded(
          child: matches.isEmpty
              ? AppEmptyState(
                  icon: Symbols.search_off,
                  title: '没有找到模型',
                  message: '试试其他模型 ID 或服务商名称。',
                  action: TextButton(
                    onPressed: _clearSearch,
                    child: const Text('清除搜索'),
                  ),
                )
              : ListView.builder(
                  key: const ValueKey('model-list'),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.l,
                    0,
                    AppSpacing.l,
                    AppSpacing.l,
                  ),
                  itemCount: matches.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _buildCurrentSelection(
                        draft,
                        matches.where((entry) => entry.model != null).length,
                      );
                    }
                    final entry = matches[index - 1];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.m),
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

  Widget _buildCurrentSelection(_PickerEntry? draft, int modelCount) {
    final theme = Theme.of(context);
    final changed =
        draft?.profile.id != _initialSelection?.profile.id ||
        draft?.model?.id != _initialSelection?.model ||
        _draftEffort != _initialSelection?.effort;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            key: const ValueKey('model-draft-summary'),
            tint: theme.colorScheme.primary,
            borderRadius: AppRadius.mediumAll,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  draft == null
                      ? '先选择一个模型'
                      : changed
                      ? '待确认选择'
                      : '当前选择',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  draft?.model?.id ?? '确认前不会更改正在使用的设置',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium,
                ),
                if (draft != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    draft.profile.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.l),
          Text(
            queryIsEmpty ? '可用模型 · $modelCount' : '搜索结果 · $modelCount',
            style: theme.textTheme.labelLarge,
          ),
        ],
      ),
    );
  }

  bool get queryIsEmpty => _query.trim().isEmpty;

  Widget _buildModelOption(_PickerEntry entry) {
    final theme = Theme.of(context);
    final model = entry.model!;
    final selected =
        entry.profile.id == _draftProfileId && model.id == _draftModel;
    return Semantics(
      key: ValueKey(('model-option', entry.profile.id, model.id)),
      selected: selected,
      button: true,
      child: AppCard(
        borderRadius: AppRadius.mediumAll,
        tint: selected ? theme.colorScheme.primary : null,
        onTap: _saving ? null : () => _choose(entry),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    model.id,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.s),
                  Wrap(
                    spacing: AppSpacing.s,
                    runSpacing: AppSpacing.s,
                    children: [
                      AppBadge(
                        key: ValueKey((
                          'model-provider',
                          entry.profile.id,
                          model.id,
                        )),
                        label: entry.profile.name,
                        tone: AppTone.teal,
                      ),
                      if (model.supportsReasoning)
                        AppBadge(
                          key: ValueKey((
                            'model-reasoning',
                            entry.profile.id,
                            model.id,
                          )),
                          label: '支持推理',
                          tone: AppTone.lavender,
                        ),
                      if (entry.manual) const AppBadge(label: '当前手动模型'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.m),
            Icon(
              selected ? Symbols.check_circle : Symbols.radio_button_unchecked,
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
              fill: selected ? 1 : 0,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnconfiguredProfile(ProviderProfile profile) {
    final theme = Theme.of(context);
    return AppCard(
      key: ValueKey(('empty-profile', profile.id)),
      borderRadius: AppRadius.mediumAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppBadge(label: profile.name, tone: AppTone.teal),
          const SizedBox(height: AppSpacing.m),
          Text('还没有可用模型', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '到服务商编辑页获取模型列表，或手动添加模型 ID。',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
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
    return Column(
      key: const ValueKey('model-picker-footer'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (draft?.model?.supportsReasoning == true) ...[
          Text('推理等级', style: theme.textTheme.labelLarge),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.s,
            runSpacing: AppSpacing.xs,
            children: [
              for (final effort in ReasoningEffort.values)
                ChoiceChip(
                  key: ValueKey(('reasoning-effort', effort.name)),
                  label: Text(effort.label),
                  tooltip: '推理等级：${effort.label}',
                  selected: _draftEffort == effort,
                  selectedColor: brand.lavenderContainer,
                  checkmarkColor: brand.onLavenderContainer,
                  labelStyle: theme.textTheme.labelLarge?.copyWith(
                    color: _draftEffort == effort
                        ? brand.onLavenderContainer
                        : theme.colorScheme.onSurface,
                  ),
                  onSelected: _saving
                      ? null
                      : (_) => setState(() {
                          _draftEffort = effort;
                          _saveError = null;
                        }),
                ),
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
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
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
      const Center(child: CircularProgressIndicator(semanticsLabel: '正在加载模型'));

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
          .select(draft.profile.id, draft.model!.id);
      if (!mounted) return;
      await ref.read(modelSelectionProvider.notifier).selectEffort(effort);
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
