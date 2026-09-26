import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/error/failure.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/id.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_icon_badge.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../data/models/api_protocol.dart';
import '../../../data/models/openai_compat.dart';
import '../../../data/models/profile_model.dart';
import '../../../data/models/provider_profile.dart';
import '../../../data/repositories/provider_profile_repository.dart';
import '../../../providers/presets/provider_preset.dart';
import '../../../providers/provider_factory.dart';
import 'provider_form_sections.dart';
import 'provider_model_dialog.dart';
import 'provider_model_editor.dart';
import 'provider_preset_sheet.dart';

/// 新增配置确认后创建，已有配置的有效修改自动保存。
class ProviderEditPage extends ConsumerStatefulWidget {
  const ProviderEditPage({super.key, this.profileId});

  /// null 表示新增。
  final String? profileId;

  @override
  ConsumerState<ProviderEditPage> createState() => _ProviderEditPageState();
}

class _ProviderEditPageState extends ConsumerState<ProviderEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _baseUrlFieldKey = GlobalKey<FormFieldState<String>>();
  final _nameController = TextEditingController();
  final _baseUrlController = TextEditingController();
  final _apiKeyController = TextEditingController();

  String? _profileId;
  String? _savedApiKey;
  String? _loadError;
  String _presetId = 'custom';
  ApiProtocol _protocol = ApiProtocol.openaiCompletions;
  OpenAiCompat? _compatOverrides;
  List<ProfileModel> _models = const [];
  String? _defaultModel;
  bool _apiKeyVisible = false;
  bool _loading = true;
  bool _saving = false;
  bool _modalOpen = false;
  bool _testing = false;
  int _testRequestId = 0;
  int? _testedModelCount;
  String? _testError;
  ProviderProfileRepository? _repository;
  DateTime? _createdAt;
  ScaffoldMessengerState? _messenger;
  Timer? _autoSaveTimer;
  Future<void>? _autoSaveFuture;
  ({ProviderProfile profile, String apiKey, int revision})? _pendingSave;
  int _revision = 0;
  String? _saveError;
  String? _deleteError;
  bool _dirty = false;
  bool _leaving = false;
  bool _deleting = false;
  bool _deletePending = false;

  ProviderPreset get _preset => presetById(_presetId);
  bool get _editing => widget.profileId != null;
  bool get _busy => (!_editing && _saving) || _modalOpen || _deletePending;

  @override
  void initState() {
    super.initState();
    _profileId = widget.profileId;
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _messenger = ScaffoldMessenger.of(context);
  }

  Future<void> _load() async {
    if (widget.profileId == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final repository = await ref.read(
        providerProfileRepositoryProvider.future,
      );
      final profile = await repository.getProfile(widget.profileId!);
      if (profile == null) {
        if (mounted) {
          setState(() {
            _loadError = '服务商配置已不存在。';
            _loading = false;
          });
        }
        return;
      }
      final apiKey = await repository.readApiKey(profile.id);
      if (!mounted) return;
      setState(() {
        _repository = repository;
        _createdAt = profile.createdAt;
        _nameController.text = profile.name;
        _baseUrlController.text = profile.baseUrl;
        _apiKeyController.text = apiKey ?? '';
        _savedApiKey = apiKey;
        _presetId = profile.presetId;
        _protocol = profile.protocol;
        _compatOverrides = profile.compatOverrides;
        // 列表外的默认模型也要可见可编辑，否则保存会把它丢掉。
        final models = List.of(profile.models);
        final fallback = profile.defaultModel;
        if (fallback != null &&
            fallback.isNotEmpty &&
            models.every((model) => model.id != fallback)) {
          models.insert(0, ProfileModel(id: fallback));
        }
        _models = models;
        _defaultModel = profile.defaultModel;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error is Failure ? error.userMessage : '读取配置或安全存储失败，请重试。';
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _leaving = true;
    _autoSaveTimer?.cancel();
    _autoSaveTimer = null;
    // 返回不阻断预测手势；已捕获的有效修改继续写入，失败由上层消息提示。
    _startAutoSave();
    if (_dirty && _pendingSave == null && !_saving && !_deletePending) {
      _showSaveFailure(_saveError ?? '更改未保存，请修正表单中的错误。');
    }
    _nameController.dispose();
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppScaffold(
      title: widget.profileId == null ? '新增服务商' : '编辑服务商',
      subtitle: _loading || _loadError != null
          ? null
          : _editing
          ? (_deletePending
                ? (_deleting ? '删除中…' : '删除未完成')
                : _dirty
                ? (_saveError != null ? '未保存' : '保存中…')
                : '已保存')
          : (_saving ? '保存中…' : null),
      actions: [
        if (!_loading && _loadError == null)
          if (_editing)
            IconButton(
              key: const ValueKey('delete-provider'),
              tooltip: '删除服务商',
              color: theme.colorScheme.error,
              onPressed: _deleting || _modalOpen ? null : _delete,
              icon: _deleting
                  ? const AppLoadingIndicator.small(semanticsLabel: '正在删除服务商')
                  : const Icon(Symbols.delete),
            )
          else
            IconButton(
              key: const ValueKey('save-provider'),
              tooltip: '保存',
              onPressed: _busy ? null : _save,
              icon: _saving
                  ? const AppLoadingIndicator.small(semanticsLabel: '正在保存配置')
                  : const Icon(Symbols.check),
            ),
      ],
      body: _loading
          ? const Center(child: AppLoadingIndicator(semanticsLabel: '正在读取配置'))
          : _loadError != null
          ? AppEmptyState(
              icon: Symbols.cloud_off,
              title: '无法读取服务商配置',
              message: '$_loadError\n读取成功前不可编辑或保存。',
              action: FilledButton.tonalIcon(
                onPressed: _load,
                icon: const Icon(Symbols.refresh),
                label: const Text('重新加载'),
              ),
            )
          : Form(
              key: _formKey,
              child: CustomScrollView(
                key: const ValueKey('provider-edit-scroll'),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  if (_saveError != null || _deleteError != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.l),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Semantics(
                              liveRegion: true,
                              child: Text(
                                _deleteError ?? _saveError!,
                                style: TextStyle(
                                  color: theme.colorScheme.error,
                                ),
                              ),
                            ),
                            TextButton.icon(
                              key: ValueKey(
                                _deletePending
                                    ? 'retry-delete-provider'
                                    : 'retry-save-provider',
                              ),
                              style: _deletePending
                                  ? TextButton.styleFrom(
                                      foregroundColor: theme.colorScheme.error,
                                    )
                                  : null,
                              onPressed: _deletePending
                                  ? (_deleting ? null : _delete)
                                  : (_busy ? null : _scheduleAutoSave),
                              icon: const Icon(Symbols.refresh),
                              label: const Text('重试'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.l),
                      child: ProviderFormSections(
                        preset: _preset,
                        protocol: _protocol,
                        nameController: _nameController,
                        baseUrlController: _baseUrlController,
                        apiKeyController: _apiKeyController,
                        baseUrlFieldKey: _baseUrlFieldKey,
                        apiKeyVisible: _apiKeyVisible,
                        hasSavedKey: _savedApiKey?.isNotEmpty ?? false,
                        hasCompatOverrides: _compatOverrides != null,
                        enabled: !_busy,
                        testing: _testing,
                        testedModelCount: _testedModelCount,
                        testError: _testError,
                        onChoosePreset: _choosePreset,
                        onProtocolChanged: _changeProtocol,
                        onConnectionChanged: () {
                          setState(_invalidateTest);
                          _scheduleAutoSave(debounce: true);
                        },
                        onToggleKeyVisibility: () =>
                            setState(() => _apiKeyVisible = !_apiKeyVisible),
                        onTest: _testConnection,
                      ),
                    ),
                  ),
                  ProviderModelEditor(
                    presetId: _presetId,
                    models: _models,
                    enabled: !_busy,
                    onAdd: _addModel,
                    onModelChanged: (model) {
                      setState(() {
                        _models = [
                          for (final entry in _models)
                            if (entry.id == model.id) model else entry,
                        ];
                      });
                      _scheduleAutoSave();
                    },
                    onRemove: _removeModel,
                  ),
                ],
              ),
            ),
    );
  }

  void _invalidateTest() {
    _testRequestId++;
    _testing = false;
    _testedModelCount = null;
    _testError = null;
  }

  Future<T?> _showEditorModal<T>(Future<T?> Function() show) async {
    if (_busy) return null;
    FocusScope.of(context).unfocus();
    setState(() => _modalOpen = true);
    try {
      return await show();
    } finally {
      if (mounted) setState(() => _modalOpen = false);
    }
  }

  Future<void> _choosePreset() async {
    final preset = await _showEditorModal(
      () => showModalBottomSheet<ProviderPreset>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Theme.of(context).colorScheme.surface
            .withValues(alpha: 0),
        builder: (_) => ProviderPresetSheet(selectedId: _presetId),
      ),
    );
    if (preset == null || !mounted || preset.id == _presetId) return;
    setState(() {
      _presetId = preset.id;
      if (widget.profileId == null) _protocol = preset.protocol;
      if (preset.baseUrl.isNotEmpty) _baseUrlController.text = preset.baseUrl;
      if (_nameController.text.trim().isEmpty && preset.id != 'custom') {
        _nameController.text = preset.name;
      }
      _invalidateTest();
    });
    _scheduleAutoSave();
  }

  void _changeProtocol(ApiProtocol protocol) {
    if (_busy || protocol == _protocol) return;
    setState(() {
      _protocol = protocol;
      _invalidateTest();
    });
    _scheduleAutoSave();
  }

  Future<void> _addModel() async {
    final model = await _showEditorModal(
      () => showDialog<ProfileModel>(
        context: context,
        builder: (_) => ProviderModelDialog(
          containsId: (id) => _models.any((model) => model.id == id),
        ),
      ),
    );
    if (model == null || !mounted) return;
    setState(() {
      if (_models.every((entry) => entry.id != model.id)) {
        _models = [..._models, model];
      }
      _defaultModel ??= model.id;
    });
    _scheduleAutoSave();
  }

  Future<void> _removeModel(ProfileModel model) async {
    var confirmed = false;
    final remove = await _showEditorModal(
      () => showDialog<bool>(
        context: context,
        builder: (context) => AppDialog(
          title: '移除模型？',
          description: _editing ? '从此配置中移除，不会删除远端模型。' : '保存后从此配置中移除，不会删除远端模型。',
          icon: Symbols.delete,
          tone: AppTone.error,
          content: Text(model.id),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              key: const ValueKey('confirm-remove-model'),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              onPressed: () {
                if (confirmed) return;
                confirmed = true;
                Navigator.of(context).pop(true);
              },
              child: const Text('移除'),
            ),
          ],
        ),
      ),
    );
    if (remove != true || !mounted) return;
    setState(() {
      _models = _models.where((entry) => entry.id != model.id).toList();
      if (_defaultModel == model.id) _defaultModel = null;
    });
    _scheduleAutoSave();
  }

  Future<void> _testConnection() async {
    if (_busy || _testing || _loading || _loadError != null) return;
    if (!_baseUrlFieldKey.currentState!.validate()) {
      await Scrollable.ensureVisible(_baseUrlFieldKey.currentContext!);
      return;
    }
    final requestId = ++_testRequestId;
    final profile = ProviderProfile(
      id: _profileId ?? 'unsaved',
      name: _nameController.text.trim(),
      protocol: _protocol,
      baseUrl: _baseUrlController.text.trim(),
      requiresKey: _preset.requiresApiKey,
      presetId: _presetId,
      compatOverrides: _compatOverrides,
      createdAt: DateTime.now(),
    );
    final enteredKey = _apiKeyController.text.trim();
    final apiKey = _preset.requiresApiKey
        ? (enteredKey.isEmpty ? _savedApiKey ?? '' : enteredKey)
        : '';
    setState(() {
      _testing = true;
      _testedModelCount = null;
      _testError = null;
    });
    try {
      final provider = ref.read(aiProviderFactoryProvider)(profile, apiKey);
      final fetched = await provider.listModels();
      if (!mounted || requestId != _testRequestId) return;
      final ids = fetched
          .map((model) => model.id)
          .where((id) => id.trim().isNotEmpty)
          .toSet();
      setState(() {
        final merged = {for (final model in _models) model.id: model};
        for (final id in ids) {
          // 新拉到的模型默认不启用，由用户勾选后进入聊天模型列表；
          // 已有模型的勾选与能力标记不受影响。
          // 新拉到的模型默认不启用（由用户勾选才进入聊天列表），
          // 能力标记沿用原型的宽松默认，确实不支持的模型由用户关闭。
          merged.putIfAbsent(
            id,
            () => ProfileModel(
              id: id,
              enabled: false,
              supportsReasoning: true,
              supportsTools: true,
              supportsImages: true,
            ),
          );
        }
        _models = merged.values.toList();
        _testing = false;
        _testedModelCount = ids.length;
      });
      _scheduleAutoSave();
    } catch (error) {
      if (!mounted || requestId != _testRequestId) return;
      setState(() {
        _testing = false;
        _testError = error is Failure ? error.userMessage : '获取模型失败，请检查配置后重试。';
      });
    }
  }

  ProviderProfile _draft() => ProviderProfile(
    id: _profileId ??= generateId(),
    name: _nameController.text.trim(),
    protocol: _protocol,
    baseUrl: _baseUrlController.text.trim(),
    requiresKey: _preset.requiresApiKey,
    presetId: _presetId,
    models: List.of(_models),
    defaultModel: _defaultModel,
    compatOverrides: _compatOverrides,
    createdAt: _createdAt ??= DateTime.now(),
  );

  void _scheduleAutoSave({bool debounce = false}) {
    if (!_editing || _loading || _loadError != null || _deletePending) return;
    _autoSaveTimer?.cancel();
    _autoSaveTimer = null;
    _revision++;
    setState(() {
      _dirty = true;
      _saveError = null;
    });
    if (validateProviderName(_nameController.text) != null ||
        validateProviderBaseUrl(_baseUrlController.text) != null) {
      _pendingSave = null;
      _formKey.currentState?.validate();
      setState(() => _saveError = '更改未保存，请修正表单中的错误。');
      return;
    }
    _formKey.currentState?.validate();
    _pendingSave = (
      profile: _draft(),
      apiKey: _apiKeyController.text.trim(),
      revision: _revision,
    );
    if (debounce) {
      _autoSaveTimer = Timer(const Duration(milliseconds: 400), () {
        _autoSaveTimer = null;
        _startAutoSave();
      });
    } else {
      _startAutoSave();
    }
  }

  void _startAutoSave() {
    if (_saving || _pendingSave == null || _deletePending) return;
    _saving = true;
    _autoSaveFuture = _drainAutoSave();
  }

  Future<void> _drainAutoSave() async {
    try {
      // 一次只写一份完整快照；写入中的新修改合并为下一份，旧完成不改回表单。
      while (!_deletePending && _autoSaveTimer == null) {
        final pending = _pendingSave;
        if (pending == null) break;
        _pendingSave = null;
        try {
          await _repository!.saveProfile(pending.profile);
          if (pending.profile.requiresKey &&
              pending.apiKey.isNotEmpty &&
              pending.apiKey != _savedApiKey) {
            await _repository!.writeApiKey(pending.profile.id, pending.apiKey);
            _savedApiKey = pending.apiKey;
          }
          if (pending.revision == _revision) {
            _dirty = false;
            _saveError = null;
          }
        } catch (error) {
          if (_deletePending || pending.revision != _revision) continue;
          _saveError = error is Failure ? error.userMessage : '自动保存失败，请重试。';
          if (_leaving || !mounted) _showSaveFailure(_saveError!);
        }
      }
    } finally {
      _saving = false;
      if (mounted && !_leaving) setState(() {});
    }
  }

  void _showSaveFailure(String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final messenger = _messenger;
      if (messenger != null && messenger.mounted) {
        messenger.showSnackBar(buildAppSnackBar(content: Text(message)));
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _delete() async {
    if (_deleting || _modalOpen || _profileId == null) return;
    if (!_deletePending) {
      final confirmed = await _showEditorModal(
        () => showDialog<bool>(
          context: context,
          builder: (context) => AppDialog(
            title: '删除服务商？',
            description: '将删除此服务商的配置、模型和本机保存的 API Key。',
            icon: Symbols.delete,
            tone: AppTone.error,
            content: Text(_nameController.text.trim()),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                key: const ValueKey('confirm-delete-provider'),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('删除'),
              ),
            ],
          ),
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() {
      _deleting = true;
      _deletePending = true;
      _deleteError = null;
      _saveError = null;
      _pendingSave = null;
      _invalidateTest();
    });
    _autoSaveTimer?.cancel();
    _autoSaveTimer = null;
    try {
      // 先收尾已派发的写入，再删除，避免迟到写入重新创建已删除配置。
      await _autoSaveFuture;
      await _repository!.deleteProfile(_profileId!);
      if (!mounted) return;
      _close();
    } catch (error) {
      _deleteError = error is Failure ? error.userMessage : '删除服务商失败，请重试。';
      if (!mounted) _showSaveFailure(_deleteError!);
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/settings/providers');
    }
  }

  Future<void> _save() async {
    if (_busy || _loading || _loadError != null) return;
    final invalidFields = _formKey.currentState!.validateGranularly();
    if (invalidFields.isNotEmpty) {
      await Scrollable.ensureVisible(invalidFields.first.context);
      return;
    }
    FocusScope.of(context).unfocus();
    final apiKey = _apiKeyController.text.trim();
    final draft = _draft();
    setState(() {
      _saving = true;
      _invalidateTest();
    });
    try {
      final repository = await ref.read(
        providerProfileRepositoryProvider.future,
      );
      final profile = await repository.saveProfile(draft);
      if (profile.requiresKey && apiKey.isNotEmpty) {
        await repository.writeApiKey(profile.id, apiKey);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(buildAppSnackBar(content: const Text('已保存服务商配置')));
      _close();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        buildAppSnackBar(
          content: Text(error is Failure ? error.userMessage : '保存失败，请重试。'),
        ),
      );
      setState(() => _saving = false);
    }
  }
}
