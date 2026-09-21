import 'package:phase/data/models/agent_run.dart';
import 'package:phase/data/models/chat_message.dart';
import 'package:phase/data/models/message_part.dart';
import 'package:phase/data/models/model_selection.dart';
import 'package:phase/data/models/tool_call_record.dart';
import 'package:phase/data/models/tool_policy.dart';

import 'tool_loop_harness.dart';

/// 直接建立进程退出时的正式数据库状态；恢复过程必须只读事实，不执行动作。
Future<AgentRun> seedInterrupted(
  ToolLoopHarness h,
  List<ToolCallStatus> states, {
  DateTime? expiresAt,
  bool saveKnownResults = true,
  String toolName = 'echo',
  Map<String, dynamic> arguments = const {},
  ExecutionChannel channel = ExecutionChannel.app,
  int turnCount = 1,
  int maxTurns = AgentRun.defaultMaxTurns,
}) async {
  final conversations = await h.conversations();
  final conversation = await conversations.createConversation(title: '中断任务测试');
  final run = AgentRun(
    id: 'recover-run',
    conversationId: conversation.id,
    inputMessageId: 'input',
    currentMessageId: 'answer',
    createdAt: DateTime.now(),
    turnCount: turnCount,
    modelAttemptCount: turnCount,
    maxTurns: maxTurns,
    configuration: RunConfiguration(
      connection: RunConnection(
        profileId: h.profile.id,
        protocol: h.profile.protocol.name,
        baseUrl: h.profile.baseUrl,
        requiresKey: false,
      ),
      modelSelection: ModelSelection(
        profileId: h.profile.id,
        modelId: 'model-a',
        temperature: 0.4,
        maxOutputTokens: 300,
      ),
      systemPrompt: 'saved prompt',
      enabledTools: {toolName},
      toolPolicies: {toolName: ToolPolicy.ask},
    ),
  );
  await (await h.runs()).create(run);
  await conversations.appendMessage(
    ChatMessage(
      id: 'input',
      conversationId: conversation.id,
      role: ChatRole.user,
      parts: const [TextPart(text: 'do work')],
      createdAt: DateTime.now(),
    ),
  );
  await conversations.appendMessage(
    ChatMessage(
      id: 'answer',
      conversationId: conversation.id,
      parentId: 'input',
      runId: run.id,
      role: ChatRole.assistant,
      modelLabel: 'model-a',
      parts: [
        for (var i = 0; i < states.length; i++)
          ToolCallPart(toolCallId: 'record-$i'),
      ],
      createdAt: DateTime.now(),
    ),
  );
  var tail = 'answer';
  for (var i = 0; i < states.length; i++) {
    final status = states[i];
    final record = ToolCallRecord(
      id: 'record-$i',
      runId: run.id,
      assistantMessageId: 'answer',
      providerCallId: 'call-$i',
      toolName: toolName,
      arguments: arguments,
      channel: channel,
      defaultPolicy: ToolPolicy.ask,
      status: status,
      result: status == ToolCallStatus.succeeded ? 'already done' : null,
      confirmationRequestedAt: status == ToolCallStatus.awaitingConfirmation
          ? DateTime.now().subtract(const Duration(seconds: 10))
          : null,
      confirmationExpiresAt: status == ToolCallStatus.awaitingConfirmation
          ? expiresAt ?? DateTime.now().add(const Duration(seconds: 30))
          : null,
      createdAt: DateTime.now().add(Duration(milliseconds: i)),
    );
    await (await h.toolCalls()).create(record);
    if (saveKnownResults && status == ToolCallStatus.succeeded) {
      final message = ChatMessage(
        id: 'result-$i',
        conversationId: conversation.id,
        runId: run.id,
        parentId: tail,
        role: ChatRole.tool,
        parts: [
          ToolResultPart(toolCallId: record.id),
          const TextPart(text: 'already done'),
        ],
        createdAt: DateTime.now(),
      );
      await conversations.saveToolResult(
        toolCallId: record.id,
        message: message,
      );
      tail = message.id;
    }
  }
  return (await (await h.runs()).getById(run.id))!;
}
