import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../../data/repositories/mcp_server_repository.dart';

/// 只编辑助手的扩展启用草稿；执行策略由会话模式决定。
class AssistantMcpSection extends ConsumerWidget {
  const AssistantMcpSection({
    super.key,
    required this.serverIds,
    required this.onChanged,
  });
  final Set<String> serverIds;
  final ValueChanged<Set<String>>? onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('MCP 服务', style: Theme.of(context).textTheme.labelLarge),
      const SizedBox(height: AppSpacing.s),
      ref
          .watch(mcpServersProvider)
          .when(
            loading: () => const AppLoadingIndicator.small(),
            error: (_, _) => TextButton(
              onPressed: () => ref.invalidate(mcpServersProvider),
              child: const Text('MCP 服务读取失败，点击重试'),
            ),
            data: (servers) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (servers.isEmpty) const Text('尚未添加 MCP 服务'),
                for (final entry in servers)
                  SwitchListTile.adaptive(
                    key: ValueKey('mcp-enable-${entry.profile.id}'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(entry.profile.name),
                    subtitle: Text(
                      entry.profile.deleting
                          ? '正在删除'
                          : !entry.profile.enabled
                          ? '已禁用'
                          : entry.tools.isEmpty
                          ? '尚无工具'
                          : '${entry.tools.length} 个工具',
                    ),
                    value: serverIds.contains(entry.profile.id),
                    onChanged: onChanged == null || entry.profile.deleting
                        ? null
                        : (enabled) => onChanged!({
                            for (final id in serverIds)
                              if (enabled || id != entry.profile.id) id,
                            if (enabled) entry.profile.id,
                          }),
                  ),
              ],
            ),
          ),
      TextButton(
        onPressed: onChanged == null
            ? null
            : () => context.push('/settings/extensions/mcp'),
        child: const Text('管理 MCP 服务'),
      ),
    ],
  );
}
