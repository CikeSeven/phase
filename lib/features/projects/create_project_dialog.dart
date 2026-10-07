import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/error/failure.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/app_loading_indicator.dart';
import '../../data/models/project.dart';
import '../../data/repositories/project_repository.dart';

Future<Project?> showCreateProjectDialog(BuildContext context) =>
    showDialog<Project>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _CreateProjectDialog(),
    );

class _CreateProjectDialog extends ConsumerStatefulWidget {
  const _CreateProjectDialog();

  @override
  ConsumerState<_CreateProjectDialog> createState() =>
      _CreateProjectDialogState();
}

class _CreateProjectDialogState extends ConsumerState<_CreateProjectDialog> {
  final _controller = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_saving) return;
    final name = _controller.text.trim();
    if (name.isEmpty || name.length > 100) {
      setState(() => _error = '项目名称需为 1–100 个字符');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repository = await ref.read(projectRepositoryProvider.future);
      final project = await repository.create(name);
      if (mounted) Navigator.of(context).pop(project);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error is Failure ? error.userMessage : '创建项目失败，请重试';
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope<Project>(
    canPop: !_saving,
    child: AppDialog(
      title: '新建项目',
      description: '为任务或代码库创建专属工作区，统一管理会话、代码与资料。',
      icon: LucideIcons.folderPlus,
      content: TextField(
        key: const ValueKey('project-name-input'),
        controller: _controller,
        autofocus: true,
        enabled: !_saving,
        maxLength: 100,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          labelText: '项目名称',
          hintText: '例如：相月移动端开发',
          counterText: '',
          errorText: _error,
          errorMaxLines: 4,
        ),
        onSubmitted: (_) => _create(),
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton.icon(
          onPressed: _saving ? null : _create,
          icon: _saving
              ? const AppLoadingIndicator.small()
              : const Icon(LucideIcons.plus),
          label: Text(_saving ? '创建中…' : '创建'),
        ),
      ],
    ),
  );
}
