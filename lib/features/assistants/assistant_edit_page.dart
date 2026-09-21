import '../tools/tool_presentation.dart';
import '../../../data/models/memory_entry.dart';
import '../../../core/widgets/app_dropdown.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/error/failure.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_icon_badge.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../data/models/assistant.dart';
import '../../../data/models/model_selection.dart';
import '../../../data/repositories/assistant_repository.dart';
import '../chat/chat_controller.dart';
import 'assistant_model_sheet.dart';
import 'assistant_tool_policy_section.dart';
import '../mcp/assistant_mcp_section.dart';
import '../skills/assistant_skills_section.dart';
import '../../../data/models/tool_policy.dart';

/// 助手新增 / 编辑：名称、系统提示词、默认模型与工具范围。
class AssistantEditPage extends ConsumerStatefulWidget {
  const AssistantEditPage({super.key, this.assistantId});

  /// null 表示新增。
  final String? assistantId;

  @override
  ConsumerState<AssistantEditPage> createState() => _AssistantEditPageState();
}

class _AssistantEditPageState extends ConsumerState<AssistantEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _promptController = TextEditingController();

  ModelSelection? _defaultModel;
  ToolPolicyConfig _toolPolicy = defaultToolPolicyConfig;
  Set<String> _skillIds = {};
  MemoryScope _memoryScope = MemoryScope.disabled;
  bool _clearDefaultModel = false;
  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  bool get _isNew => widget.assistantId == null;
  bool get _canDelete => !_isNew && widget.assistantId != defaultAssistantId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_isNew) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final repository = await ref.read(assistantRepositoryProvider.future);
      final assistant = await repository.getById(widget.assistantId!);
      if (assistant == null) {
        if (mounted) {
          setState(() {
            _loadError = '助手已不存在。';
            _loading = false;
          });
        }
        return;
      }
      if (!mounted) return;
      setState(() {
        _nameController.text = assistant.name;
        _promptController.text = assistant.systemPrompt;
        _defaultModel = assistant.defaultModelSelection;
        _toolPolicy = assistant.toolPolicy;
        _skillIds = {...assistant.skillIds};
        _memoryScope = assistant.memoryScope;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error is Failure ? error.userMessage : '读取助手失败，请重试。';
        _loading = false;
      });
    }
  }

  Future<void> _pickDefaultModel() async {
    final picked = await showAssistantModelSheet(
      context,
      current: _defaultModel,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _defaultModel = picked;
      _clearDefaultModel = false;
    });
  }

  Future<void> _save() async {
    if (_saving || _loading || _loadError != null) return;
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    final controller = ref.read(chatControllerProvider.notifier);
    try {
      if (_isNew) {
        await controller.createAssistant(
          name: _nameController.text,
          systemPrompt: _promptController.text,
          defaultModelSelection: _defaultModel,
          toolPolicy: _toolPolicy,
          skillIds: _skillIds,
          memoryScope: _memoryScope,
        );
      } else {
        await controller.updateAssistant(
          id: widget.assistantId!,
          name: _nameController.text,
          systemPrompt: _promptController.text,
          defaultModelSelection: _defaultModel,
          clearDefaultModel: _clearDefaultModel,
          toolPolicy: _toolPolicy,
          skillIds: _skillIds,
          memoryScope: _memoryScope,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已保存助手')));
      context.pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error is Failure ? error.userMessage : '保存助手失败，请重试。'),
        ),
      );
    }
  }

  Future<void> _confirmDelete() async {
    if (!_canDelete || _saving || _loading || _loadError != null) return;
    final assistant = widget.assistantId;
    if (assistant == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AppDialog(
        title: '删除助手',
        description: '确定删除此助手吗？',
        icon: Symbols.delete,
        tone: AppTone.error,
        content: const SizedBox.shrink(),
        actions: [
          TextButton(
            key: const ValueKey('cancel-delete-assistant'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const ValueKey('confirm-delete-assistant'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref
          .read(chatControllerProvider.notifier)
          .deleteAssistant(assistant);
      if (!mounted) return;
      context.pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error is Failure ? error.userMessage : '删除助手失败，请重试。'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppScaffold(
      title: _isNew ? '新建助手' : '编辑助手',
      actions: [
        if (!_loading && _loadError == null) ...[
          if (_canDelete)
            IconButton(
              key: const ValueKey('delete-assistant'),
              tooltip: '删除助手',
              onPressed: _saving ? null : _confirmDelete,
              color: theme.colorScheme.error,
              icon: const Icon(Symbols.delete),
            ),
          IconButton(
            key: const ValueKey('save-assistant'),
            tooltip: _saving ? '正在保存助手' : '保存助手',
            onPressed: _saving ? null : _save,
            color: theme.colorScheme.primary,
            icon: _saving
                ? const AppLoadingIndicator.small(semanticsLabel: '正在保存助手')
                : const Icon(Symbols.save),
          ),
        ],
      ],
      body: _loading
          ? const Center(child: AppLoadingIndicator(semanticsLabel: '正在读取助手'))
          : _loadError != null
          ? AppEmptyState(
              icon: Symbols.error,
              title: '无法读取助手',
              message: '$_loadError\n读取成功前不可编辑或保存。',
              action: FilledButton.tonal(
                onPressed: _load,
                child: const Text('重新加载'),
              ),
            )
          : Form(
              key: _formKey,
              child: ListView(
                key: const ValueKey('assistant-edit-scroll'),
                padding: const EdgeInsets.all(AppSpacing.l),
                children: [
                  TextFormField(
                    key: const ValueKey('assistant-name'),
                    controller: _nameController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: '名称',
                      hintText: '如「代码助手」',
                    ),
                    validator: (value) {
                      final name = value?.trim() ?? '';
                      if (name.isEmpty) return '请填写助手名称';
                      if (name.length > 100) return '名称最多 100 个字符';
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.l),
                  TextFormField(
                    key: const ValueKey('assistant-prompt'),
                    controller: _promptController,
                    minLines: 4,
                    maxLines: 12,
                    keyboardType: TextInputType.multiline,
                    decoration: const InputDecoration(
                      labelText: '系统提示词',
                      hintText: '写给模型的角色与规则，随每次请求发送',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text('默认模型', style: theme.textTheme.labelLarge),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '会话没有单独选择模型时使用它；留空则跟随最近使用的选择。',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s),
                  _DefaultModelRow(
                    selection: _defaultModel,
                    onPick: _pickDefaultModel,
                    onClear: _defaultModel == null
                        ? null
                        : () => setState(() {
                            _defaultModel = null;
                            _clearDefaultModel = true;
                          }),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AssistantToolPolicySection(
                    tools: ref.watch(toolRegistryProvider).tools.toList(),
                    policy: _toolPolicy,
                    onChanged: _saving
                        ? null
                        : (policy) => setState(() => _toolPolicy = policy),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AppDropdown<MemoryScope>(
                    label: '记忆读取与写入范围',
                    value: _memoryScope,
                    options: {
                      for (final scope in MemoryScope.values)
                        scope: scope.label,
                    },
                    onChanged: _saving
                        ? null
                        : (scope) => setState(() => _memoryScope = scope),
                  ),
                  const SizedBox(height: AppSpacing.l),
                  if (_memoryScope != MemoryScope.disabled) ...[
                    AppDropdown<ToolPolicy>(
                      label: '记忆写入',
                      value:
                          _toolPolicy.policies['write_memory'] ??
                          ToolPolicy.ask,
                      options: {
                        for (final value in ToolPolicy.values)
                          value: ToolPresentation.policyLabel(value),
                      },
                      onChanged: _saving
                          ? null
                          : (policy) => setState(
                              () => _toolPolicy = _toolPolicy.withPolicy(
                                'write_memory',
                                policy,
                              ),
                            ),
                    ),
                    const SizedBox(height: AppSpacing.l),
                  ],
                  AssistantSkillsSection(
                    ids: _skillIds,
                    policy:
                        _toolPolicy.policies['read_skill'] ?? ToolPolicy.ask,
                    onChanged: _saving
                        ? null
                        : (ids) => setState(() => _skillIds = ids),
                    onPolicyChanged: _saving
                        ? null
                        : (policy) => setState(
                            () => _toolPolicy = _toolPolicy.withPolicy(
                              'read_skill',
                              policy,
                            ),
                          ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AssistantMcpSection(
                    policy: _toolPolicy,
                    onChanged: _saving
                        ? null
                        : (policy) => setState(() => _toolPolicy = policy),
                  ),
                ],
              ),
            ),
    );
  }
}

class _DefaultModelRow extends StatelessWidget {
  const _DefaultModelRow({
    required this.selection,
    required this.onPick,
    this.onClear,
  });

  final ModelSelection? selection;
  final VoidCallback onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            key: const ValueKey('pick-default-model'),
            onPressed: onPick,
            icon: const Icon(Symbols.model_training, size: 18),
            label: Text(
              selection == null
                  ? '跟随当前选择'
                  : '${selection!.modelId} · ${selection!.reasoningEffort.label}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        if (onClear != null) ...[
          const SizedBox(width: AppSpacing.s),
          IconButton(
            key: const ValueKey('clear-default-model'),
            tooltip: '不使用默认模型',
            onPressed: onClear,
            icon: const Icon(Symbols.close),
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ],
      ],
    );
  }
}
