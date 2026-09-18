import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_dropdown.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../../data/models/tool_policy.dart';
import '../../../data/repositories/skill_repository.dart';

class AssistantSkillsSection extends ConsumerWidget {
  const AssistantSkillsSection({
    super.key,
    required this.ids,
    required this.policy,
    required this.onChanged,
    required this.onPolicyChanged,
  });
  final Set<String> ids;
  final ToolPolicy policy;
  final ValueChanged<Set<String>>? onChanged;
  final ValueChanged<ToolPolicy>? onPolicyChanged;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Skills', style: Theme.of(context).textTheme.labelLarge),
      const SizedBox(height: AppSpacing.s),
      ref
          .watch(skillInstallationsProvider)
          .when(
            loading: () => const AppLoadingIndicator.small(),
            error: (_, _) => TextButton(
              onPressed: () => ref.invalidate(skillInstallationsProvider),
              child: const Text('Skill 列表读取失败，点击重试'),
            ),
            data: (entries) => Column(
              children: [
                if (entries.where((e) => !e.deleting).isEmpty)
                  const Text('导入 Skill 后，可在这里为助手选择任务指导。'),
                for (final entry in entries.where((e) => !e.deleting))
                  SwitchListTile.adaptive(
                    key: ValueKey('skill-enable-${entry.id}'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(entry.snapshot.name),
                    subtitle: Text(
                      entry.enabled ? entry.snapshot.description : '已在扩展管理中停用',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    value: ids.contains(entry.id),
                    onChanged: onChanged == null
                        ? null
                        : (enabled) => onChanged!({
                            for (final id in ids)
                              if (enabled || id != entry.id) id,
                            if (enabled) entry.id,
                          }),
                  ),
              ],
            ),
          ),
      if (ids.isNotEmpty) ...[
        const SizedBox(height: AppSpacing.s),
        AppDropdown<ToolPolicy>(
          value: policy,
          label: '读取指导与资源',
          options: const {
            ToolPolicy.ask: '每次询问',
            ToolPolicy.allow: '直接允许',
            ToolPolicy.deny: '禁止读取',
          },
          onChanged: onPolicyChanged,
        ),
      ],
      TextButton(
        onPressed: onChanged == null
            ? null
            : () => context.push('/settings/extensions/skills'),
        child: const Text('管理 Skills'),
      ),
    ],
  );
}
