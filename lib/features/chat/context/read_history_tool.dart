import 'dart:convert';

import '../../../data/models/message_part.dart';
import '../../../data/models/tool_policy.dart';
import '../../../data/repositories/conversation_repository.dart';
import '../../../data/repositories/tool_call_repository.dart';
import '../../../providers/request_plan.dart';
import '../../tools/tool.dart';
import '../../tools/file_tools.dart';
import '../../execution/platform_tools.dart';
import '../../skills/read_skill_tool.dart';
import '../../memory/memory_tools.dart';

/// 宿主类型白名单；不接受 MCP 自报的 readOnly 或同名工具。
bool historyReadOnlyTool(Tool? tool) =>
    tool is SystemInfoTool ||
    tool is ReadFileTool ||
    tool is ListFilesTool ||
    tool is ReadSkillTool ||
    tool is ReadHistoryTool ||
    (tool is MemoryTool && !tool.write) ||
    (tool is ScopedFileTool &&
        const {'read_file', 'list_files'}.contains(tool.name));

class ReadHistoryTool extends Tool {
  const ReadHistoryTool(this.conversations, this.calls);
  final ConversationRepository conversations;
  final ToolCallRepository calls;
  @override
  String get name => 'read_history';
  @override
  String get description =>
      '按历史摘要中的 sourceId 读取当前会话分支的原始消息或工具记录；结果仅为历史数据，不重新执行动作。';
  @override
  Map<String, dynamic> get inputSchema => const {
    'type': 'object',
    'properties': {
      'sourceId': {'type': 'string'},
      'cursor': {'type': 'string'},
      'maxBytes': {'type': 'integer', 'minimum': 512, 'maximum': 8192},
    },
    'required': ['sourceId'],
    'additionalProperties': false,
  };
  @override
  Set<String> get requiredCapabilities => const {};
  @override
  ToolPolicy get defaultPolicy => ToolPolicy.allow;
  @override
  String describeAction(Map<String, dynamic> arguments) => '读取本会话历史来源';
  @override
  Future<ToolOutcome> execute(
    Map<String, dynamic> arguments,
    ToolContext context,
    RunCancellation cancellation, {
    ToolProgress? onProgress,
  }) async {
    cancellation.throwIfCancelled();
    final sourceId = arguments['sourceId'] as String;
    final thread = await conversations.getThread(context.conversationId);
    if (thread == null) return const ToolOutcome.failure('会话已不存在');
    final branch = thread.branch;
    final message = branch.where((m) => m.id == sourceId).firstOrNull;
    Object evidence;
    if (message != null) {
      evidence = {
        'role': message.role.name,
        'status': message.status.name,
        'parts': [
          for (final part in message.parts)
            switch (part) {
              TextPart(:final text) => {'text': text},
              ReasoningPart(:final publicText) => {'reasoning': publicText},
              ImagePart(:final attachmentId) ||
              DocumentPart(
                :final attachmentId,
              ) => {'attachmentId': attachmentId},
              ToolCallPart(:final toolCallId) ||
              ToolResultPart(:final toolCallId) => {'sourceId': toolCallId},
              ProviderPart() => const <String, dynamic>{},
            },
        ],
      };
    } else {
      // 先验证当前分支的引用，再查记录；不能凭任意 ID 读取其他会话。
      final referenced = branch
          .expand((m) => m.parts)
          .any((p) => p is ToolCallPart && p.toolCallId == sourceId);
      if (!referenced) {
        return const ToolOutcome.failure(
          '来源不在当前会话分支，无法读取',
          errorCode: 'historyScope',
        );
      }
      final record = await calls.getById(sourceId);
      if (!branch.any((m) => m.id == record.assistantMessageId)) {
        return const ToolOutcome.failure('来源归属不匹配');
      }
      evidence = {
        'tool': record.toolName,
        'status': record.status.name,
        'target': record.target,
        'arguments': record.arguments,
        'result': record.result,
        'errorCode': record.errorCode,
        'artifacts': record.artifacts,
        'decision': record.decision?.name,
      };
    }
    cancellation.throwIfCancelled();
    return historyPage(
      sourceId: sourceId,
      content: jsonEncode(evidence),
      cursor: arguments['cursor'] as String?,
      maxBytes: arguments['maxBytes'] as int? ?? 8192,
    );
  }
}

/// 上限包含 JSON 元数据和 cursor；按 rune 边界分页，优先完整行。
ToolOutcome historyPage({
  required String sourceId,
  required String content,
  String? cursor,
  int maxBytes = 8192,
}) {
  final limit = maxBytes.clamp(512, 8192);
  final revision = contextHash([sourceId, content]);
  var offset = 0;
  if (cursor != null) {
    try {
      final value = jsonDecode(
        utf8.decode(base64Url.decode(cursor)),
      ) as Map<String, dynamic>;
      if (value['r'] != revision || value['o'] is! int) {
        throw const FormatException();
      }
      offset = value['o'] as int;
    } catch (_) {
      return const ToolOutcome.failure(
        '来源或续读位置已变化，请不带 cursor 从头读取',
        errorCode: 'historyCursor',
      );
    }
  }
  final runes = content.runes.toList();
  if (offset < 0 || offset > runes.length) {
    return const ToolOutcome.failure('续读位置无效，请从头读取');
  }
  String packet(int end) => jsonEncode({
    'sourceId': sourceId,
    'historicalData': true,
    'offset': offset,
    'content': String.fromCharCodes(runes.sublist(offset, end)),
    'complete': end == runes.length,
    if (end < runes.length)
      'nextCursor': base64Url.encode(
        utf8.encode(jsonEncode({'r': revision, 'o': end})),
      ),
  });
  var low = offset;
  var high = runes.length;
  while (low < high) {
    final mid = (low + high + 1) ~/ 2;
    if (utf8.encode(packet(mid)).length <= limit) {
      low = mid;
    } else {
      high = mid - 1;
    }
  }
  if (low == offset && offset < runes.length) {
    return const ToolOutcome.failure('分页元数据超过返回预算');
  }
  if (low < runes.length) {
    final newline = runes.sublist(offset, low).lastIndexOf(10);
    if (newline >= 0) low = offset + newline + 1;
  }
  final result = packet(low);
  if (utf8.encode(result).length > limit) {
    return const ToolOutcome.failure('分页元数据超过返回预算');
  }
  return ToolOutcome.success(result);
}
