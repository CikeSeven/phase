import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/error/failure.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_list_tile.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../data/repositories/skill_repository.dart';

class SkillsPage extends ConsumerWidget {
  const SkillsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => AppScaffold(
    title: 'Skills',
    actions: [
      IconButton(
        tooltip: '导入 Skill',
        icon: const Icon(Symbols.add),
        onPressed: () => context.push('/settings/extensions/skills/import'),
      ),
    ],
    body: ref
        .watch(skillInstallationsProvider)
        .when(
          loading: () => const Center(child: AppLoadingIndicator()),
          error: (error, _) => AppEmptyState(
            icon: Symbols.error,
            title: '无法读取 Skills',
            message: error is Failure ? error.userMessage : '读取失败，请重试',
            action: TextButton(
              onPressed: () => ref.invalidate(skillInstallationsProvider),
              child: const Text('重试'),
            ),
          ),
          data: (entries) => entries.isEmpty
              ? AppEmptyState(
                  icon: Symbols.auto_stories,
                  title: '还没有 Skills',
                  message: '从目录或 ZIP 导入任务指导，再为助手选择使用范围。',
                  action: FilledButton.icon(
                    onPressed: () =>
                        context.push('/settings/extensions/skills/import'),
                    icon: const Icon(Symbols.add),
                    label: const Text('导入 Skill'),
                  ),
                )
              : ListView.separated(
                  key: const PageStorageKey('skills-list'),
                  padding: const EdgeInsets.all(AppSpacing.l),
                  itemCount: entries.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.s),
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    return AppListTile(
                      title: Text(entry.snapshot.name),
                      subtitle: Text(
                        '${entry.deleting
                            ? '等待清理，可重试删除'
                            : entry.enabled
                            ? '已启用'
                            : '已停用'} · ${entry.snapshot.source}\n${entry.snapshot.description}',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      leading: const Icon(Symbols.auto_stories),
                      trailing: const Icon(Symbols.chevron_right),
                      onTap: () => context.push(
                        '/settings/extensions/skills/${entry.id}',
                      ),
                    );
                  },
                ),
        ),
  );
}
