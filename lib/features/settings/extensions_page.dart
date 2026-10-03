import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_list_tile.dart';
import '../../../core/widgets/app_scaffold.dart';

class ExtensionsPage extends StatelessWidget {
  const ExtensionsPage({super.key});
  @override
  Widget build(BuildContext context) => AppScaffold(
    title: '扩展',
    body: ListView(
      padding: const EdgeInsets.all(AppSpacing.l),
      children: [
        AppListTile(
          leading: const Icon(LucideIcons.puzzle),
          title: const Text('MCP 服务'),
          subtitle: const Text('连接远程工具，为助手选择使用范围'),
          trailing: const Icon(LucideIcons.chevronRight),
          onTap: () => context.push('/settings/extensions/mcp'),
        ),
        const SizedBox(height: AppSpacing.m),
        AppListTile(
          leading: const Icon(LucideIcons.bookOpen),
          title: const Text('Skills'),
          subtitle: const Text('导入任务指导与资源，按需读取'),
          trailing: const Icon(LucideIcons.chevronRight),
          onTap: () => context.push('/settings/extensions/skills'),
        ),
      ],
    ),
  );
}
