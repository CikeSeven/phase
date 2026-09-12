import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/error/failure.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../data/models/assistant.dart';
import '../chat/chat_controller.dart';

/// 会话内切换助手；选中后立即作用于当前会话（新会话则作用于下一条消息）。
Future<void> showAssistantPickerSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const _AssistantPickerSheet(),
  );
}

class _AssistantPickerSheet extends ConsumerWidget {
  const _AssistantPickerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assistants =
        ref.watch(assistantsProvider).value ?? const <Assistant>[];
    final current = ref.watch(
      currentAssistantProvider(ref.watch(activeConversationProvider)),
    );

    return AppSheet(
      title: '助手',
      subtitle: '决定本次会话的系统提示词与默认模型',
      titleTrailing: current == null ? null : Text(current.name),
      footer: TextButton.icon(
        key: const ValueKey('manage-assistants'),
        onPressed: () {
          Navigator.of(context).pop();
          context.push('/assistants');
        },
        icon: const Icon(Symbols.tune, size: 18),
        label: const Text('管理助手'),
      ),
      child: ListView.builder(
        key: const ValueKey('assistant-options'),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
        itemCount: assistants.length,
        itemBuilder: (context, index) {
          final assistant = assistants[index];
          return _AssistantOption(
            assistant: assistant,
            selected: assistant.id == current?.id,
            onTap: () async {
              final messenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(context);
              try {
                await ref
                    .read(chatControllerProvider.notifier)
                    .selectAssistant(assistant.id);
              } on Failure catch (error) {
                messenger.showSnackBar(
                  SnackBar(content: Text(error.userMessage)),
                );
                return;
              }
              navigator.pop();
            },
          );
        },
      ),
    );
  }
}

class _AssistantOption extends StatelessWidget {
  const _AssistantOption({
    required this.assistant,
    required this.selected,
    required this.onTap,
  });

  final Assistant assistant;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final prompt = assistant.systemPrompt.trim();
    return Semantics(
      button: true,
      selected: selected,
      label: assistant.name,
      child: Material(
        key: ValueKey('assistant-option-${assistant.id}'),
        color: selected
            ? colors.primaryContainer.withValues(alpha: 0.72)
            : colors.surface.withValues(alpha: 0),
        borderRadius: AppRadius.mediumAll,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: AppRadius.mediumAll,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.m,
              vertical: AppSpacing.m,
            ),
            child: Row(
              children: [
                Icon(
                  selected ? Symbols.check_circle : Symbols.circle,
                  size: 20,
                  color: selected
                      ? colors.primary
                      : colors.onSurfaceVariant.withValues(alpha: 0.4),
                ),
                const SizedBox(width: AppSpacing.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        assistant.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge,
                      ),
                      Text(
                        prompt.isEmpty ? '未设置系统提示词' : prompt,
                        maxLines: 2,
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
      ),
    );
  }
}
