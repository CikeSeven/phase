import 'tool_policy.dart';

/// 一次工具调用的执行状态（design 第二部分 §5）。
enum ToolCallStatus {
  prepared,
  awaitingConfirmation,
  executing,
  succeeded,
  failed,
  rejected,
  cancelled,

  /// 已进入执行阶段但没有取得可靠结果；如实展示并提供核验入口。
  unknown,
}

/// 用户对一次确认的决定。
enum ToolDecision { approved, rejected, expired }

/// 工具执行通道。
enum ExecutionChannel { app, accessibility, shizuku, termux }

/// 工具调用记录：参数、用户决定与结果的唯一业务事实来源。
///
/// 参数在记录创建时确定，执行期间不再修改；新的尝试使用新记录。
class ToolCallRecord {
  const ToolCallRecord({
    required this.id,
    required this.runId,
    required this.assistantMessageId,
    required this.toolName,
    required this.arguments,
    required this.channel,
    required this.defaultPolicy,
    required this.createdAt,
    this.resultMessageId,
    this.providerCallId,
    this.providerData,
    this.target,
    this.status = ToolCallStatus.prepared,
    this.decision,
    this.confirmationRequestedAt,
    this.confirmationExpiresAt,
    this.decidedAt,
    this.result,
    this.artifacts = const [],
    this.errorCode,
    this.startedAt,
    this.finishedAt,
  });

  /// 应用生成的 id，同时用于 Dart、Kotlin 与通道内的同一次调用。
  final String id;
  final String runId;

  /// 提出该调用的助手消息。
  final String assistantMessageId;

  /// 结果消息；执行收口时与结果一起提交。
  final String? resultMessageId;

  /// 模型协议自己的调用 id，仅用于把结果回填给对应协议。
  final String? providerCallId;

  final String toolName;
  final Map<String, dynamic> arguments;

  /// 该调用需要回传给模型的协议状态（如 Anthropic 的 tool_use 块结构）。
  final Map<String, dynamic>? providerData;

  /// 动作目标（文件 URI、目标包名等）的展示文案。
  final String? target;
  final ExecutionChannel channel;

  /// 工具定义声明的默认策略；助手的工具策略可覆盖。
  final ToolPolicy defaultPolicy;

  final ToolCallStatus status;
  final ToolDecision? decision;
  final DateTime? confirmationRequestedAt;
  final DateTime? confirmationExpiresAt;
  final DateTime? decidedAt;

  /// 结果正文或结果引用；未知结果时为 null。
  final String? result;
  final List<String> artifacts;
  final String? errorCode;

  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? finishedAt;

  /// 状态流转的局部更新；未提供的字段保持不变（含可空字段）。
  ToolCallRecord copyWith({
    String? resultMessageId,
    ToolCallStatus? status,
    ToolDecision? decision,
    DateTime? confirmationRequestedAt,
    DateTime? confirmationExpiresAt,
    DateTime? decidedAt,
    String? result,
    List<String>? artifacts,
    String? errorCode,
    DateTime? startedAt,
    DateTime? finishedAt,
  }) {
    return ToolCallRecord(
      id: id,
      runId: runId,
      assistantMessageId: assistantMessageId,
      resultMessageId: resultMessageId ?? this.resultMessageId,
      providerCallId: providerCallId,
      toolName: toolName,
      arguments: arguments,
      providerData: providerData,
      target: target,
      channel: channel,
      defaultPolicy: defaultPolicy,
      status: status ?? this.status,
      decision: decision ?? this.decision,
      confirmationRequestedAt:
          confirmationRequestedAt ?? this.confirmationRequestedAt,
      confirmationExpiresAt:
          confirmationExpiresAt ?? this.confirmationExpiresAt,
      decidedAt: decidedAt ?? this.decidedAt,
      result: result ?? this.result,
      artifacts: artifacts ?? this.artifacts,
      errorCode: errorCode ?? this.errorCode,
      createdAt: createdAt,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
    );
  }
}
