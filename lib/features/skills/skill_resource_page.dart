import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failure.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/logger.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../data/repositories/skill_repository.dart';
import '../tools/tool.dart';
import 'read_skill_tool.dart';

class SkillResourcePage extends ConsumerStatefulWidget {
  const SkillResourcePage({super.key, required this.id, required this.path});
  final String id;
  final String path;
  @override
  ConsumerState<SkillResourcePage> createState() => _SkillResourcePageState();
}

class _SkillResourcePageState extends ConsumerState<SkillResourcePage> {
  final _cancellation = RunCancellation();
  final _scroll = ScrollController();
  final _previous = <int>[];
  SkillLease? _lease;
  Map<String, dynamic>? _page;
  String? _error;
  bool _busy = true;
  @override
  void initState() {
    super.initState();
    _read(0);
  }

  @override
  void dispose() {
    _cancellation.cancel();
    _scroll.dispose();
    final lease = _lease;
    if (lease != null) {
      unawaited(
        lease.close().catchError((Object _) {
          AppLogger.warning('Skill 查看结束后文件清理失败');
        }),
      );
    }
    super.dispose();
  }

  Future<void> _read(int offset) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repository = await ref.read(skillRepositoryProvider.future);
      _cancellation.throwIfCancelled();
      if (_lease == null) {
        final lease = await repository.acquire({widget.id}, enabledOnly: false);
        if (!mounted) {
          await lease.close();
          return;
        }
        _lease = lease;
      }
      final entry = await repository.get(widget.id);
      if (entry == null || entry.deleting || _lease!.skills.isEmpty) {
        throw const SkillFailure('deleted', 'Skill 已删除');
      }
      final page = await readSkillResource(
        _lease!.skills.single,
        widget.path,
        offset: offset,
        cancellation: _cancellation,
      );
      if (!mounted) return;
      setState(() {
        _page = page;
        _busy = false;
      });
      if (_scroll.hasClients) _scroll.jumpTo(0);
    } on ToolCancelled {
      /* 页面关闭时终止读取。 */
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error is Failure ? error.userMessage : '资源读取失败';
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: '资源查看',
    body: ListView(
      controller: _scroll,
      padding: const EdgeInsets.all(AppSpacing.l),
      children: [
        Text(widget.path, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.s),
        if (_busy) const Center(child: AppLoadingIndicator()),
        if (_error != null) ...[
          Text(_error!),
          TextButton(
            onPressed: () => _read(_page?['offset'] as int? ?? 0),
            child: const Text('重试'),
          ),
        ],
        if (_page != null) ...[
          Text(
            '${_page!['name']} · 版本 ${(_page!['revision'] as String).substring(0, 12)}',
          ),
          Text(_page!['source'] as String),
          if (_page!['execution'] != null) Text(_page!['execution'] as String),
          const SizedBox(height: AppSpacing.l),
          SelectableText(_page!['content'] as String),
          const SizedBox(height: AppSpacing.l),
          Wrap(
            spacing: AppSpacing.m,
            children: [
              if (_previous.isNotEmpty)
                OutlinedButton(
                  onPressed: _busy ? null : () => _read(_previous.removeLast()),
                  child: const Text('上一段'),
                ),
              if (_page!['nextOffset'] != null)
                FilledButton.tonal(
                  onPressed: _busy
                      ? null
                      : () {
                          _previous.add(_page!['offset'] as int);
                          _read(_page!['nextOffset'] as int);
                        },
                  child: const Text('下一段'),
                ),
            ],
          ),
        ],
      ],
    ),
  );
}
