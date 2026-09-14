import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_selection_surface.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../data/models/model_selection.dart';
import '../../../data/models/profile_model.dart';
import '../../../data/models/provider_profile.dart';
import '../../../data/models/reasoning_effort.dart';
import '../../data/repositories/provider_profile_repository.dart';

/// 选择助手的默认模型（含服务商与推理等级）；返回 null 表示取消。
///
/// 结果里的 temperature/maxOutputTokens 沿用既有值，由调用方决定是否保留。
Future<ModelSelection?> showAssistantModelSheet(
  BuildContext context, {
  required ModelSelection? current,
}) {
  return showModalBottomSheet<ModelSelection>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _AssistantModelSheet(current: current),
  );
}

class _AssistantModelSheet extends ConsumerStatefulWidget {
  const _AssistantModelSheet({this.current});

  final ModelSelection? current;

  @override
  ConsumerState<_AssistantModelSheet> createState() =>
      _AssistantModelSheetState();
}

class _AssistantModelSheetState extends ConsumerState<_AssistantModelSheet> {
  var _query = '';
  late ReasoningEffort _effort =
      widget.current?.reasoningEffort ?? ReasoningEffort.off;

  /// 每个服务的启用模型；空表示没有可选项。
  List<({ProviderProfile profile, ProfileModel model})> _options(
    List<ProviderProfile> profiles,
  ) {
    final query = _query.trim().toLowerCase();
    return [
      for (final profile in profiles)
        for (final model in profile.enabledModels)
          if (query.isEmpty ||
              model.id.toLowerCase().contains(query) ||
              model.label.toLowerCase().contains(query) ||
              profile.name.toLowerCase().contains(query))
            (profile: profile, model: model),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final profiles = ref.watch(providerProfilesProvider).value ?? const [];
    final options = _options(profiles);

    return AppSheet(
      title: '默认模型',
      subtitle: '会话未单独选择模型时使用它',
      titleTrailing: widget.current == null
          ? const Text('跟随当前选择')
          : Text(widget.current!.modelId),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.l,
              0,
              AppSpacing.l,
              AppSpacing.m,
            ),
            child: TextField(
              key: const ValueKey('assistant-model-search'),
              onChanged: (value) => setState(() => _query = value),
              decoration: const InputDecoration(
                labelText: '搜索模型',
                hintText: '模型名、展示名或服务商',
                prefixIcon: Icon(Symbols.search),
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: options.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(AppSpacing.xl),
                      child: Text('没有可选的模型，请先在服务商配置里启用模型'),
                    ),
                  )
                : ListView.builder(
                    key: const ValueKey('assistant-model-options'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.l,
                    ),
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final option = options[index];
                      final selected =
                          widget.current?.profileId == option.profile.id &&
                          widget.current?.modelId == option.model.id;
                      return _ModelOption(
                        profile: option.profile,
                        model: option.model,
                        selected: selected,
                        onTap: () => Navigator.of(context).pop(
                          ModelSelection(
                            profileId: option.profile.id,
                            modelId: option.model.id,
                            reasoningEffort: _effort,
                            temperature: widget.current?.temperature,
                            maxOutputTokens: widget.current?.maxOutputTokens,
                          ),
                        ),
                      );
                    },
                  ),
          ),
          _EffortRow(
            effort: _effort,
            onChanged: (effort) => setState(() => _effort = effort),
          ),
        ],
      ),
    );
  }
}

class _ModelOption extends StatelessWidget {
  const _ModelOption({
    required this.profile,
    required this.model,
    required this.selected,
    required this.onTap,
  });

  final ProviderProfile profile;
  final ProfileModel model;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: '${profile.name} ${model.label}',
      child: AppSelectionSurface(
        selected: selected,
        onTap: onTap,
        key: ValueKey('assistant-model-${profile.id}-${model.id}'),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.m,
            vertical: AppSpacing.m,
          ),
          child: Row(
            children: [
              SizedBox.square(
                dimension: 24,
                child: selected
                    ? Icon(Symbols.check_circle, color: colors.primary, fill: 1)
                    : null,
              ),
              const SizedBox(width: AppSpacing.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      model.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge,
                    ),
                    Text(
                      profile.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EffortRow extends StatelessWidget {
  const _EffortRow({required this.effort, required this.onChanged});

  final ReasoningEffort effort;
  final ValueChanged<ReasoningEffort> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.l,
        AppSpacing.m,
        AppSpacing.l,
        AppSpacing.l,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('推理等级', style: theme.textTheme.labelLarge),
          const SizedBox(height: AppSpacing.s),
          Wrap(
            spacing: AppSpacing.s,
            runSpacing: AppSpacing.s,
            children: [
              for (final value in [
                ReasoningEffort.off,
                ...ReasoningEffort.levels,
              ])
                ChoiceChip(
                  key: ValueKey('assistant-effort-${value.name}'),
                  label: Text(value.label),
                  selected: value == effort,
                  onSelected: (_) => onChanged(value),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
