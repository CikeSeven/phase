import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/error/failure.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_icon_badge.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../data/models/memory_entry.dart';
import '../../../data/repositories/memory_repository.dart';
import '../chat/chat_controller.dart';

class MemoriesPage extends ConsumerStatefulWidget {
  const MemoriesPage({super.key});
  @override
  ConsumerState<MemoriesPage> createState() => _MemoriesPageState();
}

class _MemoriesPageState extends ConsumerState<MemoriesPage> {
  final _search = TextEditingController();
  String? _error;
  final _deleting = <String>{};
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _delete(MemoryEntry entry) async {
    if (_deleting.contains(entry.id)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AppDialog(
        title: '删除记忆？',
        icon: Symbols.delete,
        tone: AppTone.error,
        content: const Text('删除后不再参与检索，摘要不会将它重新写回。历史对话中的文字仍保留。'),
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
    if (confirmed != true || !mounted) return;
    setState(() {
      _deleting.add(entry.id);
      _error = null;
    });
    try {
      await (await ref.read(memoryRepositoryProvider.future)).delete(entry.id);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e is Failure ? e.userMessage : '删除记忆失败');
      }
    } finally {
      if (mounted) setState(() => _deleting.remove(entry.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(memoriesProvider);
    final assistants = ref.watch(assistantsProvider).value ?? [];
    final names = {for (final a in assistants) a.id: a.name};
    return AppScaffold(
      title: '长期记忆',
      actions: [
        IconButton(
          tooltip: '添加记忆',
          icon: const Icon(Symbols.add),
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => const MemoryEditor(),
          ),
        ),
      ],
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: '搜索记忆',
                prefixIcon: Icon(Symbols.search),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('在助手编辑中选择记忆范围。写入按会话权限模式执行，普通结果和摘要不自动存为记忆。'),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Expanded(
            child: entries.when(
              loading: () => const Center(child: AppLoadingIndicator()),
              error: (e, _) => Center(
                child: TextButton(
                  onPressed: () => ref.invalidate(memoriesProvider),
                  child: Text(e is Failure ? e.userMessage : '读取失败，点击重试'),
                ),
              ),
              data: (items) {
                final filtered = items
                    .where(
                      (e) => e.content.toLowerCase().contains(
                        _search.text.toLowerCase(),
                      ),
                    )
                    .toList();
                if (filtered.isEmpty) {
                  return const Center(child: Text('暂无匹配的记忆'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final e = filtered[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            '${e.assistantId == null ? '全局' : names[e.assistantId] ?? '已删除的助手'} · ${e.enabled ? '已启用' : '已停用'}',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          const SizedBox(height: 8),
                          SelectableText(e.content),
                          const SizedBox(height: 8),
                          Text(
                            '来源消息：${e.sourceMessageId ?? '用户编辑'}\n来源运行：${e.sourceRunId ?? '无'}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Wrap(
                            children: [
                              TextButton.icon(
                                onPressed: _deleting.contains(e.id)
                                    ? null
                                    : () => showDialog<void>(
                                        context: context,
                                        builder: (_) => MemoryEditor(entry: e),
                                      ),
                                icon: const Icon(Symbols.edit),
                                label: const Text('编辑'),
                              ),
                              TextButton.icon(
                                onPressed: _deleting.contains(e.id)
                                    ? null
                                    : () => _delete(e),
                                style: TextButton.styleFrom(
                                  foregroundColor: Theme.of(context)
                                      .colorScheme
                                      .error,
                                ),
                                icon: const Icon(Symbols.delete),
                                label: const Text('删除'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class MemoryEditor extends ConsumerStatefulWidget {
  const MemoryEditor({this.entry, super.key});
  final MemoryEntry? entry;
  @override
  ConsumerState<MemoryEditor> createState() => _MemoryEditorState();
}

class _MemoryEditorState extends ConsumerState<MemoryEditor> {
  late final _content = TextEditingController(
    text: widget.entry?.content ?? '',
  );
  late bool _enabled = widget.entry?.enabled ?? true;
  String? _assistantId;
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _content.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repository = await ref.read(memoryRepositoryProvider.future);
      if (widget.entry case final entry?) {
        await repository.update(
          entry.id,
          content: _content.text,
          enabled: _enabled,
        );
      } else {
        await repository.add(content: _content.text, assistantId: _assistantId);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e is Failure ? e.userMessage : '保存记忆失败';
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final assistants = ref.watch(assistantsProvider);
    return PopScope(
      canPop: !_saving,
      child: AppDialog(
        title: widget.entry == null ? '添加记忆' : '编辑记忆',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.entry == null) ...[
              DropdownButtonFormField<String>(
                initialValue: _assistantId ?? '',
                isExpanded: true,
                decoration: const InputDecoration(labelText: '所属范围'),
                items: [
                  const DropdownMenuItem(value: '', child: Text('全局')),
                  for (final a in assistants.value ?? [])
                    DropdownMenuItem(
                      value: a.id,
                      child: Text(a.name, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: _saving
                    ? null
                    : (id) =>
                          setState(() => _assistantId = id == '' ? null : id),
              ),
              const SizedBox(height: 16),
            ],
            TextField(
              controller: _content,
              enabled: !_saving,
              minLines: 3,
              maxLines: 8,
              maxLength: 2000,
              decoration: const InputDecoration(labelText: '记忆内容'),
            ),
            if (widget.entry != null)
              SwitchListTile(
                title: const Text('启用'),
                value: _enabled,
                onChanged: _saving ? null : (v) => setState(() => _enabled = v),
              ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const AppLoadingIndicator(size: 20)
                : const Text('保存'),
          ),
        ],
      ),
    );
  }
}
