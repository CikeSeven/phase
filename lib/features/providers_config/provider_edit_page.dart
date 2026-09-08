import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../core/error/failure.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/repositories/provider_profile_repository.dart';

/// 服务商新增 / 编辑表单（`/settings/providers/new`、`/settings/providers/:id`）。
///
/// DESIGN.md §5.4：API Key obscureText + 可见切换，注明密钥仅保存在
/// 本机安全存储中；保存后立即 SnackBar 反馈。
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
                    const SizedBox(height: AppSpacing.xl),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: const Icon(Symbols.check),
                      label: const Text('保存'),
                    ),
                    // TODO(provider): 连接性校验按钮（validateKey），
                    // 结果显示为行内状态（成功 primary / 失败 error）。
                    // TODO(provider): 模型列表拉取（listModels）与选择。
                  ],
                ),
              ),
    );
  }

  String? _required(String? value) {
    return (value == null || value.trim().isEmpty) ? '必填项' : null;
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
