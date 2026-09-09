import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_icon_badge.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../providers/presets/provider_preset.dart';
import 'provider_ui.dart';

/// 从真实预设注册表中搜索并选择服务商。
class ProviderPresetSheet extends StatefulWidget {
  const ProviderPresetSheet({required this.selectedId, super.key});

  final String selectedId;

  @override
  State<ProviderPresetSheet> createState() => _ProviderPresetSheetState();
}

class _ProviderPresetSheetState extends State<ProviderPresetSheet> {
  final _searchController = TextEditingController();
  bool _closed = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = _searchController.text.trim().toLowerCase();
    final presets = providerPresets.where((preset) {
      return [
        preset.name,
        preset.id,
        preset.baseUrl,
        ProviderUi.protocolLabel(preset.protocol),
      ].any((value) => value.toLowerCase().contains(query));
    }).toList();

    return AppSheet(
      title: '选择服务商',
      child: CustomScrollView(
        key: const ValueKey('preset-scroll'),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.l,
                0,
                AppSpacing.l,
                AppSpacing.l,
              ),
              child: TextField(
                key: const ValueKey('preset-search'),
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: '搜索预设',
                  hintText: '名称或地址',
                  prefixIcon: const Icon(Symbols.search),
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: '清除预设搜索',
                          onPressed: () => setState(_searchController.clear),
                          icon: const Icon(Symbols.close),
                        ),
                ),
              ),
            ),
          ),
          if (presets.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  children: [
                    const Text('没有匹配的预设'),
                    const SizedBox(height: AppSpacing.s),
                    TextButton(
                      onPressed: () => setState(_searchController.clear),
                      child: const Text('显示全部预设'),
                    ),
                  ],
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
              itemCount: presets.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.s),
              itemBuilder: (context, index) {
                final preset = presets[index];
                final selected = preset.id == widget.selectedId;
                return AppCard(
                  key: ValueKey('preset-${preset.id}'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.m,
                    vertical: AppSpacing.s,
                  ),
                  borderRadius: AppRadius.mediumAll,
                  onTap: () {
                    if (_closed) return;
                    _closed = true;
                    Navigator.of(context).pop(preset);
                  },
                  child: Row(
                    children: [
                      AppIconBadge(
                        icon: ProviderUi.icon(preset.id),
                        tone: ProviderUi.tone(preset.id),
                        size: 32,
                        iconSize: 18,
                      ),
                      const SizedBox(width: AppSpacing.m),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              preset.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall,
                            ),
                            Text(
                              // 自定义预设的协议可随意修改，不展示默认协议标签。
                              preset.baseUrl.isEmpty
                                  ? '自定义 API 地址'
                                  : '${ProviderUi.protocolLabel(preset.protocol)} · ${preset.baseUrl}',
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
                      Icon(
                        selected ? Symbols.check_circle : Symbols.chevron_right,
                        color: selected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                        semanticLabel: selected ? '当前预设' : null,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
