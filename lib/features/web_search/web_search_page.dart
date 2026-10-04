import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/error/failure.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_bottom_bar.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_icon_badge.dart';
import '../../core/widgets/app_interactive_surface.dart';
import '../../core/widgets/app_loading_indicator.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/app_section.dart';
import '../../core/widgets/app_snack_bar.dart';
import '../../data/models/web_search_settings.dart';
import 'web_search_controller.dart';
import 'web_search_form_widgets.dart';

class WebSearchPage extends ConsumerWidget {
  const WebSearchPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(webSearchControllerProvider)
      .when(
        skipLoadingOnReload: true,
        data: (state) => _WebSearchSettingsView(state: state),
        loading: () => const AppScaffold(
          title: '网页搜索',
          body: Center(child: AppLoadingIndicator()),
        ),
        error: (error, _) => AppScaffold(
          title: '网页搜索',
          body: AppEmptyState(
            icon: LucideIcons.circleAlert,
            title: '暂时无法读取配置',
            message: error is Failure ? error.userMessage : '搜索配置读取失败',
            action: FilledButton.tonalIcon(
              onPressed: () => ref.invalidate(webSearchControllerProvider),
              icon: const Icon(LucideIcons.rotateCw),
              label: const Text('重试'),
            ),
          ),
        ),
      );
}

class _WebSearchSettingsView extends ConsumerStatefulWidget {
  const _WebSearchSettingsView({required this.state});
  final WebSearchState state;

  @override
  ConsumerState<_WebSearchSettingsView> createState() =>
      _WebSearchSettingsViewState();
}

class _WebSearchSettingsViewState
    extends ConsumerState<_WebSearchSettingsView> {
  final _form = GlobalKey<FormState>();
  final _results = TextEditingController();
  bool _dirty = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  @override
  void didUpdateWidget(covariant _WebSearchSettingsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_dirty && !widget.state.busy) _loadOptions();
  }

  void _loadOptions() {
    final settings = widget.state.settings;
    _results.text = '${settings.maxResults}';
  }

  void _changed([String? _]) => setState(() {
    _dirty = true;
    _error = null;
  });

  @override
  void dispose() {
    _results.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (widget.state.busy || !_form.currentState!.validate()) return;
    final settings = widget.state.settings.copyWith(
      searchEnabled: true,
      fetchEnabled: true,
      maxResults: int.parse(_results.text.trim()),
    );
    try {
      await ref
          .read(webSearchControllerProvider.notifier)
          .saveOptions(settings);
      if (!mounted) return;
      setState(() {
        _dirty = false;
        _error = null;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(buildAppSnackBar(content: const Text('搜索设置已保存')));
    } on Failure catch (error) {
      if (mounted) setState(() => _error = error.userMessage);
    } on Object {
      if (mounted) setState(() => _error = '搜索设置保存失败，请重试');
    }
  }

  Future<void> _select(String id) async {
    try {
      if (_dirty && _form.currentState?.validate() == true) {
        final settings = widget.state.settings.copyWith(
          searchEnabled: true,
          fetchEnabled: true,
          maxResults: int.parse(_results.text.trim()),
        );
        await ref
            .read(webSearchControllerProvider.notifier)
            .saveOptions(settings);
        if (mounted) setState(() => _dirty = false);
      }
      await ref.read(webSearchControllerProvider.notifier).select(id);
    } on Failure catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(buildAppSnackBar(content: Text(error.userMessage)));
      }
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(buildAppSnackBar(content: const Text('搜索服务选择失败')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return WebDraftBackGuard(
      dirty: _dirty,
      busy: state.busy,
      child: AppScaffold(
        title: '网页搜索',
        actions: [
          IconButton(
            tooltip: '新增搜索服务',
            onPressed: state.busy
                ? null
                : () => context.push('/settings/web-search/new'),
            icon: const Icon(LucideIcons.plus),
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
                  onPressed: state.busy || !_dirty ? null : _save,
                  icon: state.busy
                      ? const AppLoadingIndicator.small()
                      : Icon(
                          _dirty ? LucideIcons.check : LucideIcons.checkCheck,
                        ),
                  label: Text(
                    state.busy ? '保存中…' : (_dirty ? '保存设置' : '已是最新设置'),
                  ),
                ),
              ),
            ),
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 688),
            child: Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.l,
                  AppSpacing.l,
                  AppSpacing.l,
                  AppSpacing.xxl,
                ),
                children: [
                  AppSection(
                    title: '搜索服务',
                    subtitle: '点击选择默认搜索服务；可通过操作按钮编辑详情',
                    action: TextButton.icon(
                      onPressed: state.busy
                          ? null
                          : () => context.push('/settings/web-search/new'),
                      icon: const Icon(LucideIcons.plus, size: 18),
                      label: const Text('新增服务'),
                    ),
                    child: state.settings.profiles.isEmpty
                        ? AppInteractiveSurface(
                            color: colors.surfaceContainerLow,
                            radius: AppRadius.large,
                            onTap: state.busy
                                ? null
                                : () =>
                                      context.push('/settings/web-search/new'),
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.xl),
                              child: Column(
                                children: [
                                  const AppIconBadge(
                                    icon: LucideIcons.searchX,
                                    tone: AppTone.primary,
                                  ),
                                  const SizedBox(height: AppSpacing.m),
                                  Text(
                                    '尚未配置搜索服务',
                                    style: theme.textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    '添加至少一个搜索服务后即可开启网页检索',
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.l),
                                  FilledButton.tonalIcon(
                                    onPressed: state.busy
                                        ? null
                                        : () => context.push(
                                            '/settings/web-search/new',
                                          ),
                                    icon: const Icon(LucideIcons.plus),
                                    label: const Text('添加搜索服务'),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : Column(
                            children: [
                              for (
                                int i = 0;
                                i < state.settings.profiles.length;
                                i++
                              ) ...[
                                if (i > 0) const SizedBox(height: AppSpacing.s),
                                _ProfileItemCard(
                                  profile: state.settings.profiles[i],
                                  isSelected:
                                      state.settings.profiles[i].id ==
                                      state.settings.selectedProfileId,
                                  busy: state.busy,
                                  onSelect: () =>
                                      _select(state.settings.profiles[i].id),
                                  onEdit: () => context.push(
                                    '/settings/web-search/${state.settings.profiles[i].id}',
                                  ),
                                ),
                              ],
                            ],
                          ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AppSection(
                    title: '搜索参数',
                    subtitle: '控制单次网页搜索向助手返回的来源条数',
                    child: AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                LucideIcons.listOrdered,
                                size: 18,
                                color: colors.primary,
                              ),
                              const SizedBox(width: AppSpacing.s),
                              Text('返回来源数量', style: theme.textTheme.titleSmall),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.m),
                          WebNumberField(
                            controller: _results,
                            label: '返回来源数',
                            helperText: '单次查询返回的最大网页来源条数 (1–20)',
                            suffixText: '条',
                            prefixIcon: LucideIcons.newspaper,
                            minimum: 1,
                            maximum: 20,
                            enabled: !state.busy,
                            onChanged: _changed,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.l),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.m),
                      decoration: BoxDecoration(
                        color: colors.errorContainer,
                        borderRadius: AppRadius.smallAll,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            LucideIcons.circleAlert,
                            color: colors.onErrorContainer,
                            size: 20,
                          ),
                          const SizedBox(width: AppSpacing.m),
                          Expanded(
                            child: Text(
                              _error!,
                              style: TextStyle(color: colors.onErrorContainer),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileItemCard extends StatelessWidget {
  const _ProfileItemCard({
    required this.profile,
    required this.isSelected,
    required this.busy,
    required this.onSelect,
    required this.onEdit,
  });

  final WebSearchProfile profile;
  final bool isSelected;
  final bool busy;
  final VoidCallback onSelect;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final canSelect = !busy && !profile.deleting;

    return Semantics(
      button: true,
      selected: isSelected,
      child: AppInteractiveSurface(
        selected: isSelected,
        color: isSelected
            ? colors.primaryContainer.withValues(alpha: 0.35)
            : colors.surfaceContainerLow,
        radius: AppRadius.large,
        onTap: canSelect ? onSelect : null,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.l),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WebSearchProviderBadge(kind: profile.kind, size: 40),
              const SizedBox(width: AppSpacing.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            profile.name,
                            style: theme.textTheme.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isSelected) ...[
                          const SizedBox(width: AppSpacing.s),
                          const AppBadge(label: '默认', tone: AppTone.teal),
                        ],
                        if (profile.deleting) ...[
                          const SizedBox(width: AppSpacing.s),
                          const AppBadge(label: '删除未完成', tone: AppTone.error),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.s,
                      runSpacing: AppSpacing.xs,
                      children: [
                        Text(
                          profile.kind.label,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        if (profile.resolvedModel.isNotEmpty)
                          Text(
                            '· ${profile.resolvedModel}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      profile.baseUrl.isEmpty ? '内置地址' : profile.baseUrl,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.s),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: '编辑 ${profile.name}',
                    onPressed: busy ? null : onEdit,
                    icon: const Icon(LucideIcons.pencil, size: 20),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  ExcludeSemantics(
                    child: Icon(
                      isSelected ? LucideIcons.circleCheck : LucideIcons.circle,
                      color: isSelected
                          ? colors.primary
                          : colors.onSurfaceVariant.withValues(alpha: 0.45),
                      size: 22,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
