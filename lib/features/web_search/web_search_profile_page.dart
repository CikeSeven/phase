import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/error/failure.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/brand_colors.dart';
import '../../core/utils/id.dart';
import '../../core/widgets/app_bottom_bar.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/app_dropdown.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_icon_badge.dart';
import '../../core/widgets/app_loading_indicator.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/app_section.dart';
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
            enabled: true,
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
        setState(() => _notice = '连接成功 · 返回 ${result.sources.length} 个来源');
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
    IconData? prefixIcon,
    String? helperText,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.l),
    child: TextFormField(
      controller: controller,
      enabled: !_busy && _profile?.deleting != true,
      keyboardType: keyboardType,
      autocorrect: false,
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 20) : null,
      ),
      onChanged: _changed,
      validator: required
          ? (value) => value?.trim().isNotEmpty == true ? null : '请填写$label'
          : null,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final brand = context.brandColors;
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
                child: Center(
                  heightFactor: 1,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 688),
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
                            label: Text(_saving ? '保存中…' : '保存服务'),
                          ),
                        ),
                      ],
                    ),
                  ),
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
            : Center(
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
                          title: '基本信息',
                          subtitle: '选择搜索引擎类型并指定名称',
                          child: AppCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (widget.profileId == null) ...[
                                  AppDropdown<WebSearchProviderKind>(
                                    label: '搜索提供方',
                                    value: _kind,
                                    options: {
                                      for (final kind
                                          in WebSearchProviderKind.values)
                                        kind: kind.label,
                                    },
                                    onChanged: _busy ? null : _changeKind,
                                  ),
                                  const SizedBox(height: AppSpacing.m),
                                  Container(
                                    padding: const EdgeInsets.all(AppSpacing.m),
                                    decoration: BoxDecoration(
                                      color: colors.surfaceContainerHighest
                                          .withValues(alpha: 0.5),
                                      borderRadius: AppRadius.mediumAll,
                                    ),
                                    child: Row(
                                      children: [
                                        WebSearchProviderBadge(
                                          kind: _kind,
                                          size: 36,
                                          iconSize: 18,
                                        ),
                                        const SizedBox(width: AppSpacing.m),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(
                                                    _kind.label,
                                                    style: theme
                                                        .textTheme
                                                        .titleSmall,
                                                  ),
                                                  const SizedBox(
                                                    width: AppSpacing.s,
                                                  ),
                                                  if (!_kind.requiresKey)
                                                    const AppBadge(
                                                      label: '免密钥',
                                                      tone: AppTone.teal,
                                                    ),
                                                  if (_kind.usesModel)
                                                    const AppBadge(
                                                      label: '大模型',
                                                      tone: AppTone.lavender,
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(
                                                height: AppSpacing.xs,
                                              ),
                                              Text(
                                                webSearchProviderDescription(
                                                  _kind,
                                                ),
                                                style: theme.textTheme.bodySmall
                                                    ?.copyWith(
                                                      color: colors
                                                          .onSurfaceVariant,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ] else ...[
                                  Container(
                                    padding: const EdgeInsets.all(AppSpacing.m),
                                    decoration: BoxDecoration(
                                      color: colors.surfaceContainerHighest
                                          .withValues(alpha: 0.5),
                                      borderRadius: AppRadius.mediumAll,
                                    ),
                                    child: Row(
                                      children: [
                                        WebSearchProviderBadge(
                                          kind: _kind,
                                          size: 40,
                                        ),
                                        const SizedBox(width: AppSpacing.m),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _kind.label,
                                                style:
                                                    theme.textTheme.titleMedium,
                                              ),
                                              const SizedBox(
                                                height: AppSpacing.xs,
                                              ),
                                              Text(
                                                webSearchProviderDescription(
                                                  _kind,
                                                ),
                                                style: theme.textTheme.bodySmall
                                                    ?.copyWith(
                                                      color: colors
                                                          .onSurfaceVariant,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: AppSpacing.s),
                                        const AppBadge(
                                          label: '已锁定类型',
                                          tone: AppTone.primary,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: AppSpacing.l),
                                _textField(
                                  _name,
                                  '服务名称',
                                  prefixIcon: LucideIcons.tag,
                                  required: true,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        AppSection(
                          title: '接口与凭据',
                          subtitle: '配置服务接口地址及认证凭据',
                          child: AppCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _textField(
                                  _endpoint,
                                  '接口地址 (Base URL)',
                                  prefixIcon: LucideIcons.link,
                                  required: true,
                                  keyboardType: TextInputType.url,
                                ),
                                if (_kind != WebSearchProviderKind.duckDuckGo &&
                                    _kind != WebSearchProviderKind.bing) ...[
                                  TextFormField(
                                    controller: _apiKey,
                                    enabled: !_busy && !deleting && !_clearKey,
                                    obscureText: !_keyVisible,
                                    enableSuggestions: false,
                                    autocorrect: false,
                                    decoration: InputDecoration(
                                      labelText:
                                          _kind == WebSearchProviderKind.searxng
                                          ? 'Bearer 令牌（可选）'
                                          : !_kind.requiresKey
                                          ? 'API Key（可选）'
                                          : 'API Key',
                                      prefixIcon: const Icon(
                                        LucideIcons.keyRound,
                                        size: 20,
                                      ),
                                      suffixIcon: IconButton(
                                        tooltip: _keyVisible ? '隐藏密钥' : '显示密钥',
                                        onPressed: _busy
                                            ? null
                                            : () => setState(
                                                () =>
                                                    _keyVisible = !_keyVisible,
                                              ),
                                        icon: Icon(
                                          _keyVisible
                                              ? LucideIcons.eyeOff
                                              : LucideIcons.eye,
                                          size: 20,
                                        ),
                                      ),
                                      helperText: _hasKey
                                          ? (_clearKey
                                                ? '已勾选移除已存密钥'
                                                : '已配置密钥 · 留空保留原密钥')
                                          : (_kind ==
                                                    WebSearchProviderKind
                                                        .searxng
                                                ? '若 SearXNG 实例无需鉴权可留空'
                                                : !_kind.requiresKey
                                                ? '可选 · 若有 API Key 可填写以提升配额'
                                                : '请输入用于鉴权的 API Key'),
                                    ),
                                    onChanged: _changed,
                                  ),
                                  if (_hasKey) ...[
                                    const SizedBox(height: AppSpacing.m),
                                    Row(
                                      children: [
                                        AppBadge(
                                          label: _clearKey ? '将移除密钥' : '已保存密钥',
                                          tone: _clearKey
                                              ? AppTone.error
                                              : AppTone.teal,
                                        ),
                                        const Spacer(),
                                        InkWell(
                                          borderRadius: AppRadius.controlAll,
                                          onTap: _busy || deleting
                                              ? null
                                              : () {
                                                  setState(() {
                                                    _clearKey = !_clearKey;
                                                    if (_clearKey) {
                                                      _apiKey.clear();
                                                    }
                                                    _changed();
                                                  });
                                                },
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: AppSpacing.s,
                                              vertical: AppSpacing.xs,
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  _clearKey
                                                      ? LucideIcons.undo2
                                                      : LucideIcons.trash2,
                                                  size: 16,
                                                  color: _clearKey
                                                      ? colors.primary
                                                      : colors.error,
                                                ),
                                                const SizedBox(
                                                  width: AppSpacing.xs,
                                                ),
                                                Text(
                                                  _clearKey ? '取消移除' : '移除已存密钥',
                                                  style: theme
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: _clearKey
                                                            ? colors.primary
                                                            : colors.error,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ],
                            ),
                          ),
                        ),
                        if (_kind.usesModel ||
                            _kind == WebSearchProviderKind.deepseek ||
                            _kind == WebSearchProviderKind.exa ||
                            _kind == WebSearchProviderKind.tavily ||
                            _kind == WebSearchProviderKind.duckDuckGo ||
                            _kind == WebSearchProviderKind.brave ||
                            _kind == WebSearchProviderKind.searxng ||
                            _kind == WebSearchProviderKind.bing ||
                            _kind == WebSearchProviderKind.serper) ...[
                          const SizedBox(height: AppSpacing.xl),
                          AppSection(
                            title: '搜索行为与参数',
                            subtitle: '定制搜索模式、模型或检索条件',
                            child: AppCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (_kind.usesModel) ...[
                                    _textField(
                                      _model,
                                      '搜索模型',
                                      prefixIcon: LucideIcons.cpu,
                                      required: true,
                                    ),
                                    WebNumberField(
                                      controller: _maxTokens,
                                      label: '搜索回答 token 上限',
                                      prefixIcon: LucideIcons.coins,
                                      suffixText: 'tokens',
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
                                      prefixIcon: LucideIcons.refreshCw,
                                      suffixText: '次',
                                      minimum: 1,
                                      maximum: 20,
                                      helperText:
                                          '单次查询中 DeepSeek 最多调用的原生搜索次数 (1–20)',
                                      enabled: !_busy && !deleting,
                                      onChanged: _changed,
                                    ),
                                  if (_kind == WebSearchProviderKind.exa) ...[
                                    AppDropdown<String>(
                                      label: '检索模式',
                                      value: _searchType,
                                      options: const {
                                        'auto': '自动 (Auto)',
                                        'keyword': '关键词 (Keyword)',
                                        'neural': '语义 (Neural)',
                                      },
                                      onChanged: _busy || deleting
                                          ? null
                                          : (value) {
                                              if (value == _searchType) return;
                                              setState(() {
                                                _searchType = value;
                                                _changed();
                                              });
                                            },
                                    ),
                                    const SizedBox(height: AppSpacing.l),
                                  ],
                                  if (_kind ==
                                      WebSearchProviderKind.tavily) ...[
                                    AppDropdown<String>(
                                      label: '搜索深度',
                                      value: _searchDepth,
                                      options: const {
                                        'basic': '标准深度 (Basic)',
                                        'advanced': '深入检索 (Advanced)',
                                      },
                                      onChanged: _busy || deleting
                                          ? null
                                          : (value) {
                                              if (value == _searchDepth) return;
                                              setState(() {
                                                _searchDepth = value;
                                                _changed();
                                              });
                                            },
                                    ),
                                    const SizedBox(height: AppSpacing.l),
                                  ],
                                  if (_kind ==
                                          WebSearchProviderKind.duckDuckGo ||
                                      _kind == WebSearchProviderKind.brave)
                                    _textField(
                                      _region,
                                      _kind == WebSearchProviderKind.brave
                                          ? '国家代码（可选，如 cn）'
                                          : '地区（可选，如 cn-zh）',
                                      prefixIcon: LucideIcons.mapPin,
                                    ),
                                  if (_kind == WebSearchProviderKind.brave ||
                                      _kind == WebSearchProviderKind.searxng ||
                                      _kind == WebSearchProviderKind.bing ||
                                      _kind == WebSearchProviderKind.serper)
                                    _textField(
                                      _language,
                                      _kind == WebSearchProviderKind.serper
                                          ? '地区代码（可选，如 cn、us）'
                                          : '语言代码（可选，如 zh-CN、zh）',
                                      prefixIcon: LucideIcons.languages,
                                    ),
                                  if (_kind == WebSearchProviderKind.searxng)
                                    _textField(
                                      _engines,
                                      '搜索引擎（可选，逗号分隔，如 google,bing）',
                                      prefixIcon: LucideIcons.layers,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.xl),
                        AppSection(
                          title: '连通性测试',
                          subtitle: '在保存前发送测试请求验证接口地址与密钥是否可用',
                          child: AppCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '接口测试',
                                            style: theme.textTheme.titleSmall,
                                          ),
                                          const SizedBox(height: AppSpacing.xs),
                                          Text(
                                            '发送测试请求验证接口地址与密钥是否可用',
                                            style: theme.textTheme.bodyMedium
                                                ?.copyWith(
                                                  color:
                                                      colors.onSurfaceVariant,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.m),
                                    FilledButton.tonalIcon(
                                      onPressed: deleting || _saving
                                          ? null
                                          : _checking
                                          ? () => _checkCancellation?.cancel()
                                          : _check,
                                      icon: _checking
                                          ? const AppLoadingIndicator.small()
                                          : const Icon(
                                              LucideIcons.plugZap,
                                              size: 18,
                                            ),
                                      label: Text(_checking ? '停止' : '测试连接'),
                                    ),
                                  ],
                                ),
                                if (_notice != null) ...[
                                  const SizedBox(height: AppSpacing.m),
                                  Container(
                                    padding: const EdgeInsets.all(AppSpacing.m),
                                    decoration: BoxDecoration(
                                      color: brand.tealContainer,
                                      borderRadius: AppRadius.smallAll,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          LucideIcons.circleCheck,
                                          color: brand.onTealContainer,
                                          size: 20,
                                        ),
                                        const SizedBox(width: AppSpacing.m),
                                        Expanded(
                                          child: Text(
                                            _notice!,
                                            style: TextStyle(
                                              color: brand.onTealContainer,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                if (_error != null) ...[
                                  const SizedBox(height: AppSpacing.m),
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
                                            style: TextStyle(
                                              color: colors.onErrorContainer,
                                            ),
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
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
