import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../core/error/failure.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/models/reasoning_effort.dart';
import '../../../data/repositories/provider_profile_repository.dart';
import 'model_selection.dart';

/// 「服务商 × 模型」选择面板（DESIGN.md §5.3 选择弹窗范式：
/// 透明底选项 + 当前选中项尾部 primary 对勾）。
Future<void> showModelPickerSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => const ModelPickerSheet(),
  );
}

class ModelPickerSheet extends ConsumerWidget {
  const ModelPickerSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profilesAsync = ref.watch(providerProfilesProvider);
    final selection = ref.watch(modelSelectionProvider).value;
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: profilesAsync.when(
        data: (profiles) {
          if (profiles.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Symbols.cloud,
                    size: 48,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: AppSpacing.l),
                  Text(
                    '还没有配置服务商',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  FilledButton.tonalIcon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      context.push('/settings/providers');
                    },
                    icon: const Icon(Symbols.settings),
                    label: const Text('去配置服务商'),
                  ),
                ],
              ),
            );
          }
          return ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.l,
              0,
              AppSpacing.l,
              AppSpacing.xl,
            ),
            children: [
              for (final profile in profiles) ...[
                Padding(
                  padding: const EdgeInsets.only(
                    top: AppSpacing.m,
                    bottom: AppSpacing.s,
                  ),
                  child: Text(
                    profile.name,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: colorScheme.primary,
                    ),
                  ),
                ),
                if (profile.modelCandidates.isEmpty)
                  const ListTile(
                    enabled: false,
                    title: Text('暂无可用模型'),
                    subtitle: Text('在编辑页测试连接拉取，或直接填写模型名'),
                  ),
                for (final model in profile.modelCandidates)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.s),
                    child: Material(
                      type: MaterialType.transparency,
                      child: ListTile(
                        title: Text(model.id),
                        subtitle: model.supportsReasoning
                            ? const Text('支持推理')
                            : null,
                        selected:
                            selection?.profile.id == profile.id &&
                            selection?.model == model.id,
                        trailing:
                            selection?.profile.id == profile.id &&
                                selection?.model == model.id
                            ? Icon(Symbols.check, color: colorScheme.primary)
                            : null,
                        onTap: () {
                          ref
                              .read(modelSelectionProvider.notifier)
                              .select(profile.id, model.id);
                          Navigator.of(context).pop();
                        },
                      ),
                    ),
                  ),
              ],
              // 当前模型支持推理时才出现推理等级选择。
              if (selection != null && selection.supportsReasoning) ...[
                const SizedBox(height: AppSpacing.l),
                Text(
                  '推理等级',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: AppSpacing.s),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<ReasoningEffort>(
                    segments: [
                      for (final effort in ReasoningEffort.values)
                        ButtonSegment(
                          value: effort,
                          label: Text(effort.label),
                        ),
                    ],
                    selected: {selection.effort},
                    onSelectionChanged: (selected) {
                      ref
                          .read(modelSelectionProvider.notifier)
                          .selectEffort(selected.first);
                    },
                  ),
                ),
              ],
            ],
          );
        },
        loading: () => const SizedBox(
          height: 160,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, _) => Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Text(error is Failure ? error.userMessage : '加载服务商失败'),
        ),
      ),
    );
  }
}
