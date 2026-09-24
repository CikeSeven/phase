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
    required this.names,
    required this.onChanged,
  });
  final Set<String> names;
  final ValueChanged<Set<String>>? onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('MCP 工具', style: Theme.of(context).textTheme.labelLarge),
      const SizedBox(height: AppSpacing.s),
      ref
          .watch(mcpServersProvider)
          .when(
            loading: () => const AppLoadingIndicator.small(),
            error: (_, _) => TextButton(
              onPressed: () => ref.invalidate(mcpServersProvider),
              child: const Text('工具目录读取失败，点击重试'),
            ),
            data: (servers) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (servers.isEmpty) const Text('添加 MCP 服务并检查连接后，可在这里启用工具。'),
                for (final entry in servers) ...[
                  const SizedBox(height: AppSpacing.m),
                  Text(
                    '${entry.profile.name}${entry.profile.enabled ? "" : "（已禁用）"}',
                  ),
                  if (entry.tools.isEmpty) const Text('尚无工具，请在服务详情中检查连接。'),
                  for (final tool in entry.tools) ...[
                    SwitchListTile.adaptive(
                      key: ValueKey('mcp-enable-${tool.name}'),
                      contentPadding: EdgeInsets.zero,
                      title: Text(tool.source.originalName),
                      subtitle: tool.description.isEmpty
                          ? null
                          : Text(
                              tool.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                      value: names.contains(tool.name),
                      onChanged: onChanged == null || entry.profile.deleting
                          ? null
                          : (enabled) => onChanged!({
                              for (final name in names)
                                if (enabled || name != tool.name) name,
                              if (enabled) tool.name,
                            }),
                    ),
                  ],
                ],
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
