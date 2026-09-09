import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/error/failure.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../core/widgets/app_bottom_bar.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_icon_badge.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../data/models/provider_profile.dart';
import '../../../data/repositories/provider_profile_repository.dart';
import '../../../providers/presets/provider_preset.dart';
import 'provider_ui.dart';

/// 服务商配置总览（`/settings/providers`），仅展示本机配置中的真实数量。
class ProvidersPage extends ConsumerStatefulWidget {
  const ProvidersPage({super.key});

  @override
  ConsumerState<ProvidersPage> createState() => _ProvidersPageState();
}

class _ProvidersPageState extends ConsumerState<ProvidersPage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _addProvider() => context.push('/settings/providers/new');

  @override
  Widget build(BuildContext context) {
    final profilesAsync = ref.watch(providerProfilesProvider);
    return AppScaffold(
      title: '服务商',
      subtitle: '管理连接与模型',
      actions: [
        IconButton(
          tooltip: '新增服务商',
          onPressed: _addProvider,
          icon: const Icon(Symbols.add),
        ),
      ],
      bottomBar: AppBottomBar(
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 688),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const ValueKey('add-provider'),
                onPressed: _addProvider,
                icon: const Icon(Symbols.add),
                label: const Text('新增服务商'),
              ),
            ),
          ),
        ),
      ),
      body: profilesAsync.when(
        skipLoadingOnReload: true,
        data: (profiles) => profiles.isEmpty
            ? AppEmptyState(
                icon: Symbols.hub,
                tone: AppTone.teal,
                title: '连接你的第一个服务商',
                message: '选择预设或填入自己的 API 地址，让喜欢的模型在这里汇合。',
                action: OutlinedButton.icon(
                  onPressed: _addProvider,
                  icon: const Icon(Symbols.add),
                  label: const Text('添加第一个服务商'),
                ),
              )
            : _buildProfiles(profiles),
        loading: () => const AppEmptyState(
          icon: Symbols.cloud_download,
          tone: AppTone.teal,
          title: '正在读取配置',
          message: '正在加载本机服务商与模型列表，也可以先添加新的服务商。',
          action: SizedBox(width: 160, child: LinearProgressIndicator()),
        ),
        error: (error, _) => AppEmptyState(
          icon: Symbols.cloud_off,
          title: '暂时无法读取服务商',
          message: error is Failure ? error.userMessage : '加载本机配置失败，请重试。',
          action: FilledButton.tonalIcon(
            onPressed: () => ref.invalidate(providerProfilesProvider),
            icon: const Icon(Symbols.refresh),
            label: const Text('重新加载'),
          ),
        ),
      ),
    );
  }

  Widget _buildProfiles(List<ProviderProfile> profiles) {
    final theme = Theme.of(context);
    final query = _searchController.text.trim().toLowerCase();
    final filtered = profiles.where((profile) {
      return [
        profile.name,
        profile.baseUrl,
        presetById(profile.presetId).name,
        ProviderUi.protocolLabel(profile.protocol),
        ...profile.modelCandidates.map((model) => model.id),
      ].any((value) => value.toLowerCase().contains(query));
    }).toList();
    final modelCount = profiles.fold<int>(
      0,
      (count, profile) =>
          count +
          profile.modelCandidates.map((model) => model.id).toSet().length,
    );
    return CustomScrollView(
      key: const ValueKey('providers-scroll'),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppCard(
                  tint: context.brandColors.teal,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('你的模型入口', style: theme.textTheme.titleMedium),
                      const SizedBox(height: AppSpacing.l),
                      Wrap(
                        spacing: AppSpacing.xxl,
                        runSpacing: AppSpacing.l,
                        children: [
                          _OverviewCount(value: profiles.length, label: '服务商'),
                          _OverviewCount(value: modelCount, label: '已配置模型'),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.l),
                      Text(
                        '这里记录你的本机配置，连接状态以实际请求为准。',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                TextField(
                  key: const ValueKey('provider-search'),
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: '搜索服务商',
                    hintText: '名称、协议、地址或模型',
                    prefixIcon: const Icon(Symbols.search),
                    suffixIcon: query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: '清除服务商搜索',
                            onPressed: () => setState(_searchController.clear),
                            icon: const Icon(Symbols.close),
                          ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  query.isEmpty ? '已添加' : '搜索结果 · ${filtered.length}',
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ),
        if (filtered.isEmpty)
          SliverToBoxAdapter(
            child: AppEmptyState(
              icon: Symbols.search_off,
              title: '没有匹配的服务商',
              message: '换一个关键词，或添加新的服务商。',
              action: TextButton(
                onPressed: () => setState(_searchController.clear),
                child: const Text('显示全部服务商'),
              ),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.l,
            0,
            AppSpacing.l,
            AppSpacing.xl,
          ),
          sliver: SliverList.separated(
            itemCount: filtered.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.m),
            itemBuilder: (context, index) => _ProfileCard(
              profile: filtered[index],
              onTap: () =>
                  context.push('/settings/providers/${filtered[index].id}'),
            ),
          ),
        ),
      ],
    );
  }
}

class _OverviewCount extends StatelessWidget {
  const _OverviewCount({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$value', style: theme.textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.profile, required this.onTap});

  final ProviderProfile profile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = profile.modelCandidates
        .map((model) => model.id)
        .toSet()
        .length;
    return AppCard(
      key: ValueKey('provider-${profile.id}'),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AppIconBadge(
                icon: ProviderUi.icon(profile.presetId),
                tone: ProviderUi.tone(profile.presetId),
              ),
              const SizedBox(width: AppSpacing.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      presetById(profile.presetId).name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.s),
              const Icon(Symbols.chevron_right),
            ],
          ),
          const SizedBox(height: AppSpacing.l),
          Wrap(
            spacing: AppSpacing.s,
            runSpacing: AppSpacing.s,
            children: [
              AppBadge(label: ProviderUi.protocolLabel(profile.protocol)),
              AppBadge(label: '$count 个模型', tone: AppTone.teal),
            ],
          ),
          const SizedBox(height: AppSpacing.l),
          Text(
            '默认模型',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            profile.defaultModel ?? (count == 0 ? '暂未设置' : '未指定，将使用列表首项'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.m),
          Text(
            profile.baseUrl,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
