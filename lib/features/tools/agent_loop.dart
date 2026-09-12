import '../../../data/models/message_part.dart';
import '../../../data/models/tool_call_record.dart';

/// 循环宿主：负责真实 IO（模型流、落库、工具执行），Loop 只决定顺序。
///
/// 「一次运行怎样推进」只有这一处实现；IO 与状态各自可测。
abstract interface class AgentLoopHost {
  /// 一轮模型请求；返回本轮完整内容与工具调用。
  ///
  /// 创建助手消息、节流落库、错误映射都由宿主完成。
  Future<StreamedTurn> streamTurn();

  /// 执行一次工具调用（含确认与状态记录）。
  Future<ExecutedTool> executeTool(ToolCall call, StreamedTurn turn);

  /// 本轮工具结果已回填，记录当前位置并开始下一轮。
  Future<void> finishTurn(StreamedTurn turn);

  /// 运行结束（含停止、失败与轮次上限）。
  Future<void> finish(AgentFinishReason reason);

  /// 当前是否已被用户停止。
  bool get isCancelled;
}

/// 一轮模型响应：内容块、工具调用与终态。
class StreamedTurn {
  const StreamedTurn({
    required this.messageId,
    required this.parts,
    required this.toolCalls,
    this.cancelled = false,
    this.failed = false,
    this.finishReason,
  });

  final String messageId;

  /// 已收口的内容块（含引用工具记录的 ToolCallPart）。
  final List<MessagePart> parts;

  final List<ToolCall> toolCalls;

  /// 本轮有可见内容（正文、思考、附件或工具调用）。
  bool get hasVisibleContent => parts.any((part) => part is! ProviderPart);

  /// 本轮被用户停止。
  final bool cancelled;

  /// 本轮以错误结束（模型或存储），不再进入工具调度。
  final bool failed;

  final AgentFinishReason? finishReason;
}

/// 模型提出的一次调用；参数组装完成后才交给执行器。
class ToolCall {
  const ToolCall({
    required this.callId,
    required this.toolName,
    required this.arguments,
    this.argumentsError,
    this.providerData,
  });

  /// 模型协议自己的调用 id，用于回填与配对。
  final String callId;
  final String toolName;
  final Map<String, dynamic> arguments;

  /// 参数 JSON 不完整或格式错误时的原因：如实反馈给模型，不从文本猜命令。
  final String? argumentsError;

  final Map<String, dynamic>? providerData;
}

/// 一次工具执行的结果（已落库）。
class ExecutedTool {
  const ExecutedTool({
    required this.callId,
    required this.content,
    required this.isError,
    this.record,
    this.messageId,
  });

  final String callId;
  final String content;
  final bool isError;

  /// 工具记录；参数错误等未执行的情况也可能有记录。
  final ToolCallRecord? record;

  /// 结果消息 id；为空表示结果未确认，整个任务需要暂停。
  final String? messageId;

  /// 结果未确认：已派发但没有可靠结果，等用户核验。
  bool get suspended =>
      record?.status == ToolCallStatus.unknown || messageId == null;
}

/// 循环结束原因。
enum AgentFinishReason {
  completed,
  cancelled,
  turnLimit,

  /// 动作结果未确认，运行挂起等待核验。
  unknownResult,
}

/// 单循环：模型调用 → 工具执行 → 结果回填 → 下一轮。
///
/// 聊天（无工具）与工具任务走同一条循环，每次运行有独立状态。
class AgentLoop {
  AgentLoop(this._host, {this.maxTurns = 30});

  final AgentLoopHost _host;
  final int maxTurns;

  Future<void> run() async {
    var turns = 0;
    while (!_host.isCancelled && turns < maxTurns) {
      turns++;
      final turn = await _host.streamTurn();
      if (_host.isCancelled || turn.cancelled) {
        return _host.finish(AgentFinishReason.cancelled);
      }
      if (turn.failed) {
        return _host.finish(turn.finishReason ?? AgentFinishReason.completed);
      }
      if (turn.toolCalls.isEmpty) {
        return _host.finish(AgentFinishReason.completed);
      }

      // 一轮多个调用按顺序串行执行，结果按原调用配对回填。
      for (final call in turn.toolCalls) {
        if (_host.isCancelled) {
          return _host.finish(AgentFinishReason.cancelled);
        }
        final executed = await _host.executeTool(call, turn);
        if (executed.suspended) {
          return _host.finish(AgentFinishReason.unknownResult);
        }
      }

      if (_host.isCancelled) {
        return _host.finish(AgentFinishReason.cancelled);
      }
      await _host.finishTurn(turn);
    }
    if (_host.isCancelled) {
      return _host.finish(AgentFinishReason.cancelled);
    }
    return _host.finish(AgentFinishReason.turnLimit);
  }
}
