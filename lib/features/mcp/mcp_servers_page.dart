import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/error/failure.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../data/repositories/mcp_server_repository.dart';

class McpServersPage extends ConsumerWidget {
  const McpServersPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servers = ref.watch(mcpServersProvider);
    return AppScaffold(
      title: 'MCP 服务',
      actions: [
        IconButton(
          tooltip: '新增 MCP 服务',
          icon: const Icon(Symbols.add),
          onPressed: () => context.push('/settings/extensions/mcp/new'),
        ),
      ],
      body: servers.when(
        loading: () => const Center(child: AppLoadingIndicator()),
        error: (error, _) => AppEmptyState(
          icon: Symbols.error,
          title: '无法读取 MCP 服务',
          message: error is Failure ? error.userMessage : '读取失败，请重试',
          action: FilledButton.tonal(
            onPressed: () => ref.invalidate(mcpServersProvider),
            child: const Text('重试'),
          ),
        ),
        data: (entries) => entries.isEmpty
            ? AppEmptyState(
                icon: Symbols.extension,
                title: '还没有 MCP 服务',
                message: '添加 Streamable HTTP 服务，发现工具后在助手中启用。',
                action: FilledButton.icon(
                  icon: const Icon(Symbols.add),
                  label: const Text('添加服务'),
                  onPressed: () => context.push('/settings/extensions/mcp/new'),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.l),
                children: [
                  for (final entry in entries)
                    ListTile(
                      title: Text(
                        entry.profile.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      leading: Icon(
                        entry.profile.enabled
                            ? Symbols.extension
                            : Symbols.extension_off,
                      ),
                      subtitle: Text(
                        entry.profile.deleting
                            ? '凭据清理未完成，请重试删除'
                            : '${entry.profile.enabled ? "已启用" : "已禁用"} · '
                                  '${entry.protocolVersion == null ? "尚未检查连接" : "已发现 ${entry.tools.length} 个工具"}',
                      ),
                      trailing: const Icon(Symbols.chevron_right),
                      onTap: () => context.push(
                        '/settings/extensions/mcp/${entry.profile.id}',
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
