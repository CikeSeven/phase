import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/error/failure.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../data/models/attachment.dart';
import '../../../data/models/tool_call_record.dart';
import '../../../data/repositories/conversation_repository.dart';
import '../../../data/repositories/tool_call_repository.dart';
import '../chat/tool_artifact_viewer.dart';
import 'tool_card.dart';

/// 一个会话的执行记录：按时间列出工具调用、决定与结果。
class ToolRecordsPage extends ConsumerStatefulWidget {
  const ToolRecordsPage({required this.conversationId, super.key});

  final String conversationId;

  @override
  ConsumerState<ToolRecordsPage> createState() => _ToolRecordsPageState();
}

class _ToolRecordsPageState extends ConsumerState<ToolRecordsPage> {
  late Future<(List<ToolCallRecord>, Map<String, Attachment>)> _load;

  @override
  void initState() {
    super.initState();
    _load = _loadRecords();
  }

  Future<(List<ToolCallRecord>, Map<String, Attachment>)> _loadRecords() async {
    final conversations = await ref.read(conversationRepositoryProvider.future);
    final repository = await ref.read(toolCallRepositoryProvider.future);
    final attachments = await conversations.attachmentsFor(
      widget.conversationId,
    );
    final runs = await _runIds(conversations);
    final records = <ToolCallRecord>[];
    for (final runId in runs) {
      records.addAll(await repository.getByRun(runId));
    }
    records.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return (records, {for (final item in attachments) item.id: item});
  }

  /// 该会话的运行 id：工具记录挂在运行下。
  Future<List<String>> _runIds(ConversationRepository conversations) async {
    final thread = await conversations.getThread(widget.conversationId);
    if (thread == null) return const [];
    final runIds = <String>{};
    for (final message in thread.messages) {
      final runId = message.runId;
      if (runId != null) runIds.add(runId);
    }
    return runIds.toList();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: '执行记录',
      subtitle: '本会话的工具调用、决定与结果',
      actions: [
        IconButton(
          tooltip: '刷新',
          onPressed: () => setState(() => _load = _loadRecords()),
          icon: const Icon(Symbols.refresh),
        ),
      ],
      body: FutureBuilder(
        future: _load,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            final error = snapshot.error;
            return AppEmptyState(
              icon: Symbols.error,
              title: '暂时无法读取记录',
              message: error is Failure ? error.userMessage : '读取失败，请重试',
            );
          }
          if (!snapshot.hasData) {
            return const Center(
              child: AppLoadingIndicator(semanticsLabel: '正在读取记录'),
            );
          }
          final (records, attachments) = snapshot.data!;
          if (records.isEmpty) {
            return const AppEmptyState(
              icon: Symbols.history,
              title: '还没有执行记录',
              message: '当模型调用工具时，这里会按顺序记录每一次动作与结果。',
            );
          }
          return ListView.builder(
            key: const ValueKey('tool-records-list'),
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.m),
            itemCount: records.length,
            itemBuilder: (context, index) {
              final record = records[index];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (index == 0 || !_sameRun(records[index - 1], record)) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.l,
                        AppSpacing.m,
                        AppSpacing.l,
                        AppSpacing.xs,
                      ),
                      child: Text(
                        '运行 ${record.runId} · '
                        '${_formatTime(record.createdAt)}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                  ToolCard(
                    record: record,
                    artifacts: [
                      for (final id in record.artifacts)
                        if (attachments[id] != null) attachments[id]!,
                    ],
                    onOpenArtifact: (attachment) =>
                        showToolArtifact(context, attachment),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  bool _sameRun(ToolCallRecord a, ToolCallRecord b) => a.runId == b.runId;

  String _formatTime(DateTime time) {
    final local = time.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${local.month}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
  }
}
