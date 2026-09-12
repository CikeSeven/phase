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
          '读取范围仅限当前会话的附件与产物；读取结果会发送给所选模型。允许一次只批准当前动作，不改变这里的策略。',
          style: theme.textTheme.bodySmall,
        ),
        for (final group in const ['文件', '网络', '系统信息']) ...[
          const SizedBox(height: AppSpacing.l),
          Text(group, style: theme.textTheme.labelLarge),
          for (final tool in tools.where((tool) => _group(tool) == group)) ...[
            const SizedBox(height: AppSpacing.m),
            DropdownButtonFormField<ToolPolicy>(
              key: ValueKey('tool-policy-${tool.name}'),
              initialValue: policy.policies[tool.name] ?? ToolPolicy.deny,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: ToolPresentation.toolLabel(tool.name),
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
                        onChanged!(policy.withPolicy(tool.name, value));
                      }
                    },
            ),
          ],
        ],
      ],
    );
  }

  String _group(Tool tool) => tool.requiredCapabilities.contains('network')
      ? '网络'
      : tool.requiredCapabilities.contains('system_info')
      ? '系统信息'
      : '文件';
}
