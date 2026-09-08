import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../core/error/failure.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/models/provider_profile.dart';
import '../../../data/repositories/provider_profile_repository.dart';
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

  _TestStatus _testStatus = const _TestIdle();

  /// 测试连接成功后拉到的模型候选，也是默认模型下拉的选项来源。
  List<String> _availableModels = const [];
  String _defaultModel = '';

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
          _availableModels = profile.models;
          _defaultModel = profile.defaultModel ?? '';
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
                  const SizedBox(height: AppSpacing.l),
                  _buildDefaultModelField(),
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

  /// 默认模型：可下拉候选（测试连接拉取），也接受直接手输。
  Widget _buildDefaultModelField() {
    return Autocomplete<String>(
      initialValue: TextEditingValue(text: _defaultModel),
      optionsBuilder: (value) {
        final query = value.text.toLowerCase();
        return _availableModels.where(
          (model) => model.toLowerCase().contains(query),
        );
      },
      onSelected: (model) => _defaultModel = model,
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: const InputDecoration(
            labelText: '默认模型',
            hintText: '测试连接后可下拉选择，也可直接输入',
          ),
          onChanged: (value) => _defaultModel = value,
        );
      },
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
        _availableModels = [for (final model in models) model.id];
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
        defaultModel: _defaultModel.trim(),
        models: _availableModels,
      );
      final apiKey = _apiKeyController.text.trim();
      if (apiKey.isNotEmpty) {
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
