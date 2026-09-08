import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../core/error/failure.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/models/profile_model.dart';
import '../../../data/models/provider_profile.dart';
import '../../../data/repositories/provider_profile_repository.dart';
import '../../../providers/presets/provider_preset.dart';
import '../../../providers/provider_factory.dart';

/// 测试连接的行内状态。
sealed class _TestStatus {
  const _TestStatus();
}

class _TestIdle extends _TestStatus {
  const _TestIdle();
}

class _TestRunning extends _TestStatus {
  const _TestRunning();
}

class _TestSuccess extends _TestStatus {
  const _TestSuccess(this.modelCount);

  final int modelCount;
}

class _TestFailure extends _TestStatus {
  const _TestFailure(this.message);

  final String message;
}

/// 服务商新增 / 编辑表单（`/settings/providers/new`、`/settings/providers/:id`）。
///
/// DESIGN.md §5.4：API Key obscureText + 可见切换，注明密钥仅保存在
/// 本机安全存储中；保存后立即 SnackBar 反馈；连接性校验行内展示。
class ProviderEditPage extends ConsumerStatefulWidget {
  const ProviderEditPage({super.key, this.profileId});

  /// null 表示新增。
  final String? profileId;

  @override
  ConsumerState<ProviderEditPage> createState() => _ProviderEditPageState();
}

class _ProviderEditPageState extends ConsumerState<ProviderEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _baseUrlController = TextEditingController();
  final _apiKeyController = TextEditingController();

  bool _apiKeyVisible = false;
  bool _loading = true;
  bool _saving = false;

  ProviderPreset _preset = providerPresets.last;
  _TestStatus _testStatus = const _TestIdle();

  /// 模型管理列表：可手动添加，或经测试连接拉取合并。
  List<ProfileModel> _models = const [];
  String? _defaultModel;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profileId = widget.profileId;
    if (profileId != null) {
      final repository = ref.read(providerProfileRepositoryProvider);
      try {
        final profile = await repository.getProfile(profileId);
        final apiKey = await repository.readApiKey(profileId);
        if (profile != null) {
          _nameController.text = profile.name;
          _baseUrlController.text = profile.baseUrl;
          _apiKeyController.text = apiKey ?? '';
          _preset = presetById(profile.presetId);
          _models = profile.models;
          _defaultModel = profile.defaultModel;
        }
      } on Failure {
        // 读取失败按新增空表单处理，保存时报错也会给出 SnackBar。
      }
    }
    if (mounted) {
      setState(() => _loading = false);
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
    final isNew = widget.profileId == null;
    return Scaffold(
      appBar: AppBar(title: Text(isNew ? '新增服务商' : '编辑服务商')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.l),
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _preset.id,
                    decoration: const InputDecoration(labelText: '服务商'),
                    items: [
                      for (final preset in providerPresets)
                        DropdownMenuItem(
                          value: preset.id,
                          child: Text(preset.name),
                        ),
                    ],
                    onChanged: _onPresetChanged,
                  ),
                  if (_preset.note != null)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.s),
                      child: Text(
                        _preset.note!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.l),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: '名称',
                      hintText: '如：DeepSeek 官方',
                    ),
                    textInputAction: TextInputAction.next,
                    validator: _required,
                  ),
                  const SizedBox(height: AppSpacing.l),
                  TextFormField(
                    controller: _baseUrlController,
                    decoration: const InputDecoration(
                      labelText: 'Base URL',
                      hintText: 'https://api.openai.com/v1',
                    ),
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.next,
                    validator: _required,
                  ),
                  if (_preset.requiresApiKey) ...[
                    const SizedBox(height: AppSpacing.l),
                    TextFormField(
                      controller: _apiKeyController,
                      obscureText: !_apiKeyVisible,
                      decoration: InputDecoration(
                        labelText: 'API Key',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _apiKeyVisible
                                ? Symbols.visibility_off
                                : Symbols.visibility,
                          ),
                          tooltip: _apiKeyVisible ? '隐藏密钥' : '显示密钥',
                          onPressed: () =>
                              setState(() => _apiKeyVisible = !_apiKeyVisible),
                        ),
                      ),
                      textInputAction: TextInputAction.done,
                    ),
                    const SizedBox(height: AppSpacing.s),
                    Text(
                      '密钥仅保存在本机安全存储中',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  _buildModelSection(),
                  const SizedBox(height: AppSpacing.xl),
                  OutlinedButton.icon(
                    onPressed: _testStatus is _TestRunning
                        ? null
                        : _testConnection,
                    icon: const Icon(Symbols.cloud),
                    label: const Text('测试连接'),
                  ),
                  const SizedBox(height: AppSpacing.s),
                  _buildTestStatus(),
                  const SizedBox(height: AppSpacing.xl),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Symbols.check),
                    label: const Text('保存'),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildModelSection() {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '模型',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(color: colorScheme.primary),
        ),
        const SizedBox(height: AppSpacing.s),
        DropdownButtonFormField<String>(
          initialValue: _models.any((m) => m.id == _defaultModel)
              ? _defaultModel
              : null,
          decoration: const InputDecoration(
            labelText: '默认模型',
            hintText: '从模型列表中选择',
          ),
          items: [
            for (final model in _models)
              DropdownMenuItem(value: model.id, child: Text(model.id)),
          ],
          onChanged: _models.isEmpty
              ? null
              : (value) => setState(() => _defaultModel = value),
        ),
        const SizedBox(height: AppSpacing.m),
        for (final model in _models)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s),
            child: Dismissible(
              key: ValueKey(model.id),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: AppSpacing.l),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer,
                  borderRadius: AppRadius.mediumAll,
                ),
                child: Icon(
                  Symbols.delete,
                  color: colorScheme.onErrorContainer,
                ),
              ),
              onDismissed: (_) => setState(() {
                _models = [for (final m in _models) if (m.id != model.id) m];
                if (_defaultModel == model.id) {
                  _defaultModel = null;
                }
              }),
              child: ListTile(
                title: Text(model.id, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '支持推理',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Switch(
                      value: model.supportsReasoning,
                      onChanged: (value) => setState(() {
                        _models = [
                          for (final m in _models)
                            if (m.id == model.id)
                              m.copyWith(supportsReasoning: value)
                            else
                              m,
                        ];
                      }),
                    ),
                  ],
                ),
              ),
            ),
          ),
        OutlinedButton.icon(
          onPressed: _addModel,
          icon: const Icon(Symbols.add),
          label: const Text('添加模型'),
        ),
      ],
    );
  }

  Widget _buildTestStatus() {
    final colorScheme = Theme.of(context).colorScheme;
    return switch (_testStatus) {
      _TestIdle() => const SizedBox.shrink(),
      _TestRunning() => const Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: AppSpacing.m),
          Text('正在测试连接…'),
        ],
      ),
      _TestSuccess(:final modelCount) => Row(
        children: [
          Icon(Symbols.check_circle, size: 20, color: colorScheme.primary),
          const SizedBox(width: AppSpacing.m),
          Expanded(
            child: Text(
              '连接成功，已获取 $modelCount 个模型',
              style: TextStyle(color: colorScheme.primary),
            ),
          ),
        ],
      ),
      _TestFailure(:final message) => Row(
        children: [
          Icon(Symbols.error, size: 20, color: colorScheme.error),
          const SizedBox(width: AppSpacing.m),
          Expanded(
            child: Text(message, style: TextStyle(color: colorScheme.error)),
          ),
        ],
      ),
    };
  }

  void _onPresetChanged(String? presetId) {
    if (presetId == null) {
      return;
    }
    setState(() {
      _preset = presetById(presetId);
      if (_preset.baseUrl.isNotEmpty) {
        _baseUrlController.text = _preset.baseUrl;
      }
      // 名称未填写时跟随预设，已填写的自定义名称不覆盖。
      if (_nameController.text.trim().isEmpty && _preset.id != 'custom') {
        _nameController.text = _preset.name;
      }
      // 换预设意味着协议变化，之前的测试结论不再有效。
      _testStatus = const _TestIdle();
    });
  }

  Future<void> _addModel() async {
    final idController = TextEditingController();
    var supportsReasoning = false;
    var switchTouched = false;
    final added = await showDialog<ProfileModel>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          icon: Icon(
            Symbols.add,
            color: Theme.of(context).colorScheme.primary,
          ),
          title: const Text('添加模型'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: idController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: '模型 id',
                  hintText: '如：deepseek-reasoner',
                ),
                onChanged: (value) {
                  // 用户没碰过开关时跟随 id 启发式预填。
                  if (!switchTouched) {
                    setDialogState(
                      () => supportsReasoning = guessSupportsReasoning(value),
                    );
                  }
                },
              ),
              const SizedBox(height: AppSpacing.m),
              SwitchListTile(
                title: const Text('支持推理'),
                value: supportsReasoning,
                onChanged: (value) => setDialogState(() {
                  supportsReasoning = value;
                  switchTouched = true;
                }),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final id = idController.text.trim();
                if (id.isEmpty) {
                  return;
                }
                Navigator.of(context).pop(
                  ProfileModel(id: id, supportsReasoning: supportsReasoning),
                );
              },
              child: const Text('添加'),
            ),
          ],
        ),
      ),
    );
    if (added == null || !mounted) {
      return;
    }
    setState(() {
      if (_models.every((m) => m.id != added.id)) {
        _models = [..._models, added];
      }
      _defaultModel ??= added.id;
    });
  }

  String? _required(String? value) {
    return (value == null || value.trim().isEmpty) ? '必填项' : null;
  }

  Future<void> _testConnection() async {
    setState(() => _testStatus = const _TestRunning());
    // 用表单当前值构造临时配置，不要求先保存。
    final profile = ProviderProfile(
      id: widget.profileId ?? 'unsaved',
      name: _nameController.text.trim(),
      baseUrl: _baseUrlController.text.trim(),
      protocol: _preset.protocol,
      presetId: _preset.id,
    );
    final provider = ref
        .read(aiProviderFactoryProvider)(profile, _apiKeyController.text.trim());
    try {
      // listModels 一次调用同时覆盖连通性、鉴权校验与候选拉取。
      final models = await provider.listModels();
      if (!mounted) {
        return;
      }
      setState(() {
        // 已存在的条目保留用户的推理标记，新 id 按启发式预填。
        final existing = {for (final m in _models) m.id: m};
        _models = [
          for (final model in models)
            existing[model.id] ??
                ProfileModel(
                  id: model.id,
                  supportsReasoning: guessSupportsReasoning(model.id),
                ),
        ];
        _testStatus = _TestSuccess(models.length);
      });
    } on Failure catch (e) {
      if (mounted) {
        setState(() => _testStatus = _TestFailure(e.userMessage));
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _saving = true);
    final repository = ref.read(providerProfileRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final profile = await repository.saveProfile(
        id: widget.profileId,
        name: _nameController.text.trim(),
        baseUrl: _baseUrlController.text.trim(),
        protocol: _preset.protocol,
        presetId: _preset.id,
        defaultModel: _defaultModel,
        models: _models,
      );
      final apiKey = _apiKeyController.text.trim();
      if (_preset.requiresApiKey && apiKey.isNotEmpty) {
        await repository.writeApiKey(profile.id, apiKey);
      }
      if (mounted) {
        messenger.showSnackBar(const SnackBar(content: Text('已保存')));
        context.pop();
      }
    } on Failure catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(e.userMessage)));
        setState(() => _saving = false);
      }
    }
  }
}
