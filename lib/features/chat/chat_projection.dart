import 'dart:convert';

import '../../data/models/chat_message.dart';
import '../../data/models/message_part.dart';
import '../../data/repositories/conversation_repository.dart';
import 'chat_state.dart';

/// 当前分支的展示投影；同一次运行及没有新用户输入的后台续答共用回答区。
///
/// [thread] 来自 repository 的 watch 流，是持久化事实；
/// [state] 只提供尚未落库的流式内容。
///
/// 工具结果消息（role: tool）是回填给模型的上下文，不作为对话正文展示：
/// 调用与结果由助手消息里的 [ToolCallPart] 引用记录、以工具卡片渲染，
/// 模型提出的调用与执行结果不冒充助手回答。
///
/// 工具循环每轮落一条助手消息（数据层如此，协议回填依赖它），这里把属于
/// 同一次运行的连续助手消息合并成一个回答区，后台续答按已保存的任务来源归组。
/// 工具卡片按 Part 顺序保留；合并只发生在视图层，不改写任何落库内容。
List<ChatMessage> visibleMessages(ConversationThread thread, ChatState state) {
  // 流式内容覆盖的是当前分支末尾那条助手消息（本次运行正在写入的行）。
  // 分支末尾是隐藏的结果消息时不覆盖：那时流式内容属于上一轮，覆盖已落库的
  // 助手消息会把它的工具卡片抹掉。
  final streaming = state.isGenerating && state.streamingParts.isNotEmpty;
  final tail = thread.branch.length - 1;
  final visible = <ChatMessage>[];
  for (var index = 0; index <= tail; index++) {
    final message = thread.branch[index];
    if (message.role == ChatRole.tool ||
        (message.role == ChatRole.system && !message.hasVisibleContent)) {
      continue;
    }
    final live =
        streaming &&
        index == tail &&
        message.role == ChatRole.assistant &&
        message.id == state.streamingMessageId;
    visible.add(
      live
          ? message.copyWith(
              parts: state.streamingParts,
              status: MessageStatus.streaming,
            )
          : message,
    );
  }
  return _mergeAnswerRuns(visible, _answerGroups(thread.branch));
}

/// 完成通知只延续其任务来源的回答区，新用户输入或其他回答区会截断归组。
Map<String, String> _answerGroups(List<ChatMessage> messages) {
  final groups = <String, String>{};
  final runGroups = <String, String>{};
  final taskOrigins = <String, ({String group, String? userMessageId})>{};
  String? userMessageId;
  String? previousGroup;
  for (final message in messages) {
    if (message.role == ChatRole.user) {
      userMessageId = message.id;
      previousGroup = null;
    }
    final runId = message.runId;
    if (runId != null && message.role == ChatRole.system) {
      final continuationGroup = previousGroup;
      final taskIds = _completedTaskIds(message);
      if (taskIds != null) {
        final continuesAnswer =
            continuationGroup != null &&
            (runGroups[runId] == null ||
                runGroups[runId] == continuationGroup) &&
            taskIds.isNotEmpty &&
            taskIds.every((id) {
              final origin = taskOrigins[id];
              return origin != null &&
                  origin.group == continuationGroup &&
                  origin.userMessageId == userMessageId;
            });
        runGroups[runId] = continuesAnswer ? continuationGroup : message.id;
      }
    }
    if (message.role == ChatRole.tool) {
      if (runId != null) {
        final taskId = _startedTaskId(message);
        if (taskId != null) {
          taskOrigins.putIfAbsent(
            taskId,
            () => (
              group: runGroups[runId] ?? runId,
              userMessageId: userMessageId,
            ),
          );
        }
      }
      continue;
    }
    if (message.role == ChatRole.system && !message.hasVisibleContent) {
      continue;
    }
    previousGroup = message.role == ChatRole.assistant
        ? runGroups[runId] ?? runId
        : null;
    if (message.role == ChatRole.assistant && previousGroup != null) {
      groups[message.id] = previousGroup;
    }
  }
  return groups;
}

String? _startedTaskId(ChatMessage message) {
  if (!message.parts.any((part) => part is ToolResultPart)) return null;
  final text = message.text;
  if (!text.contains('"background"')) return null;
  try {
    if (jsonDecode(text) case {
      'taskId': final String taskId,
      'background': bool(),
    }) {
      return taskId;
    }
  } on FormatException {
    // 非结构化或不完整的结果不提供任务归组依据。
  }
  return null;
}

List<String>? _completedTaskIds(ChatMessage message) {
  final part = message.parts
      .whereType<RuntimeContextPart>()
      .where((part) => part.section == 'task_completion')
      .firstOrNull;
  if (part == null) return null;
  const prefix = '<phase_runtime_context section="task_completion">\n';
  const suffix = '\n</phase_runtime_context>';
  if (!part.text.startsWith(prefix) || !part.text.endsWith(suffix)) {
    return const [];
  }
  try {
    final decoded = jsonDecode(
      part.text.substring(prefix.length, part.text.length - suffix.length),
    );
    if (decoded case {'tasks': final List tasks}) {
      final ids = <String>[];
      for (final task in tasks) {
        if (task case {'taskId': final String id}) {
          ids.add(id);
        } else {
          return const [];
        }
      }
      return ids;
    }
  } on FormatException {
    // 无法识别的历史通知保持独立展示。
  }
  return const [];
}

/// 合并工具轮之前，把仅含一个公开思考块的消息总耗时归还给该块。
/// 多块且没有逐块计时的记录无法拆分，不把整轮耗时冒充任一段的时间。
ChatMessage _withRecordedThinkingDuration(ChatMessage message) {
  final duration = message.thinkingDurationMs;
  if (duration == null || message.status == MessageStatus.streaming) {
    return message;
  }
  final reasoning = message.parts
      .whereType<ReasoningPart>()
      .where((part) => part.publicText.isNotEmpty)
      .toList();
  if (reasoning.length != 1 || reasoning.single.durationMs != null) {
    return message;
  }
  final part = reasoning.single;
  return message.copyWith(
    parts: [
      for (final entry in message.parts)
        if (identical(entry, part))
          ReasoningPart(
            publicText: part.publicText,
            partId: part.partId,
            providerData: part.providerData,
            startedAt: part.startedAt,
            durationMs: duration,
          )
        else
          entry,
    ],
  );
}

/// 把同一回答区的连续助手消息合并为渲染投影。
///
/// 用户消息与可见系统消息保留边界；无 runId 的相邻老消息沿用原分组规则。
List<ChatMessage> _mergeAnswerRuns(
  List<ChatMessage> messages,
  Map<String, String> groups,
) {
  final merged = <ChatMessage>[];
  for (final message in messages) {
    final previous = merged.isEmpty ? null : merged.last;
    if (previous != null &&
        previous.role == ChatRole.assistant &&
        message.role == ChatRole.assistant &&
        (groups[previous.id] ?? previous.runId) ==
            (groups[message.id] ?? message.runId)) {
      merged[merged.length - 1] = _mergeAnswers(previous, message);
      continue;
    }
    merged.add(message);
  }
  return merged;
}

/// 两条同一回答区的助手消息合并成一条渲染用消息。
///
/// 身份沿用首条：流式期间新增一轮不会重建气泡，阅读位置与思考面板的
/// 手动展开状态都保留。状态取最后一次终态，任一还在流式则按流式展示
/// （生成光标留在回答区末尾）；用量取最后一次有值的；思考耗时按各轮合计。
ChatMessage _mergeAnswers(ChatMessage head, ChatMessage tail) {
  head = _withRecordedThinkingDuration(head);
  tail = _withRecordedThinkingDuration(tail);
  final headThinking = head.thinkingDurationMs;
  final tailThinking = tail.thinkingDurationMs;
  return ChatMessage(
    id: head.id,
    conversationId: head.conversationId,
    parentId: head.parentId,
    runId: head.runId,
    role: head.role,
    status: head.status == MessageStatus.streaming
        ? MessageStatus.streaming
        : tail.status,
    parts: _mergeAnswerParts(head, tail),
    // 同一运行保留原模型名，跨运行续答展示最近回复的模型。
    modelLabel: head.runId == tail.runId
        ? head.modelLabel ?? tail.modelLabel
        : tail.modelLabel ?? head.modelLabel,
    usage: tail.usage ?? head.usage,
    thinkingDurationMs: headThinking == null
        ? tailThinking
        : (tailThinking == null ? headThinking : headThinking + tailThinking),
    createdAt: head.createdAt,
  );
}

/// 拼接两条消息的内容块，保持各自的 Part 顺序。
///
/// 只在正文接正文时补一个空行：两轮正文直接相连会被渲染成一段。思考不补——
/// 每轮思考各自成区，工具调用或正文天然把它们隔开。
List<MessagePart> _mergeAnswerParts(ChatMessage head, ChatMessage tail) {
  final parts = [...head.parts];
  if (tail.parts.isNotEmpty &&
      parts.isNotEmpty &&
      parts.last is TextPart &&
      tail.parts.first is TextPart) {
    parts.add(const TextPart(text: '\n\n'));
  }
  return [...parts, ...tail.parts];
}
