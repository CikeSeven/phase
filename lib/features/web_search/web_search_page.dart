import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/error/failure.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_bottom_bar.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_loading_indicator.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/app_snack_bar.dart';
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
  final _queries = TextEditingController();
  final _results = TextEditingController();
  final _searchTimeout = TextEditingController();
  final _fetchTimeout = TextEditingController();
  final _pageSize = TextEditingController();
  bool _searchEnabled = true;
  bool _fetchEnabled = true;
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
    _searchEnabled = settings.searchEnabled;
    _fetchEnabled = settings.fetchEnabled;
    _queries.text = '${settings.maxQueries}';
    _results.text = '${settings.maxResults}';
    _searchTimeout.text = '${settings.searchTimeoutSeconds}';
    _fetchTimeout.text = '${settings.fetchTimeoutSeconds}';
    _pageSize.text = '${settings.maxPageCharacters}';
  }

  void _changed([String? _]) => setState(() {
    _dirty = true;
    _error = null;
  });
  @override
  void dispose() {
    for (final controller in [
      _queries,
      _results,
      _searchTimeout,
      _fetchTimeout,
      _pageSize,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (widget.state.busy || !_form.currentState!.validate()) return;
    final settings = widget.state.settings.copyWith(
      searchEnabled: _searchEnabled,
      fetchEnabled: _fetchEnabled,
      maxQueries: int.parse(_queries.text.trim()),
      maxResults: int.parse(_results.text.trim()),
      searchTimeoutSeconds: int.parse(_searchTimeout.text.trim()),
      fetchTimeoutSeconds: int.parse(_fetchTimeout.text.trim()),
      maxPageCharacters: int.parse(_pageSize.text.trim()),
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
    Widget heading(String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.l),
      child: Text(text, style: theme.textTheme.titleMedium),
    );
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
          child: FilledButton.icon(
            onPressed: state.busy || !_dirty ? null : _save,
            icon: state.busy
                ? const AppLoadingIndicator.small()
                : const Icon(LucideIcons.check),
            label: Text(state.busy ? '保存中…' : '保存设置'),
          ),
        ),
        body: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.l),
            children: [
              SwitchListTile.adaptive(
                title: const Text('网页搜索'),
                value: _searchEnabled,
                onChanged: state.busy
                    ? null
                    : (value) {
                        _searchEnabled = value;
                        _changed();
                      },
              ),
              SwitchListTile.adaptive(
                title: const Text('网页读取'),
                value: _fetchEnabled,
                onChanged: state.busy
                    ? null
                    : (value) {
                        _fetchEnabled = value;
                        _changed();
                      },
              ),
              heading('搜索服务'),
              if (state.settings.profiles.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(AppSpacing.l),
                  child: Text('尚未添加搜索服务'),
                ),
              for (final profile in state.settings.profiles)
                ListTile(
                  selected: profile.id == state.settings.selectedProfileId,
                  leading: Icon(
                    profile.id == state.settings.selectedProfileId
                        ? LucideIcons.circleCheck
                        : LucideIcons.circle,
                  ),
                  title: Text(profile.name),
                  subtitle: Text(
                    '${profile.kind.label} · ${profile.deleting
                        ? '删除未完成'
                        : profile.enabled
                        ? '已启用'
                        : '已停用'}',
                  ),
                  trailing: IconButton(
                    tooltip: '编辑 ${profile.name}',
                    onPressed: state.busy
                        ? null
                        : () => context.push(
                            '/settings/web-search/${profile.id}',
                          ),
                    icon: const Icon(LucideIcons.pencil),
                  ),
                  onTap: state.busy || !profile.enabled || profile.deleting
                      ? null
                      : () => _select(profile.id),
                ),
              heading('搜索与读取上限'),
              WebNumberField(
                controller: _queries,
                label: '单次查询数',
                minimum: 1,
                maximum: 8,
                enabled: !state.busy,
                onChanged: _changed,
              ),
              WebNumberField(
                controller: _results,
                label: '返回来源数',
                minimum: 1,
                maximum: 20,
                enabled: !state.busy,
                onChanged: _changed,
              ),
              WebNumberField(
                controller: _searchTimeout,
                label: '搜索超时（秒）',
                minimum: 5,
                maximum: 180,
                enabled: !state.busy,
                onChanged: _changed,
              ),
              WebNumberField(
                controller: _fetchTimeout,
                label: '网页读取超时（秒）',
                minimum: 5,
                maximum: 180,
                enabled: !state.busy,
                onChanged: _changed,
              ),
              WebNumberField(
                controller: _pageSize,
                label: '网页正文字符上限',
                minimum: 1024,
                maximum: 100000,
                enabled: !state.busy,
                onChanged: _changed,
              ),
              if (_error != null)
                Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
          ),
        ),
      ),
    );
  }
}
