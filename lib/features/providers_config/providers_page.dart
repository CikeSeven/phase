import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../core/error/failure.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/repositories/provider_profile_repository.dart';

/// 服务商配置列表页（`/settings/providers`）。
class ProvidersPage extends ConsumerWidget {
  const ProvidersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profilesAsync = ref.watch(providerProfilesProvider);
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('服务商配置')),
      floatingActionButton: FloatingActionButton(
        tooltip: '新增服务商',
        onPressed: () => context.push('/settings/providers/new'),
        child: const Icon(Symbols.add),
      ),
      body: profilesAsync.when(
        data: (profiles) {
          if (profiles.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Symbols.cloud,
                    size: 48,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: AppSpacing.l),
                  Text(
                    '还没有服务商，点击右下角添加',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s,
              AppSpacing.l,
              AppSpacing.s,
              AppSpacing.xxl,
            ),
            itemCount: profiles.length,
            separatorBuilder: (context, index) =>
                const SizedBox(height: AppSpacing.s),
            itemBuilder: (context, index) {
              final profile = profiles[index];
              return Material(
                type: MaterialType.transparency,
                child: ListTile(
                  leading: const Icon(Symbols.cloud),
                  title: Text(profile.name),
                  subtitle: Text(
                    profile.baseUrl,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Symbols.chevron_right),
                  onTap: () =>
                      context.push('/settings/providers/${profile.id}'),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(error is Failure ? error.userMessage : '加载服务商配置失败'),
        ),
      ),
    );
  }
}
