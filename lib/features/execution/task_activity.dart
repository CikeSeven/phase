import 'execution_api.g.dart';

/// 面板只携带最近消息片段；稳定 ID 让流式完成快照原位替换，而非重复追加。
class TaskMessage {
  const TaskMessage({
    required this.id,
    required this.kind,
    required this.label,
    required this.text,
  });

  final String id;
  final TaskPanelMessageKind kind;
  final String label;
  final String text;

  TaskMessage get bounded => TaskMessage(
    id: id,
    kind: kind,
    label: panelExcerpt(label, limit: 100),
    text: panelExcerpt(text, limit: 480),
  );

  TaskPanelMessage toBridge() =>
      TaskPanelMessage(id: id, kind: kind, label: label, text: text);
}

class TaskActivity {
  const TaskActivity({
    this.phase = TaskPanelPhase.waitingModel,
    this.status = '正在处理',
    this.messages = const [],
    this.lastToolStatus,
  });

  static const maxMessages = 6;
  final TaskPanelPhase phase;
  final String status;
  final List<TaskMessage> messages;
  final String? lastToolStatus;

  String get waitingStatus => lastToolStatus ?? '正在处理';

  TaskActivity copyWith({
    TaskPanelPhase? phase,
    String? status,
    List<TaskMessage>? messages,
    String? lastToolStatus,
  }) => TaskActivity(
    phase: phase ?? this.phase,
    status: status ?? this.status,
    messages: messages == null
        ? this.messages
        : List.unmodifiable(
            messages
                .skip((messages.length - maxMessages).clamp(0, messages.length))
                .map((message) => message.bounded),
          ),
    lastToolStatus: lastToolStatus ?? this.lastToolStatus,
  );

  TaskActivity upsert(TaskMessage value) {
    final index = messages.indexWhere((entry) => entry.id == value.id);
    final next = [...messages];
    if (index < 0) {
      next.add(value);
    } else {
      next[index] = value;
    }
    return copyWith(messages: next);
  }

  /// 同一次模型响应按 Part 顺序更新；保留前轮正文与已执行工具。
  TaskActivity replaceResponse(String messageId, List<TaskMessage> parts) =>
      copyWith(
        messages: [
          ...messages.where((entry) => !entry.id.startsWith('$messageId/')),
          ...parts,
        ],
      );

  TaskActivity waitForResponse() =>
      copyWith(phase: TaskPanelPhase.waitingModel, status: waitingStatus);
}

class UserActionRequest {
  const UserActionRequest({
    required this.runId,
    required this.toolCallId,
    required this.prompt,
  });
  final String runId;
  final String toolCallId;
  final String prompt;
}

String panelExcerpt(String value, {int limit = 800}) {
  if (value.length <= limit) return value;
  var start = value.length - limit;
  // UTF-16 的低代理项不能独立跨越桥接边界。
  if (value.codeUnitAt(start) & 0xfc00 == 0xdc00) start++;
  return '…${value.substring(start)}';
}
