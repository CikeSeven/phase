import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/error/failure.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_bottom_bar.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_icon_badge.dart';
import '../../../core/widgets/app_interactive_surface.dart';
import '../../../core/widgets/app_loading_indicator.dart';
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
            ? _buildStatus(icon: Symbols.hub, title: '暂无服务商')
            : _buildProfiles(profiles),
        loading: () => _buildStatus(
          title: '正在读取配置',
          action: const AppLoadingIndicator(semanticsLabel: '正在读取服务商'),
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

  Widget _buildStatus({required String title, Widget? action, IconData? icon}) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              AppIconBadge(icon: icon, tone: AppTone.teal),
              const SizedBox(height: AppSpacing.l),
            ],
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (action != null) ...[
              const SizedBox(height: AppSpacing.l),
              action,
            ],
          ],
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
        ...profile.models.map((model) => model.id),
        // 列表外的默认模型也要能搜到。
        ?profile.defaultModel,
      ].any((value) => value.toLowerCase().contains(query));
    }).toList();
    // 模型数按 id 去重后统计，包含列表外的默认模型。
    final modelCount = profiles.fold<int>(
      0,
      (count, profile) =>
          count +
          profile.models.map((model) => model.id).toSet().length +
          (profile.defaultModel != null &&
                  profile.models.every(
                    (model) => model.id != profile.defaultModel,
                  )
              ? 1
              : 0),
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
                  query.isEmpty
                      ? '${profiles.length} 个服务商 · $modelCount 个模型'
                      : '搜索结果 · ${filtered.length} 个服务商',
                  key: const ValueKey('provider-counts'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (filtered.isEmpty)
          SliverToBoxAdapter(
            child: _buildStatus(
              icon: Symbols.search_off,
              title: '没有匹配的服务商',
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
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.s),
            itemBuilder: (context, index) => _ProfileRow(
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

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.profile, required this.onTap});

  final ProviderProfile profile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count =
        profile.models.map((model) => model.id).toSet().length +
        (profile.defaultModel != null &&
                profile.models.every(
                  (model) => model.id != profile.defaultModel,
                )
            ? 1
            : 0);
    final secondaryStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Semantics(
      button: true,
      child: AppInteractiveSurface(
        color: theme.colorScheme.surfaceContainerLow,
        key: ValueKey('provider-${profile.id}'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s,
            vertical: AppSpacing.l,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppIconBadge(
                icon: ProviderUi.icon(profile.presetId),
                tone: AppTone.teal,
                size: 40,
                iconSize: 22,
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
                    Wrap(
                      spacing: AppSpacing.s,
                      runSpacing: AppSpacing.xs,
                      children: [
                        Text(
                          ProviderUi.protocolLabel(profile.protocol),
                          style: secondaryStyle,
                        ),
                        Text('$count 个模型', style: secondaryStyle),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      profile.baseUrl,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: secondaryStyle,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.s),
              ExcludeSemantics(
                child: Icon(
                  Symbols.chevron_right,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
