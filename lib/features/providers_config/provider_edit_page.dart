import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/error/failure.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_bottom_bar.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_scaffold.dart';
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
import 'provider_protocol_sheet.dart';

/// 服务商新增 / 编辑草稿，只有保存操作会写入配置与安全存储。
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

  ProviderPreset get _preset => presetById(_presetId);
  bool get _busy => _saving || _modalOpen;

  @override
  void initState() {
    super.initState();
    _profileId = widget.profileId;
    _load();
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
      final repository = ref.read(providerProfileRepositoryProvider);
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
        _nameController.text = profile.name;
        _baseUrlController.text = profile.baseUrl;
        _apiKeyController.text = apiKey ?? '';
        _savedApiKey = apiKey;
        _presetId = profile.presetId;
        _protocol = profile.protocol;
        _compatOverrides = profile.compatOverrides;
        _models = {for (final model in profile.modelCandidates) model.id: model}
            .values
            .toList();
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
      bottomBar: _loading || _loadError != null
          ? null
          : AppBottomBar(
              child: Center(
                heightFactor: 1,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 688),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${_models.length} 个模型',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.m),
                      FilledButton.icon(
                        key: const ValueKey('save-provider'),
                        onPressed: _busy ? null : _save,
                        icon: _saving
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Symbols.check),
                        label: Text(_saving ? '保存中…' : '保存'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(semanticsLabel: '正在读取配置'),
            )
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
                        onChooseProtocol: _chooseProtocol,
                        onConnectionChanged: () => setState(_invalidateTest),
                        onToggleKeyVisibility: () =>
                            setState(() => _apiKeyVisible = !_apiKeyVisible),
                        onTest: _testConnection,
                      ),
                    ),
                  ),
                  ProviderModelEditor(
                    models: _models,
                    defaultModel: _defaultModel,
                    enabled: !_busy,
                    onAdd: _addModel,
                    onDefaultChanged: (id) =>
                        setState(() => _defaultModel = id),
                    onModelChanged: (model) => setState(() {
                      _models = [
                        for (final entry in _models)
                          if (entry.id == model.id) model else entry,
                      ];
                    }),
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
  }

  Future<void> _chooseProtocol() async {
    final protocol = await _showEditorModal(
      () => showModalBottomSheet<ApiProtocol>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Theme.of(context).colorScheme.surface
            .withValues(alpha: 0),
        builder: (_) => ProviderProtocolSheet(selected: _protocol),
      ),
    );
    if (protocol == null || !mounted || protocol == _protocol) return;
    setState(() {
      _protocol = protocol;
      _invalidateTest();
    });
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
  }

  Future<void> _removeModel(ProfileModel model) async {
    var confirmed = false;
    final remove = await _showEditorModal(
      () => showDialog<bool>(
        context: context,
        builder: (context) => AppDialog(
          title: '移除模型？',
          description: '保存后从此配置中移除，不会删除远端模型。',
          icon: Symbols.delete,
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
      baseUrl: _baseUrlController.text.trim(),
      protocol: _protocol,
      presetId: _presetId,
      compatOverrides: _compatOverrides,
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
          merged.putIfAbsent(
            id,
            () => ProfileModel(
              id: id,
              supportsReasoning: guessSupportsReasoning(id),
            ),
          );
        }
        _models = merged.values.toList();
        _testing = false;
        _testedModelCount = ids.length;
      });
    } catch (error) {
      if (!mounted || requestId != _testRequestId) return;
      setState(() {
        _testing = false;
        _testError = error is Failure ? error.userMessage : '获取模型失败，请检查配置后重试。';
      });
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
    final requiresApiKey = _preset.requiresApiKey;
    final repository = ref.read(providerProfileRepositoryProvider);
    setState(() {
      _saving = true;
      _invalidateTest();
    });
    try {
      final profile = await repository.saveProfile(
        id: _profileId,
        name: _nameController.text.trim(),
        baseUrl: _baseUrlController.text.trim(),
        protocol: _protocol,
        presetId: _presetId,
        defaultModel: _defaultModel,
        models: List.of(_models),
        compatOverrides: _compatOverrides,
      );
      _profileId = profile.id;
      if (requiresApiKey && apiKey.isNotEmpty) {
        await repository.writeApiKey(profile.id, apiKey);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已保存服务商配置')));
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/settings/providers');
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error is Failure ? error.userMessage : '保存失败，请重试。'),
        ),
      );
      setState(() => _saving = false);
    }
  }
}
