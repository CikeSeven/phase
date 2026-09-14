import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../data/models/assistant.dart';
import '../../../data/models/tool_policy.dart';
import '../tools/tool.dart';
import '../tools/tool_presentation.dart';

/// 编辑的是表单草稿；只有助手表单保存才写入真实策略。
class AssistantToolPolicySection extends StatelessWidget {
  const AssistantToolPolicySection({
    super.key,
    required this.tools,
    required this.policy,
    required this.onChanged,
  });

  final List<Tool> tools;
  final ToolPolicyConfig policy;
  final ValueChanged<ToolPolicyConfig>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('工具范围', style: theme.textTheme.labelLarge),
        const SizedBox(height: AppSpacing.s),
        Text(
          '文件与屏幕读取结果会发送给所选模型。“应用操作”统一控制应用列表、打开、控件与截图观察、点击、滚动、输入和手势组合；实际可用应用受黑白名单限制。',
          style: theme.textTheme.bodySmall,
        ),
        for (final group in const ['文件', '网络', '系统信息', '应用操作']) ...[
          const SizedBox(height: AppSpacing.l),
          Text(group, style: theme.textTheme.labelLarge),
          for (final tool in {
            for (final tool in tools.where((tool) => _group(tool) == group))
              tool.policyKey: tool,
          }.values) ...[
            const SizedBox(height: AppSpacing.m),
            DropdownButtonFormField<ToolPolicy>(
              key: ValueKey('tool-policy-${tool.policyKey}'),
              initialValue: policy.policies[tool.policyKey] ?? ToolPolicy.deny,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: tool.policyKey == applicationOperationsPolicyKey
                    ? '应用操作'
                    : ToolPresentation.toolLabel(tool.name),
              ),
              items: [
                for (final value in ToolPolicy.values)
                  DropdownMenuItem(
                    value: value,
                    child: Text(ToolPresentation.policyLabel(value)),
                  ),
              ],
              onChanged: onChanged == null
                  ? null
                  : (value) {
                      if (value != null) {
                        onChanged!(policy.withPolicy(tool.policyKey, value));
                      }
                    },
            ),
          ],
        ],
      ],
    );
  }

  String _group(Tool tool) => tool.policyKey == applicationOperationsPolicyKey
      ? '应用操作'
      : tool.requiredCapabilities.contains('network')
      ? '网络'
      : tool.requiredCapabilities.contains('system_info')
      ? '系统信息'
      : '文件';
}
