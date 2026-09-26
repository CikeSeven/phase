import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_bottom_bar.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_snack_bar.dart';
import 'skill_controller.dart';

class SkillImportPage extends ConsumerWidget {
  const SkillImportPage({super.key, this.replaceId});
  final String? replaceId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = skillImportControllerProvider(replaceId);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    final package = state.package;
    final previous = replaceId == null
        ? null
        : ref
              .watch(skillControllerProvider(replaceId!))
              .asData
              ?.value
              ?.snapshot;
    return AppScaffold(
      title: replaceId == null ? '导入 Skill' : '更新 Skill',
      bottomBar: package == null
          ? null
          : AppBottomBar(
              child: FilledButton.icon(
                key: const ValueKey('install-skill'),
                onPressed: state.busy
                    ? null
                    : () async {
                        final installed = await controller.install();
                        if (!context.mounted || installed == null) return;
                        final error = ref.read(provider).error;
                        ScaffoldMessenger.of(context).showSnackBar(
                          buildAppSnackBar(
                            content: Text(error ?? '已安装，请在助手中选择使用范围'),
                          ),
                        );
                        context.pop();
                      },
                icon: state.busy
                    ? const AppLoadingIndicator.small()
                    : const Icon(Symbols.check),
                label: Text(replaceId == null ? '安装' : '更新版本'),
              ),
            ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.l),
        children: [
          Text(
            '选择包含 SKILL.md 的目录或 ZIP。导入后保留独立副本，安装不会执行脚本。',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: AppSpacing.l),
          Wrap(
            spacing: AppSpacing.m,
            runSpacing: AppSpacing.s,
            children: [
              FilledButton.tonalIcon(
                key: const ValueKey('pick-skill-zip'),
                onPressed: state.busy ? null : () => controller.pick(true),
                icon: const Icon(Symbols.folder_zip),
                label: const Text('选择 ZIP'),
              ),
              OutlinedButton.icon(
                key: const ValueKey('pick-skill-directory'),
                onPressed: state.busy ? null : () => controller.pick(false),
                icon: const Icon(Symbols.folder_open),
                label: const Text('选择目录'),
              ),
            ],
          ),
          if (state.busy) ...[
            const SizedBox(height: AppSpacing.l),
            const Align(
              alignment: Alignment.centerLeft,
              child: AppLoadingIndicator.small(),
            ),
            Text(state.phase),
            TextButton(onPressed: controller.cancel, child: const Text('取消导入')),
          ] else if (state.phase.isNotEmpty && package == null)
            Text(state.phase),
          if (state.error != null) ...[
            const SizedBox(height: AppSpacing.l),
            Text(
              state.error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if (package != null) ...[
            const SizedBox(height: AppSpacing.xl),
            Text(package.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.s),
            Text(package.description),
            const SizedBox(height: AppSpacing.l),
            Text(package.source),
            Text(
              '${package.resources.length} 个文件 · ${(package.resources.values.fold<int>(0, (n, r) => n + r.size) / 1024).toStringAsFixed(1)} KiB',
            ),
            Text('版本 ${package.revision.substring(0, 12)}'),
            if (package.ignoredFields.isNotEmpty)
              Text('未使用的元数据字段：${package.ignoredFields.join('、')}'),
            if (previous != null) ...[
              const SizedBox(height: AppSpacing.l),
              const Text('更新用于新任务，正在运行的任务继续使用原版本。'),
              Text(
                '新增 ${package.resources.keys.where((k) => !previous.resources.containsKey(k)).length} · 修改 ${package.resources.entries.where((e) => previous.resources.containsKey(e.key) && previous.resources[e.key]!.digest != e.value.digest).length} · 删除 ${previous.resources.keys.where((k) => !package.resources.containsKey(k)).length} 个文件',
              ),
            ],
            const SizedBox(height: AppSpacing.l),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('包内文件'),
              children: [
                for (final path in package.resources.keys.toList()..sort())
                  ListTile(dense: true, title: Text(path)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
