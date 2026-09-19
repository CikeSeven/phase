import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/models/attachment.dart';
import '../../../data/models/tool_call_record.dart';
import '../../../data/repositories/tool_call_repository.dart';
import '../tools/tool_card.dart';
import 'tool_artifact_viewer.dart';

part 'tool_call_card.g.dart';

/// 一条工具记录的流：卡片跟随记录状态更新。
///
/// 记录被删除时流不发值，卡片整块不显示，不伪造一次调用。
@riverpod
Stream<ToolCallRecord> toolCallRecord(Ref ref, String toolCallId) async* {
  final repository = await ref.watch(toolCallRepositoryProvider.future);
  yield* repository.watchById(toolCallId);
}

/// 聊天流里的工具卡片：工具记录按 [toolCallId] 从仓储读。
///
/// 消息只保存记录 id（design 第五部分 §2.3），参数与结果留在 tool_calls；
/// 卡片展开后展示输入参数、输出内容和附件。
class ToolCallCard extends ConsumerWidget {
  const ToolCallCard({
    required this.toolCallId,
    this.attachments = const {},
    super.key,
  });

  final String toolCallId;

  /// 会话附件索引：把记录里的产物 id 还原成可查看的文件。
  final Map<String, Attachment> attachments;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final record = ref.watch(toolCallRecordProvider(toolCallId)).value;
    if (record == null) return const SizedBox.shrink();
    return ToolCard(
      record: record,
      artifacts: [
        for (final id in record.artifacts)
          if (attachments[id] != null) attachments[id]!,
      ],
      onOpenArtifact: (attachment) => showToolArtifact(context, attachment),
    );
  }
}
