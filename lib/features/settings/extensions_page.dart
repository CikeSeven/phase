import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_spacing.dart';
import '../../core/widgets/app_card_dialog.dart';
import '../../../core/widgets/app_list_tile.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../core/widgets/settings_list_item.dart';
import '../../data/models/media_generation.dart';
import '../../data/repositories/image_generation_repository.dart';
import '../../data/repositories/media_generation_repository.dart';
import '../../data/repositories/video_generation_repository.dart';
import '../media_generation/media_generation_settings_dialog.dart';

class ExtensionsPage extends ConsumerWidget {
  const ExtensionsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => AppScaffold(
    title: '扩展',
    body: SettingsListView(
      padding: const EdgeInsets.all(AppSpacing.l),
      children: [
        _generationTile(
          context,
          MediaGenerationKind.image,
          LucideIcons.image,
          '为聊天指定图像模型',
          () => ref.read(imageGenerationRepositoryProvider),
        ),
        const SizedBox(height: AppSpacing.m),
        _generationTile(
          context,
          MediaGenerationKind.video,
          LucideIcons.video,
          '配置视频模型和接口参数',
          () => ref.read(videoGenerationRepositoryProvider),
        ),
        const SizedBox(height: AppSpacing.m),
        AppListTile(
          dialogTag: '/settings/extensions/mcp',
          leading: const Icon(LucideIcons.puzzle),
          title: const Text('MCP 服务'),
          subtitle: const Text('连接远程工具，为助手选择使用范围'),
          trailing: const Icon(LucideIcons.chevronRight),
          onTap: () => context.push('/settings/extensions/mcp'),
        ),
        const SizedBox(height: AppSpacing.m),
        AppListTile(
          dialogTag: '/settings/extensions/skills',
          leading: const Icon(LucideIcons.bookOpen),
          title: const Text('Skills'),
          subtitle: const Text('导入任务指导与资源，按需读取'),
          trailing: const Icon(LucideIcons.chevronRight),
          onTap: () => context.push('/settings/extensions/skills'),
        ),
      ],
    ),
  );

  Widget _generationTile(
    BuildContext context,
    MediaGenerationKind kind,
    IconData icon,
    String subtitle,
    MediaGenerationRepository Function() readRepository,
  ) => AppListTile(
    dialogTag: kind,
    leading: Icon(icon),
    title: Text(kind.label),
    subtitle: Text(subtitle),
    trailing: const Icon(LucideIcons.chevronRight),
    onTap: () {
      final repository = readRepository();
      Navigator.of(context).push<void>(
        AppCardDialogRoute<void>(
          context: context,
          tag: kind,
          builder: (_) => MediaGenerationSettingsDialog(repository: repository),
        ),
      );
    },
  );
}
