import 'package:flutter_test/flutter_test.dart';
import 'package:phase/features/tools/agent_loop.dart';

class _PlanHost implements AgentLoopHost {
  _PlanHost({this.succeeded = true});
  final bool succeeded;
  int requests = 0;
  bool savedTurn = false;
  AgentFinishReason? result;

  @override
  bool get isCancelled => false;
  @override
  Future<StreamedTurn> streamTurn() async {
    requests++;
    return const StreamedTurn(
      messageId: 'message',
      parts: [],
      toolCalls: [
        ToolCall(callId: 'plan', toolName: 'submit_plan', arguments: {}),
      ],
    );
  }

  @override
  Future<ExecutedTool> executeTool(ToolCall call, StreamedTurn turn) async =>
      ExecutedTool(
        callId: call.callId,
        content: '保存结果',
        isError: !succeeded,
        finishRun: succeeded,
      );
  @override
  Future<void> finishTurn(StreamedTurn turn) async {
    savedTurn = true;
  }

  @override
  Future<void> finish(AgentFinishReason reason) async {
    result = reason;
  }
}

void main() {
  test('最后一个预算轮成功提交计划后正常结束，不伪报轮数耗尽', () async {
    final host = _PlanHost();
    await AgentLoop(host, maxTurns: 1).run();
    expect(host.result, AgentFinishReason.completed);
    expect(host.requests, 1);
    expect(host.savedTurn, isTrue);
  });
  test('计划未保存成功时仍遵守显式轮次预算', () async {
    final host = _PlanHost(succeeded: false);
    await AgentLoop(host, maxTurns: 1).run();
    expect(host.result, AgentFinishReason.turnLimit);
    expect(host.requests, 1);
  });
}
