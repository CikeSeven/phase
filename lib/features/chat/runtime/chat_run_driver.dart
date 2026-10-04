import 'dart:async';

import '../../../core/error/failure.dart';
import '../../../core/utils/id.dart';
import '../../../core/utils/logger.dart';
import '../../../data/datasources/local/artifact_storage.dart';
import '../../../data/models/agent_run.dart';
import '../../../data/models/attachment.dart';
import '../../../data/models/chat_message.dart';
import '../../../data/models/message_part.dart';
import '../../../data/models/permission_mode.dart';
import '../../../data/models/tool_call_record.dart';
import '../../../data/repositories/agent_run_repository.dart';
import '../../../data/repositories/conversation_repository.dart';
import '../../../data/repositories/model_request_repository.dart';
import '../../../data/repositories/workspace_repository.dart';
import '../../execution/execution_controller.dart';
import '../../execution/execution_api.g.dart';
import '../../execution/task_activity.dart';
import '../../tools/agent_loop.dart';
import '../../tools/tool.dart';
import '../../tools/tool_executor.dart';
import '../../tools/tool_presentation.dart';
import '../../tools/tool_result_projection.dart';
import '../chat_model_selection.dart';
import '../chat_operation.dart';
import '../context/chat_context_coordinator.dart';
import '../context/context_configuration.dart';
import '../context/history_resolver.dart';
import 'chat_run_update.dart';
import 'chat_tool_runtime.dart';
import 'model_turn_runner.dart';

/// 一次驱动的唯一循环宿主；运行位置和终态只在这里推进。
class ChatRunDriver implements AgentLoopHost {
  ChatRunDriver({
    required this._run,
    required this._selection,
    required this._operation,
    required ConversationRepository conversations,
    required this._runs,
    required this._requests,
    required this._storage,
    required ChatToolRuntimeFactory tools,
    required ModelTurnRunnerFactory models,
    required this._contexts,
    required this._execution,
    required this._observe,
    required this._runStarted,
    required this._refreshRecovery,
    required this._sendFromPanel,
    this.darkTheme,
  }) : _repository = conversations,
       _toolFactory = tools,
       _modelFactory = models;

  AgentRun _run;
  final ChatModelSelection _selection;
  final ChatOperation _operation;
  final ConversationRepository _repository;
  final AgentRunRepository _runs;
  final ModelRequestRepository _requests;
  final ArtifactStorage _storage;
  final ChatToolRuntimeFactory _toolFactory;
  final ModelTurnRunnerFactory _modelFactory;
  final ChatContextCoordinator _contexts;
  final ExecutionController _execution;
  final ChatRunObserver _observe;
  final void Function(String) _runStarted;
  final Future<void> Function() _refreshRecovery;
  final Future<void> Function(String, String, String, RunCancellation)
  _sendFromPanel;
  final bool? darkTheme;
  ChatToolRuntime? _tools;
  ModelTurnRunner? _models;
  String? _turnTailId;
  RunFinishReason? _turnFailure;
  bool _submittedPlan = false;
  bool _closed = false;
  Map<String, Attachment> _attachments = const {};
  RunCancellation get _cancellation => _operation.beginCancellation();
  @override
  bool get isCancelled => _cancellation.isCancelled;

  void stop() {
    if (_closed) return;
    _operation.cancel();
    _models?.stop();
  }

  void _checkPanelCancellation(RunCancellation? cancellation) {
    if (cancellation?.isCancelled == true) {
      throw const CancelledFailure('悬浮面板发送已取消');
    }
  }

  Future<void> run({
    bool resuming = false,
    RunCancellation? panelCancellation,
    void Function()? onPanelAccepted,
  }) async {
    final run = _run;
    _operation.bindRun(run.id);
    _operation.beginCancellation();
    WorkspaceLease? resumedWorkspace;
    try {
      _tools = await _toolFactory.create(
        run: run,
        execution: _execution,
        cancellation: _cancellation,
        confirm: _confirmToolCall,
        waitForUser: _waitForUser,
      );
      _models = _modelFactory.create(
        run: run,
        selection: _selection,
        tools: _tools!,
        cancellation: _cancellation,
        observe: _observe,
        execution: _execution,
      );
      _runStarted(run.id);
      _tools!.listenStops(stop);
      final binding = run.configuration.workspace;
      if (resuming && binding != null) {
        resumedWorkspace = await _tools!.workspaces!.acquire(
          binding.id,
          expected: binding,
        );
      }
      _execution.beginRun(
        run.id,
        stop: stop,
        scope: run.configuration.executionScope,
        darkTheme: darkTheme,
        onPanelMessage: (text, cancellation) =>
            _sendFromPanel(run.id, run.conversationId, text, cancellation),
      );
      await _execution.ensureBackgroundHost(run.id);
      _attachments = await _contexts.attachments(run.conversationId);
      _observe(ChatRunStarted(run.id, run.conversationId, _attachments));
      if (onPanelAccepted != null) {
        if (panelCancellation?.isCancelled == true) _execution.stopRun(run.id);
        _checkPanelCancellation(panelCancellation);
        unawaited(
          panelCancellation!.whenCancelled.then((_) {
            if (!_closed && !_operation.runFinished) _execution.stopRun(run.id);
          }),
        );
        await _execution.ensureDeviceHost(run.id);
        _checkPanelCancellation(panelCancellation);
        onPanelAccepted();
      }
      if (resuming && !await _restorePendingTools()) return;
      if (_submittedPlan) {
        await finish(
          isCancelled
              ? AgentFinishReason.cancelled
              : AgentFinishReason.completed,
        );
        return;
      }
      if (!isCancelled) {
        final thread = await _repository.getThread(run.conversationId);
        if (thread == null) throw const OperationFailure('会话已不存在');
        final changed = RuntimeContextPart.changes(
          thread.branch
              .where((message) => message.role == ChatRole.system)
              .expand((message) => message.parts),
          contextRuntimeParts(run.configuration),
        );
        if (changed.isNotEmpty && !isCancelled) {
          final message = ChatMessage(
            id: generateId(),
            conversationId: run.conversationId,
            parentId: thread.currentMessageId,
            runId: run.id,
            role: ChatRole.system,
            parts: changed,
            createdAt: DateTime.now(),
          );
          await _repository.appendMessage(message);
          _turnTailId = message.id;
        }
      }
      await AgentLoop(
        this,
        maxTurns: run.maxTurns == 0 ? null : run.maxTurns - run.turnCount,
      ).run();
    } on StorageFailure {
      await _operation.cleanup(
        () => _requests.interruptPending(
          runId: run.id,
          errorCode: 'storageError',
        ),
        failureMessage: '存储故障后的请求终态未能保存',
      );
      await _operation.cleanup(
        () => _finishRun(RunStatus.failed, RunFinishReason.storageError),
        failureMessage: '运行终态未能保存，启动时需核对',
      );
      rethrow;
    } on Failure {
      await _finishUnexpectedRun();
      rethrow;
    } catch (error, stackTrace) {
      AppLogger.error('运行异常：${error.runtimeType}', null, stackTrace);
      await _finishUnexpectedRun();
      throw UnknownFailure('运行执行失败', cause: error);
    } finally {
      _closed = true;
      _operation.cancel();
      await _operation.cleanup(
        () async => _models?.close(_operation),
        failureMessage: '模型运行资源未能完整关闭',
      );
      await _operation.cleanup(
        () async => _tools?.close(_operation),
        failureMessage: '工具运行资源未能完整关闭',
      );
      await _operation.cleanup(
        () => resumedWorkspace?.close(),
        failureMessage: '恢复运行的工作区租约未能释放',
      );
      await _operation.cleanup(
        () => _execution.endRun(run.id),
        failureMessage: 'Android 任务服务未确认结束',
      );
      await _operation.cleanup(
        () => _requests.interruptPending(runId: run.id),
        failureMessage: '请求终态未能保存，启动时需核对',
      );
      await _operation.cleanup(_refreshRecovery, failureMessage: '中断任务索引未能刷新');
      _models = null;
      _tools = null;
      _attachments = const {};
    }
  }

  Future<void> _finishUnexpectedRun() async {
    try {
      await _finishRun(
        isCancelled ? RunStatus.stopped : RunStatus.failed,
        isCancelled
            ? RunFinishReason.cancelled
            : RunFinishReason.executionError,
      );
    } on Object {
      AppLogger.error('运行终态未能保存，启动时需核对');
    }
  }

  @override
  Future<StreamedTurn> streamTurn() async {
    final thread = await _repository.getThread(_run.conversationId);
    if (thread == null) throw const UnknownFailure('会话不存在或已删除');
    _run = await _runs.beginTurn(_run.id);
    final messages = await _contexts.resolve(
      messages: thread.branch,
      attachments: _attachments,
      selection: _selection,
      registry: _tools!.registry,
    );
    try {
      final result = await _models!.runTurn(
        logicalTurn: _run.turnCount,
        messages: messages,
        parentId: thread.currentMessageId,
        attachments: _attachments,
      );
      _turnFailure = result.failure;
      return result.turn;
    } finally {
      // 请求或写入异常也保留已创建的响应位置，不回退到上一轮工具结果。
      _turnTailId = _models!.tailId ?? _turnTailId;
    }
  }

  Future<Map<String, ToolCallRecord>> _recordsFor(List<ChatMessage> messages) =>
      historyRecords(_repository, messages);

  Future<void> _refreshRunningContext() => _contexts.refreshForRun(
    run: _run,
    selection: _selection,
    registry: _tools!.registry,
    tools: _tools!.definitions,
    attachments: _attachments,
    cancellation: _cancellation,
    observe: _observe,
  );
  Future<bool> _restorePendingTools() async {
    final run = _run;
    final thread = await _repository.getThread(run.conversationId);
    if (thread == null) throw const OperationFailure('会话已不存在');
    _run = await _runs.resume(run.id);
    _turnTailId = thread.currentMessageId;
    final records = await _recordsFor(thread.branch);
    _submittedPlan =
        run.configuration.mode == PermissionMode.plan &&
        records.values.any(
          (record) =>
              record.runId == run.id &&
              record.toolName == 'submit_plan' &&
              record.status == ToolCallStatus.succeeded,
        );
    for (final message in thread.branch.where(
      (m) => m.runId == run.id && m.role == ChatRole.assistant,
    )) {
      final turn = StreamedTurn(
        messageId: message.id,
        parts: message.parts,
        toolCalls: const [],
      );
      for (final part in message.parts.whereType<ToolCallPart>()) {
        final record = records[part.toolCallId];
        if (record == null) throw const OperationFailure('中断任务的工具记录不完整');
        if (record.resultMessageId != null) continue;
        final providerCallId = record.providerCallId;
        if (providerCallId == null) {
          throw const OperationFailure('中断调用缺少协议标识，无法继续');
        }
        if (isCancelled) {
          await finish(AgentFinishReason.cancelled);
          return false;
        }
        await executeTool(
          ToolCall(
            callId: providerCallId,
            toolName: record.toolName,
            arguments: record.arguments,
            providerData: record.providerData,
            recordId: record.id,
          ),
          turn,
        );
      }
    }
    return true;
  }

  /// 执行一次工具调用：记录 → 结果消息 → 结果进入下一轮上下文。
  @override
  Future<ExecutedTool> executeTool(ToolCall call, StreamedTurn turn) async {
    final run = _run;
    final cancellation = _cancellation;
    final repository = _repository;

    if (call.recordId == null) throw const OperationFailure('调用尚未持久化，不能执行');
    final channel = _tools!.channelFor(call.toolName, call.arguments);
    final executed = await _tools!.executor.execute(
      ToolExecutionRequest(
        runId: run.id,
        assistantMessageId: turn.messageId,
        toolName: call.toolName,
        arguments: call.arguments,
        channel: channel,
        conversationId: run.conversationId,
        attachments: await _storage.attachments(run.conversationId),
        workspaceDirectory: run.configuration.workspace?.rootPath ?? '',
        fileAccess: run.configuration.workspace == null
            ? null
            : _tools!.workspaces!.files(run.configuration.workspace!),
        storage: _storage,
        enabledTools: run.configuration.enabledTools,
        toolPolicies: run.configuration.toolPolicies,
        providerCallId: call.callId,
        providerData: call.providerData,
        recordId: call.recordId,
      ),
      cancellation,
      onProgress: (message) {
        if (cancellation.isCancelled) return;
        _execution.updateActivity(
          run.id,
          _execution
              .activityFor(run.id)
              .upsert(
                TaskMessage(
                  id: 'tool/${call.recordId}',
                  kind: TaskPanelMessageKind.tool,
                  label: '正在${ToolPresentation.toolLabel(call.toolName)}',
                  text:
                      '${toolActivity(_tools!.registry.byName(call.toolName)!, call.arguments)}\n${panelExcerpt(message, limit: 160)}',
                ),
              ),
        );
      },
    );
    final record = executed.record;
    if (run.configuration.mode == PermissionMode.plan &&
        record.toolName == 'submit_plan' &&
        record.status == ToolCallStatus.succeeded) {
      _submittedPlan = true;
    }
    final label = ToolPresentation.recordLabel(record);
    final status = switch (record.status) {
      ToolCallStatus.succeeded =>
        '执行了${(record.toolName == 'shell') ? '命令' : label}',
      ToolCallStatus.rejected => '已拒绝$label',
      ToolCallStatus.cancelled => '已取消$label',
      _ => '$label失败',
    };
    final previousActivity = _execution.activityFor(run.id);
    _execution.updateActivity(
      run.id,
      previousActivity
          .copyWith(
            phase: TaskPanelPhase.waitingModel,
            status: status,
            lastToolStatus: status,
          )
          .upsert(
            TaskMessage(
              id: 'tool/${record.id}',
              kind: TaskPanelMessageKind.tool,
              label: status,
              text:
                  previousActivity.messages
                      .where((entry) => entry.id == 'tool/${record.id}')
                      .firstOrNull
                      ?.text ??
                  (record.target ?? label),
            ),
          ),
    );
    if (record.status == ToolCallStatus.succeeded ||
        record.artifacts.isNotEmpty) {
      await _registerArtifacts(
        run.conversationId,
        toolReported: record.artifacts.isNotEmpty,
      );
    }

    final content = toolResultText(record);
    // 结果消息接在本轮末尾之后：多个结果按执行顺序串成同一条分支。
    final message = ChatMessage(
      id: generateId(),
      conversationId: run.conversationId,
      parentId: _turnTailId ?? turn.messageId,
      runId: run.id,
      role: ChatRole.tool,
      status: MessageStatus.completed,
      parts: [
        ToolResultPart(toolCallId: record.id),
        TextPart(text: content),
      ],
      createdAt: DateTime.now(),
    );
    // 结果记录与结果消息在同一事务提交（design 第五部分 §3.3）。
    final saved = await repository.saveToolResult(
      toolCallId: record.id,
      message: message,
    );
    _turnTailId = message.id;
    await _refreshRunningContext();
    return ExecutedTool(
      callId: call.callId,
      content: content,
      isError: saved.status != ToolCallStatus.succeeded,
      record: saved,
      messageId: message.id,
      finishRun: _submittedPlan,
    );
  }

  /// 本轮工具结果已回填：记录分支位置并清空待处理调用。
  @override
  Future<void> finishTurn(StreamedTurn turn) async {
    final run = _run;
    _run = await _runs.finishTurn(
      run.id,
      currentMessageId: _turnTailId ?? turn.messageId,
    );
  }

  /// 运行终态：按原因写状态与结束原因（design 第二部分 §4）。
  @override
  Future<void> finish(AgentFinishReason reason) async {
    final run = _run;
    if (_operation.runFinished) return;
    if (reason == AgentFinishReason.turnLimit) {
      // 工具结果不展示为正文；仅保存运行失败会看起来像模型正常完成。
      final message = ChatMessage(
        id: generateId(),
        conversationId: run.conversationId,
        parentId: _turnTailId ?? run.currentMessageId ?? run.inputMessageId,
        runId: run.id,
        role: ChatRole.assistant,
        status: MessageStatus.failed,
        parts: [
          TextPart(
            text:
                '应用已达到本次运行的 ${run.maxTurns} 轮上限，任务已停止，并不代表工作已完成。'
                '已执行的工具结果已保留，可发送“继续”接着处理。',
          ),
        ],
        modelLabel: _selection.model,
        createdAt: DateTime.now(),
      );
      await _repository.appendMessage(message);
      _turnTailId = message.id;
    }
    final (RunStatus, RunFinishReason?) result = switch (reason) {
      // 本轮以错误或空回复收场时，运行按具体原因失败。
      AgentFinishReason.completed =>
        _turnFailure == null
            ? (RunStatus.completed, RunFinishReason.completed)
            : (RunStatus.failed, _turnFailure),
      AgentFinishReason.cancelled => (
        RunStatus.stopped,
        RunFinishReason.cancelled,
      ),
      AgentFinishReason.turnLimit => (
        RunStatus.failed,
        RunFinishReason.turnLimit,
      ),
    };
    return _finishRun(result.$1, result.$2);
  }

  /// 运行终态只写一次：循环收口与异常收尾共用。
  Future<void> _finishRun(
    RunStatus status,
    RunFinishReason? finishReason,
  ) async {
    final run = _run;
    if (_operation.runFinished) return;
    _run = await _runs.finish(
      run.id,
      status: status,
      finishReason: finishReason,
      currentMessageId: _turnTailId,
    );
    _operation.markRunFinished();
  }

  /// 请求用户确认：等待期间运行记 awaitingConfirmation 与待确认调用。
  ///
  /// 应用级控制器持有待确认请求；页面销毁/移交不改变决定或原期限。
  /// 到期按拒绝，停止由执行器按取消收口。
  Future<ToolDecision> _confirmToolCall(ToolConfirmationRequest request) async {
    final run = _run;
    _run = await _runs.awaitConfirmation(run.id, request.record.id);
    final cancellation = _cancellation;
    return _execution.confirm(request, cancellation);
  }

  Future<void> _waitForUser(
    ToolContext context,
    String prompt,
    RunCancellation cancellation,
  ) async {
    _run = await _runs.awaitUser(context.runId, context.toolCallId);
    await _execution.waitForUser(
      UserActionRequest(
        runId: context.runId,
        toolCallId: context.toolCallId,
        prompt: prompt,
      ),
      cancellation,
    );
    cancellation.throwIfCancelled();
    _run = await _runs.resume(context.runId);
  }

  /// 产物登记与附件索引刷新：写文件产生的产物要出现在会话附件里。
  ///
  /// [toolReported] 表示工具自己已登记并引用了产物（不会出现在待登记扫描里），
  /// 索引同样要刷新，否则卡片与气泡查不到这份文件。
  Future<void> _registerArtifacts(
    String conversationId, {
    bool toolReported = false,
  }) async {
    final storage = _storage;
    try {
      final registered = await storage.registerPendingArtifacts(conversationId);
      if (registered.isEmpty && !toolReported) return;
      _attachments = await _contexts.attachments(conversationId);
      _observe(ChatAttachmentsChanged(_run.id, conversationId, _attachments));
    } on Failure {
      rethrow;
    } on Exception {
      throw const OperationFailure('产物登记失败，请处理后再继续任务');
    }
  }
}
