import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/error/failure.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_list_tile.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../../core/widgets/app_scaffold.dart';
import 'skill_controller.dart';

class SkillDetailPage extends ConsumerStatefulWidget {
  const SkillDetailPage({super.key, required this.id});
  final String id;
  @override
  ConsumerState<SkillDetailPage> createState() => _SkillDetailPageState();
}

class _SkillDetailPageState extends ConsumerState<SkillDetailPage> {
  bool _busy = false;
  Future<void> _operate(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error is Failure ? error.userMessage : '操作失败，请重试'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AppDialog(
        title: '删除 Skill',
        description: '从助手范围中移除并立即停止后续读取。任务引用的版本会在任务结束后清理；已有聊天和产物保留。',
        content: const SizedBox.shrink(),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    await _operate(() async {
      await ref.read(skillControllerProvider(widget.id).notifier).delete();
      if (mounted) context.pop();
    });
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: 'Skill 详情',
    body: ref
        .watch(skillControllerProvider(widget.id))
        .when(
          loading: () => const Center(child: AppLoadingIndicator()),
          error: (error, _) => AppEmptyState(
            icon: Symbols.error,
            title: '无法读取 Skill',
            message: error is Failure ? error.userMessage : '读取失败',
            action: TextButton(
              onPressed: () =>
                  ref.invalidate(skillControllerProvider(widget.id)),
              child: const Text('重试'),
            ),
          ),
          data: (entry) {
            if (entry == null) {
              return const AppEmptyState(
                icon: Symbols.auto_stories,
                title: 'Skill 已不存在',
                message: '请返回 Skills 列表。',
              );
            }
            final skill = entry.snapshot;
            return ListView(
              key: PageStorageKey('skill-${widget.id}'),
              padding: const EdgeInsets.all(AppSpacing.l),
              children: [
                Text(skill.name, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: AppSpacing.s),
                Text(skill.description),
                const SizedBox(height: AppSpacing.l),
                Text(skill.source),
                Text(
                  '版本 ${skill.revision.substring(0, 12)} · ${skill.resources.length} 个文件 · ${(skill.size / 1024).toStringAsFixed(1)} KiB',
                ),
                if (skill.ignoredFields.isNotEmpty)
                  Text('未使用的元数据字段：${skill.ignoredFields.join('、')}'),
                const SizedBox(height: AppSpacing.l),
                SwitchListTile.adaptive(
                  key: const ValueKey('skill-global-enabled'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('启用 Skill'),
                  subtitle: const Text('助手仍需单独选择；停用后立即停止后续读取'),
                  value: entry.enabled,
                  onChanged: _busy || entry.deleting
                      ? null
                      : (value) => _operate(
                          () => ref
                              .read(skillControllerProvider(widget.id).notifier)
                              .setEnabled(value),
                        ),
                ),
                if (entry.deleting) const Text('已停止读取，文件等待任务结束后清理。可重试删除。'),
                Wrap(
                  spacing: AppSpacing.m,
                  runSpacing: AppSpacing.s,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _busy || entry.deleting
                          ? null
                          : () => context.push(
                              '/settings/extensions/skills/${widget.id}/update',
                            ),
                      icon: const Icon(Symbols.upgrade),
                      label: const Text('更新版本'),
                    ),
                    TextButton.icon(
                      onPressed: _busy ? null : _delete,
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                      ),
                      icon: const Icon(Symbols.delete),
                      label: Text(entry.deleting ? '重试删除' : '删除'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                Text('指导与资源', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.s),
                for (final path in skill.resources.keys.toList()..sort()) ...[
                  AppListTile(
                    title: Text(path),
                    subtitle: Text('${skill.resources[path]!.size} 字节'),
                    trailing: const Icon(Symbols.chevron_right),
                    onTap: entry.deleting
                        ? null
                        : () => context.push(
                            Uri(
                              path:
                                  '/settings/extensions/skills/${widget.id}/resource',
                              queryParameters: {'path': path},
                            ).toString(),
                          ),
                  ),
                  const SizedBox(height: AppSpacing.s),
                ],
              ],
            );
          },
        ),
  );
}
