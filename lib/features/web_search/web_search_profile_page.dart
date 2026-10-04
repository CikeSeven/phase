import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/error/failure.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/id.dart';
import '../../core/widgets/app_bottom_bar.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/app_dropdown.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_icon_badge.dart';
import '../../core/widgets/app_loading_indicator.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../data/models/web_search_settings.dart';
import '../tools/tool.dart';
import 'web_search_controller.dart';
import 'web_search_form_widgets.dart';

class WebSearchProfilePage extends ConsumerStatefulWidget {
  const WebSearchProfilePage({this.profileId, super.key});
  final String? profileId;
  @override
  ConsumerState<WebSearchProfilePage> createState() =>
      _WebSearchProfilePageState();
}

class _WebSearchProfilePageState extends ConsumerState<WebSearchProfilePage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _endpoint = TextEditingController();
  final _apiKey = TextEditingController();
  final _model = TextEditingController();
  final _region = TextEditingController();
  final _language = TextEditingController();
  final _engines = TextEditingController();
  final _maxTokens = TextEditingController();
  final _maxUses = TextEditingController();
  late final String _id;
  WebSearchProfile? _profile;
  WebSearchProviderKind _kind = WebSearchProviderKind.deepseek;
  String _searchDepth = 'basic';
  String _searchType = 'auto';
  bool _enabled = true;
  bool _loading = true;
  bool _saving = false;
  bool _checking = false;
  bool _dirty = false;
  bool _hasKey = false;
  bool _keyVisible = false;
  bool _clearKey = false;
  String? _error;
  String? _notice;
  RunCancellation? _checkCancellation;
  bool get _busy => _saving || _checking;

  @override
  void initState() {
    super.initState();
    _id = widget.profileId ?? generateId();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final state = await ref.read(webSearchControllerProvider.future);
      final profile = state.settings.profiles
          .where((item) => item.id == _id)
          .firstOrNull;
      if (widget.profileId != null && profile == null) {
        throw const OperationFailure('搜索服务已不存在');
      }
      final configured =
          profile != null &&
          await ref
              .read(webSearchControllerProvider.notifier)
              .credentialStatus(profile);
      if (!mounted) return;
      _profile = profile;
      _kind = profile?.kind ?? _kind;
      _name.text = profile?.name ?? _kind.label;
      _endpoint.text = profile?.baseUrl ?? _kind.defaultBaseUrl;
      _model.text = profile?.resolvedModel ?? _kind.defaultModel;
      _region.text = profile?.region ?? '';
      _language.text = profile?.language ?? '';
      _engines.text = profile?.engines ?? '';
      _maxTokens.text = '${profile?.maxTokens ?? 4096}';
      _maxUses.text = '${profile?.maxUses ?? 5}';
      setState(() {
        _hasKey = configured;
        _enabled = profile?.enabled ?? true;
        _searchDepth = profile?.searchDepth ?? 'basic';
        _searchType = profile?.searchType ?? 'auto';
        _loading = false;
      });
    } on Failure catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error.userMessage;
        });
      }
    } on Object {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '搜索配置读取失败';
        });
      }
    }
  }

  void _changed([String? _]) => setState(() {
    _dirty = true;
    _error = null;
    _notice = null;
  });

  void _changeKind(WebSearchProviderKind kind) {
    if (kind == _kind || _profile != null) return;
    _kind = kind;
    _name.text = kind.label;
    _endpoint.text = kind.defaultBaseUrl;
    _model.text = kind.defaultModel;
    _region.clear();
    _language.clear();
    _engines.clear();
    _apiKey.clear();
    _clearKey = false;
    _changed();
  }

  WebSearchProfile _draft() =>
      (_profile ??
              WebSearchProfile(
                id: _id,
                name: _name.text.trim(),
                kind: _kind,
                baseUrl: _endpoint.text.trim(),
              ))
          .copyWith(
            name: _name.text.trim(),
            baseUrl: _endpoint.text.trim().replaceFirst(RegExp(r'/+$'), ''),
            enabled: _enabled,
            model: _model.text.trim(),
            region: _region.text.trim(),
            language: _language.text.trim(),
            engines: _engines.text.trim(),
            searchDepth: _searchDepth,
            searchType: _searchType,
            maxTokens: int.tryParse(_maxTokens.text.trim()) ?? 4096,
            maxUses: int.tryParse(_maxUses.text.trim()) ?? 5,
          );

  void _closePage() {
    if (!mounted) return;
    setState(() {
      _dirty = false;
      _saving = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.pop();
    });
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(webSearchControllerProvider.notifier)
          .saveProfile(_draft(), apiKey: _apiKey.text, clearKey: _clearKey);
      _apiKey.clear();
      _closePage();
    } on Failure catch (error) {
      if (mounted) setState(() => _error = error.userMessage);
    } on Object {
      if (mounted) setState(() => _error = '搜索服务保存失败，请重试');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _check() async {
    if (_busy || !_form.currentState!.validate()) return;
    final cancellation = RunCancellation();
    _checkCancellation = cancellation;
    setState(() {
      _checking = true;
      _error = null;
      _notice = null;
    });
    try {
      final result = await ref
          .read(webSearchControllerProvider.notifier)
          .checkProfile(
            _draft().copyWith(clearCredential: _clearKey),
            apiKey: _apiKey.text,
            cancellation: cancellation.whenCancelled,
          );
      if (mounted && !cancellation.isCancelled) {
        setState(() => _notice = '已连接 · 返回 ${result.sources.length} 个来源');
      }
    } on WebFailure catch (error) {
      if (!mounted) return;
      if (error.code == 'cancelled') {
        setState(() => _notice = '检查已停止');
      } else {
        setState(() => _error = error.userMessage);
      }
    } on Failure catch (error) {
      if (mounted) setState(() => _error = error.userMessage);
    } on Object {
      if (mounted) setState(() => _error = '无法检查搜索服务，请重试');
    } finally {
      _checkCancellation = null;
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _delete() async {
    if (_busy || _profile == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AppDialog(
        title: '删除搜索服务？',
        description: '同时删除此服务的搜索凭据。历史搜索结果保留。',
        icon: LucideIcons.trash2,
        tone: AppTone.error,
        content: const SizedBox.shrink(),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(webSearchControllerProvider.notifier).deleteProfile(_id);
      _closePage();
    } on Failure catch (error) {
      if (mounted) {
        setState(() {
          _profile = ref
              .read(webSearchControllerProvider)
              .value
              ?.settings
              .profiles
              .where((item) => item.id == _id)
              .firstOrNull;
          _error = '删除未完成，请重试。${error.userMessage}';
        });
      }
    } on Object {
      if (mounted) setState(() => _error = '删除未完成，请重试');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _checkCancellation?.cancel();
    for (final controller in [
      _name,
      _endpoint,
      _apiKey,
      _model,
      _region,
      _language,
      _engines,
      _maxTokens,
      _maxUses,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Widget _textField(
    TextEditingController controller,
    String label, {
    bool required = false,
    TextInputType? keyboardType,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.l),
    child: TextFormField(
      controller: controller,
      enabled: !_busy && _profile?.deleting != true,
      keyboardType: keyboardType,
      autocorrect: false,
      decoration: InputDecoration(labelText: label),
      onChanged: _changed,
      validator: required
          ? (value) => value?.trim().isNotEmpty == true ? null : '请填写$label'
          : null,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final missing = widget.profileId != null && _profile == null;
    final deleting = _profile?.deleting == true;
    return WebDraftBackGuard(
      dirty: _dirty,
      busy: _busy,
      onBusyBack: () => _checkCancellation?.cancel(),
      child: AppScaffold(
        title: widget.profileId == null ? '新增搜索服务' : '编辑搜索服务',
        bottomBar: _loading || missing
            ? null
            : AppBottomBar(
                child: Row(
                  children: [
                    if (_profile != null) ...[
                      IconButton.filledTonal(
                        tooltip: deleting ? '重试删除搜索服务' : '删除搜索服务',
                        onPressed: _busy ? null : _delete,
                        style: IconButton.styleFrom(
                          backgroundColor: colors.errorContainer,
                          foregroundColor: colors.onErrorContainer,
                        ),
                        icon: const Icon(LucideIcons.trash2),
                      ),
                      const SizedBox(width: AppSpacing.m),
                    ],
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _busy || deleting ? null : _save,
                        icon: _saving
                            ? const AppLoadingIndicator.small()
                            : const Icon(LucideIcons.check),
                        label: Text(_saving ? '保存中…' : '保存'),
                      ),
                    ),
                  ],
                ),
              ),
        body: _loading
            ? const Center(child: AppLoadingIndicator())
            : missing
            ? AppEmptyState(
                icon: LucideIcons.circleAlert,
                title: '无法读取搜索服务',
                message: _error ?? '搜索服务不存在',
                action: FilledButton.tonal(
                  onPressed: _load,
                  child: const Text('重试'),
                ),
              )
            : Form(
                key: _form,
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.l),
                  children: [
                    AppDropdown<WebSearchProviderKind>(
                      label: '搜索提供方',
                      value: _kind,
                      options: {
                        for (final kind in WebSearchProviderKind.values)
                          kind: kind.label,
                      },
                      onChanged: _busy || _profile != null ? null : _changeKind,
                    ),
                    const SizedBox(height: AppSpacing.l),
                    _textField(_name, '名称', required: true),
                    _textField(
                      _endpoint,
                      '接口地址',
                      required: true,
                      keyboardType: TextInputType.url,
                    ),
                    if (_kind != WebSearchProviderKind.duckDuckGo) ...[
                      TextFormField(
                        controller: _apiKey,
                        enabled: !_busy && !deleting && !_clearKey,
                        obscureText: !_keyVisible,
                        enableSuggestions: false,
                        autocorrect: false,
                        decoration: InputDecoration(
                          labelText: _kind == WebSearchProviderKind.searxng
                              ? 'Bearer 令牌（可选）'
                              : 'API Key',
                          helperText: _hasKey ? '已设置 · 留空保留' : '尚未设置',
                          suffixIcon: IconButton(
                            tooltip: _keyVisible ? '隐藏密钥' : '显示密钥',
                            onPressed: _busy
                                ? null
                                : () => setState(
                                    () => _keyVisible = !_keyVisible,
                                  ),
                            icon: Icon(
                              _keyVisible
                                  ? LucideIcons.eyeOff
                                  : LucideIcons.eye,
                            ),
                          ),
                        ),
                        onChanged: _changed,
                      ),
                      if (_hasKey)
                        CheckboxListTile(
                          title: const Text('移除已保存的密钥'),
                          value: _clearKey,
                          onChanged: _busy || deleting
                              ? null
                              : (value) {
                                  _clearKey = value ?? false;
                                  if (_clearKey) _apiKey.clear();
                                  _changed();
                                },
                        ),
                      const SizedBox(height: AppSpacing.l),
                    ],
                    if (_kind.usesModel) ...[
                      _textField(_model, '搜索模型', required: true),
                      WebNumberField(
                        controller: _maxTokens,
                        label: '搜索回答 token 上限',
                        minimum: 256,
                        maximum: 32768,
                        enabled: !_busy && !deleting,
                        onChanged: _changed,
                      ),
                    ],
                    if (_kind == WebSearchProviderKind.deepseek)
                      WebNumberField(
                        controller: _maxUses,
                        label: '单个查询最多原生搜索次数',
                        minimum: 1,
                        maximum: 20,
                        enabled: !_busy && !deleting,
                        onChanged: _changed,
                      ),
                    if (_kind == WebSearchProviderKind.exa) ...[
                      AppDropdown<String>(
                        label: '检索模式',
                        value: _searchType,
                        options: const {
                          'auto': '自动',
                          'keyword': '关键词',
                          'neural': '语义',
                        },
                        onChanged: _busy || deleting
                            ? null
                            : (value) {
                                if (value == _searchType) return;
                                _searchType = value;
                                _changed();
                              },
                      ),
                      const SizedBox(height: AppSpacing.l),
                    ],
                    if (_kind == WebSearchProviderKind.tavily) ...[
                      AppDropdown<String>(
                        label: '搜索深度',
                        value: _searchDepth,
                        options: const {'basic': '标准', 'advanced': '深入'},
                        onChanged: _busy || deleting
                            ? null
                            : (value) {
                                if (value == _searchDepth) return;
                                _searchDepth = value;
                                _changed();
                              },
                      ),
                      const SizedBox(height: AppSpacing.l),
                    ],
                    if (_kind == WebSearchProviderKind.duckDuckGo ||
                        _kind == WebSearchProviderKind.brave)
                      _textField(
                        _region,
                        _kind == WebSearchProviderKind.brave
                            ? '国家代码（可选，如 cn）'
                            : '地区（可选，如 cn-zh）',
                      ),
                    if (_kind == WebSearchProviderKind.brave ||
                        _kind == WebSearchProviderKind.searxng)
                      _textField(_language, '语言（可选）'),
                    if (_kind == WebSearchProviderKind.searxng)
                      _textField(_engines, '搜索引擎（可选，逗号分隔）'),
                    SwitchListTile.adaptive(
                      title: const Text('启用服务'),
                      value: _enabled,
                      onChanged: _busy || deleting
                          ? null
                          : (value) {
                              _enabled = value;
                              _changed();
                            },
                    ),
                    const SizedBox(height: AppSpacing.l),
                    OutlinedButton.icon(
                      onPressed: deleting || _saving
                          ? null
                          : _checking
                          ? () => _checkCancellation?.cancel()
                          : _check,
                      icon: _checking
                          ? const Icon(LucideIcons.square)
                          : const Icon(LucideIcons.plug),
                      label: Text(_checking ? '停止检查' : '检查连接'),
                    ),
                    const SizedBox(height: AppSpacing.m),
                    if (_notice != null)
                      Text(
                        _notice!,
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                    if (_error != null)
                      Text(_error!, style: TextStyle(color: colors.error)),
                  ],
                ),
              ),
      ),
    );
  }
}
