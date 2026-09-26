import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/brand_colors.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/widgets/app_loading_indicator.dart';
import '../../../../data/models/agent_plan.dart';
import '../../../../data/repositories/plan_repository.dart';
import '../chat_controller.dart';

class PlanCard extends ConsumerStatefulWidget {
  const PlanCard({required this.plan, this.grouped = false, super.key});
  final AgentPlan plan;
  final bool grouped;
  @override
  ConsumerState<PlanCard> createState() => _PlanCardState();
}

class _PlanCardState extends ConsumerState<PlanCard> {
  bool _busy = false;
  String? _error;

  Future<void> _perform(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) {
        setState(() => _error = e is Failure ? e.userMessage : '计划操作失败，请重试');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.plan;
    final generating = ref.watch(
      chatControllerProvider.select(
        (s) => s.isGenerating || s.savingPermissionMode,
      ),
    );
    final disabled = generating || _busy;
    return Material(
      color: context.brandColors.tealContainer,
      borderRadius: widget.grouped ? BorderRadius.zero : AppRadius.mediumAll,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(p.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              '计划 · 修订 ${p.revision} · ${switch (p.status) {
                PlanStatus.draft => '待批准',
                PlanStatus.approved => '已批准并创建执行运行',
                PlanStatus.cancelled => '已取消',
              }}',
            ),
            const SizedBox(height: 12),
            for (final (i, step) in p.steps.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SelectableText('${i + 1}. $step'),
              ),
            const Text('批准当前修订后恢复规划前的权限档位，按该模式执行。'),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (p.status == PlanStatus.draft)
                  FilledButton(
                    onPressed: disabled
                        ? null
                        : () => _perform(
                            () => ref
                                .read(chatControllerProvider.notifier)
                                .approvePlan(p),
                          ),
                    child: const Text('批准并执行'),
                  ),
                TextButton.icon(
                  onPressed: disabled
                      ? null
                      : () => showDialog<void>(
                          context: context,
                          builder: (_) => _PlanEditor(plan: p),
                        ),
                  icon: const Icon(Symbols.edit),
                  label: Text(p.status == PlanStatus.draft ? '编辑' : '创建新修订'),
                ),
                if (p.status == PlanStatus.draft)
                  TextButton(
                    onPressed: disabled
                        ? null
                        : () => _perform(() async {
                            await (await ref.read(
                              planRepositoryProvider.future,
                            )).cancel(p.id, p.revision);
                          }),
                    child: const Text('取消计划'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanEditor extends ConsumerStatefulWidget {
  const _PlanEditor({required this.plan});
  final AgentPlan plan;
  @override
  ConsumerState<_PlanEditor> createState() => _PlanEditorState();
}

class _PlanEditorState extends ConsumerState<_PlanEditor> {
  late final _title = TextEditingController(text: widget.plan.title);
  late final _steps = widget.plan.steps
      .map((s) => TextEditingController(text: s))
      .toList();
  final _retired = <TextEditingController>[];
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _title.dispose();
    for (final c in [..._steps, ..._retired]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await (await ref.read(planRepositoryProvider.future)).edit(
        widget.plan.id,
        widget.plan.revision,
        _title.text,
        _steps.map((s) => s.text).toList(),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e is Failure ? e.userMessage : '保存计划失败';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AppDialog(
      title: '编辑计划',
      description: '保存后生成新修订，需要重新批准。',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _title,
            enabled: !_saving,
            maxLength: 200,
            decoration: const InputDecoration(labelText: '标题'),
          ),
          for (final (i, step) in _steps.indexed)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: TextField(
                controller: step,
                enabled: !_saving,
                minLines: 2,
                maxLines: 6,
                maxLength: 2000,
                decoration: InputDecoration(
                  labelText: '步骤 ${i + 1}',
                  suffixIcon: IconButton(
                    tooltip: '移除步骤',
                    onPressed: _saving
                        ? null
                        : () => setState(() {
                            _retired.add(_steps.removeAt(i));
                          }),
                    icon: const Icon(Symbols.remove_circle_outline),
                  ),
                ),
              ),
            ),
          TextButton.icon(
            onPressed: _saving || _steps.length >= 30
                ? null
                : () => setState(() => _steps.add(TextEditingController())),
            icon: const Icon(Symbols.add),
            label: const Text('添加步骤'),
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
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const AppLoadingIndicator(size: 20)
              : const Text('保存新修订'),
        ),
      ],
    ),
  );
}
