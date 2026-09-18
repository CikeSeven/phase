import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_dropdown.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../../data/models/assistant.dart';
import '../../../data/models/tool_policy.dart';
import '../../../data/repositories/mcp_server_repository.dart';

/// 只编辑助手草稿；新增工具默认关闭，启用时默认询问。
class AssistantMcpSection extends ConsumerWidget {
  const AssistantMcpSection({
    super.key,
    required this.policy,
    required this.onChanged,
  });
  final ToolPolicyConfig policy;
  final ValueChanged<ToolPolicyConfig>? onChanged;

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
                      value:
                          (policy.policies[tool.name] ?? ToolPolicy.deny) !=
                          ToolPolicy.deny,
                      onChanged: onChanged == null || entry.profile.deleting
                          ? null
                          : (enabled) => onChanged!(
                              policy.withPolicy(
                                tool.name,
                                enabled ? ToolPolicy.ask : ToolPolicy.deny,
                              ),
                            ),
                    ),
                    if ((policy.policies[tool.name] ?? ToolPolicy.deny) !=
                        ToolPolicy.deny)
                      AppDropdown<ToolPolicy>(
                        value: policy.policies[tool.name]!,
                        label: '执行策略',
                        options: const {
                          ToolPolicy.ask: '每次询问',
                          ToolPolicy.allow: '直接允许',
                        },
                        onChanged: onChanged == null
                            ? null
                            : (value) => onChanged!(
                                policy.withPolicy(tool.name, value),
                              ),
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
