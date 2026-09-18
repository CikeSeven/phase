import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/error/failure.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_bottom_bar.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_interactive_surface.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../data/models/assistant.dart';
import '../chat/chat_controller.dart';

/// 助手列表：真实数据，展示名称、系统提示词与默认模型，点入编辑页。
class AssistantsPage extends ConsumerWidget {
  const AssistantsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assistantsAsync = ref.watch(assistantsProvider);
    final currentId = ref
        .watch(currentAssistantProvider(ref.watch(activeConversationProvider)))
        ?.id;

    return AppScaffold(
      title: '助手',
      subtitle: '为会话设定系统提示词、默认模型与工具范围',
      bottomBar: AppBottomBar(
        child: FilledButton.icon(
          key: const ValueKey('add-assistant'),
          onPressed: () => context.push('/assistants/new'),
          icon: const Icon(Symbols.add),
          label: const Text('新建助手'),
        ),
      ),
      body: assistantsAsync.when(
        skipLoadingOnReload: true,
        data: (assistants) =>
            _AssistantList(assistants: assistants, currentId: currentId),
        loading: () =>
            const Center(child: AppLoadingIndicator(semanticsLabel: '正在读取助手')),
        error: (error, _) => AppEmptyState(
          icon: Symbols.error,
          title: '暂时无法读取助手',
          message: error is Failure ? error.userMessage : '加载助手失败，请重试',
          action: FilledButton.tonal(
            onPressed: () => ref.invalidate(assistantsProvider),
            child: const Text('重试'),
          ),
        ),
      ),
    );
  }
}

class _AssistantList extends StatelessWidget {
  const _AssistantList({required this.assistants, this.currentId});

  final List<Assistant> assistants;
  final String? currentId;

  @override
  Widget build(BuildContext context) {
    if (assistants.isEmpty) {
      return const AppEmptyState(
        icon: Symbols.smart_toy,
        title: '还没有助手',
        message: '新建一个助手，为它写系统提示词并选定默认模型。',
      );
    }
    return ListView.separated(
      key: const ValueKey('assistants-list'),
      padding: const EdgeInsets.all(AppSpacing.l),
      itemCount: assistants.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.m),
      itemBuilder: (context, index) {
        final assistant = assistants[index];
        return _AssistantRow(
          assistant: assistant,
          current: assistant.id == currentId,
        );
      },
    );
  }
}

class _AssistantRow extends StatelessWidget {
  const _AssistantRow({required this.assistant, required this.current});

  final Assistant assistant;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final prompt = assistant.systemPrompt.trim();
    final selection = assistant.defaultModelSelection;

    return Semantics(
      button: true,
      label: assistant.name,
      child: AppInteractiveSurface(
        key: ValueKey('assistant-${assistant.id}'),
        color: colors.surfaceContainerLow,
        radius: AppRadius.large,
        onTap: () => context.push('/assistants/${assistant.id}'),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      assistant.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  if (current) ...[
                    const SizedBox(width: AppSpacing.s),
                    _CurrentBadge(color: colors.primary),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                prompt.isEmpty ? '未设置系统提示词' : prompt,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.s),
              Text(
                selection == null ? '默认模型：跟随当前选择' : '默认模型：${selection.modelId}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CurrentBadge extends StatelessWidget {
  const _CurrentBadge({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: AppRadius.smallAll,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s,
          vertical: AppSpacing.xs,
        ),
        child: Text(
          '当前',
          key: const ValueKey('assistant-current-badge'),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
        ),
      ),
    );
  }
}
