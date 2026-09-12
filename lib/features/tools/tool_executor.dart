import 'dart:async';

import '../../../core/utils/id.dart';
import '../../../core/utils/logger.dart';
import '../../../data/models/attachment.dart';
import '../../../data/models/tool_call_record.dart';
import '../../../data/models/tool_policy.dart';
import '../../../data/repositories/agent_run_repository.dart';
import '../../../data/repositories/tool_call_repository.dart';
import 'tool.dart';

/// 一次工具调用的执行请求。
class ToolExecutionRequest {
  const ToolExecutionRequest({
    required this.runId,
    required this.assistantMessageId,
    required this.toolName,
    required this.arguments,
    required this.channel,
    required this.conversationId,
    required this.attachments,
    required this.storage,
    this.workspaceDirectory = '',
    required this.enabledTools,
    required this.toolPolicies,
    this.providerCallId,
    this.providerData,
    this.target,
  });

  final String runId;
  final String assistantMessageId;
  final String toolName;
  final Map<String, dynamic> arguments;
  final ExecutionChannel channel;
  final String conversationId;
  final List<Attachment> attachments;
  final ToolStorage storage;
  final String workspaceDirectory;

  /// 本次运行开放的工具范围与工具级策略（来自助手与该次运行配置）。
  final Set<String> enabledTools;
  final Map<String, ToolPolicy> toolPolicies;

  /// 模型协议自己的调用 id，用于结果回填。
  final String? providerCallId;

  /// 需要随结果回传给模型的协议状态。
  final Map<String, dynamic>? providerData;
  final String? target;
}

/// 等待用户确认的请求：界面据此展示确认面板。
class ToolConfirmationRequest {
  const ToolConfirmationRequest({
    required this.record,
    required this.summary,
    required this.policy,
    required this.expiresAt,
  });

  final ToolCallRecord record;

  /// 一句话动作摘要（工具自己给出）。
  final String summary;

  /// 本次调用的策略（ask 才会走到确认）。
  final ToolPolicy policy;

  /// 期限；到点未决定按拒绝处理。
  final DateTime expiresAt;
}

/// 执行结束后的结果：记录与工具返回内容。
class ToolExecutionResult {
  const ToolExecutionResult({required this.record, required this.outcome});

  final ToolCallRecord record;
  final ToolOutcome? outcome;

  bool get rejected => record.status == ToolCallStatus.rejected;

  /// 等待确认期间被用户停止。
  bool get cancelled => record.status == ToolCallStatus.cancelled;

  bool get unknown => record.status == ToolCallStatus.unknown;
}

/// 工具执行器：参数校验、策略决定、确认、执行与状态记录。
///
/// 只在这里决定「是否执行」与记录「执行结果」，Loop 只等待结果。
class ToolExecutor {
  ToolExecutor({
    required this.registry,
    required this.toolCalls,
    this.runs,
    this.onConfirmationRequired,
    this.onRecordCreated,
    this.confirmationTimeout = ToolCallRepository.confirmationTimeout,
  });

  final ToolRegistry registry;
  final ToolCallRepository toolCalls;

  /// 运行仓储：确认有结果后把运行从等待确认恢复为运行中，与执行进度一致。
  final AgentRunRepository? runs;

  /// 界面注册的确认入口；没有界面时按超时拒绝处理。
  Future<ToolDecision> Function(ToolConfirmationRequest request)?
  onConfirmationRequired;

  /// 记录创建后立即回调（此时尚未确认与执行）。
  ///
  /// 调用方据此把 ToolCallPart 写进助手消息，让"等待确认 / 执行中"
  /// 的工具卡片在动作发生前就出现在会话里。
  Future<void> Function(ToolCallRecord record)? onRecordCreated;

  final Duration confirmationTimeout;

  /// 执行一次工具调用；返回最终记录状态与工具输出。
  Future<ToolExecutionResult> execute(
    ToolExecutionRequest request,
    RunCancellation cancellation, {
    ToolProgress? onProgress,
  }) async {
    final tool = registry.byName(request.toolName);
    if (tool == null) {
      // 未注册的工具名不会被"就近执行"。
      return _rejected(
        request,
        reason: '工具「${request.toolName}」不存在或未开放',
        errorCode: 'unknownTool',
        policy: ToolPolicy.deny,
      );
    }

    final policy = registry.policyFor(
      tool,
      request.enabledTools,
      request.toolPolicies,
    );
    if (policy == ToolPolicy.deny) {
      return _rejected(
        request,
        reason: '工具「${tool.name}」未被允许使用',
        errorCode: 'policyDenied',
        policy: policy,
      );
    }

    // 参数校验在派发前完成：缺参数属于模型响应问题，不进确认与执行。
    final validation = _validate(tool, request.arguments);
    if (validation != null) {
      final record = await _create(
        request,
        tool,
        status: ToolCallStatus.failed,
      );
      await toolCalls.markFailed(
        record.id,
        result: validation,
        errorCode: 'invalidArguments',
      );
      return ToolExecutionResult(
        record: await toolCalls.getById(record.id),
        outcome: ToolOutcome.failure(validation, errorCode: 'invalidArguments'),
      );
    }

    final record = await _create(
      request,
      tool,
      status: ToolCallStatus.prepared,
    );
    // 记录已就绪：调用方现在就能把工具卡片放进会话（此时还没确认/执行）。
    await onRecordCreated?.call(record);

    if (policy == ToolPolicy.ask) {
      final decision = await _confirm(record, tool, cancellation);
      if (decision == null) {
        // 等待确认期间用户停止：结束等待，本次确认不再生效。
        return ToolExecutionResult(
          record: await toolCalls.markCancelled(record.id),
          outcome: null,
        );
      }
      // 决定已落库：批准与拒绝都让运行回到运行中（拒绝在返回结果前），
      // 界面上的运行状态与循环的实际进度保持一致。
      await runs?.resume(request.runId);
      if (decision != ToolDecision.approved) {
        return ToolExecutionResult(
          record: await toolCalls.getById(record.id),
          outcome: ToolOutcome.failure('用户拒绝了本次动作', errorCode: 'userRejected'),
        );
      }
    }

    if (cancellation.isCancelled) {
      return ToolExecutionResult(
        record: await toolCalls.markCancelled(record.id),
        outcome: null,
      );
    }

    // 先记录 executing 再派发：外部动作可能已经开始。
    await toolCalls.markExecuting(record.id);

    final context = ToolContext(
      conversationId: request.conversationId,
      runId: request.runId,
      toolCallId: record.id,
      storage: request.storage,
      attachments: request.attachments,
      workspaceDirectory: request.workspaceDirectory,
    );

    ToolOutcome outcome;
    try {
      outcome = await tool.execute(
        request.arguments,
        context,
        cancellation,
        onProgress: onProgress,
      );
    } on ToolArgumentException catch (error) {
      outcome = ToolOutcome.failure(
        error.message,
        errorCode: 'invalidArguments',
      );
    } on Exception catch (error, stackTrace) {
      AppLogger.error('工具执行异常：${tool.name}', error, stackTrace);
      outcome = ToolOutcome.failure(
        '工具执行失败（${error.runtimeType}）',
        errorCode: 'toolFailed',
      );
    }

    final updated = switch (outcome) {
      ToolOutcome(unknown: true) => await toolCalls.markUnknown(
        record.id,
        errorCode: outcome.errorCode,
      ),
      ToolOutcome(ok: true) => await toolCalls.markSucceeded(
        record.id,
        result: outcome.content,
        artifacts: outcome.artifacts,
      ),
      _ => await toolCalls.markFailed(
        record.id,
        result: outcome.content,
        errorCode: outcome.errorCode,
      ),
    };
    return ToolExecutionResult(record: updated, outcome: outcome);
  }

  /// 请求确认并等待决定；无界面或到点按拒绝，停止按取消。
  ///
  /// 返回 null 表示等待期间被停止。
  Future<ToolDecision?> _confirm(
    ToolCallRecord record,
    Tool tool,
    RunCancellation cancellation,
  ) async {
    final awaiting = await toolCalls.requestConfirmation(record.id);
    final expiresAt =
        awaiting.confirmationExpiresAt ??
        DateTime.now().add(confirmationTimeout);

    final callback = onConfirmationRequired;
    if (callback == null) {
      // 没有界面可确认：不把动作当成已批准，等满期限后按拒绝处理。
      await Future.any([
        Future<void>.delayed(confirmationTimeout),
        cancellation.whenCancelled,
      ]);
      if (cancellation.isCancelled) return null;
      await toolCalls.recordDecision(record.id, ToolDecision.expired);
      return ToolDecision.expired;
    }

    final decision = await callback(
      ToolConfirmationRequest(
        record: awaiting,
        summary: tool.describeAction(record.arguments),
        policy: ToolPolicy.ask,
        expiresAt: expiresAt,
      ),
    );
    if (cancellation.isCancelled) return null;
    await toolCalls.recordDecision(record.id, decision);
    return decision;
  }

  /// 参数校验：必填与声明类型由工具的 schema 决定。
  String? _validate(Tool tool, Map<String, dynamic> arguments) {
    final schema = tool.inputSchema;
    final required = schema['required'];
    if (required is List) {
      for (final key in required) {
        if (key is! String) continue;
        final value = arguments[key];
        if (value == null || (value is String && value.trim().isEmpty)) {
          return '缺少必填参数「$key」';
        }
      }
    }
    final properties = schema['properties'];
    if (properties is Map) {
      for (final entry in arguments.entries) {
        final property = properties[entry.key];
        if (property is! Map) {
          return '参数「${entry.key}」不在工具定义里';
        }
        final expected = property['type'];
        if (expected is! String) continue;
        final value = entry.value;
        final matches = switch (expected) {
          'string' => value is String,
          'integer' => value is int || value is num,
          'number' => value is num || value is String,
          'boolean' => value is bool || value is String,
          'object' => value is Map,
          'array' => value is List,
          _ => true,
        };
        if (!matches) {
          return '参数「${entry.key}」类型应为 $expected';
        }
      }
    }
    return null;
  }

  Future<ToolCallRecord> _create(
    ToolExecutionRequest request,
    Tool tool, {
    required ToolCallStatus status,
  }) {
    return toolCalls.create(
      ToolCallRecord(
        id: generateId(),
        runId: request.runId,
        assistantMessageId: request.assistantMessageId,
        providerCallId: request.providerCallId,
        toolName: tool.name,
        arguments: request.arguments,
        providerData: request.providerData,
        target: request.target ?? tool.describeAction(request.arguments),
        channel: request.channel,
        defaultPolicy: tool.defaultPolicy,
        status: status,
        createdAt: DateTime.now(),
      ),
    );
  }

  /// 未执行的调用也留下记录：拒绝与未开放都能在记录里查到。
  Future<ToolExecutionResult> _rejected(
    ToolExecutionRequest request, {
    required String reason,
    required String errorCode,
    required ToolPolicy policy,
  }) async {
    final record = await toolCalls.create(
      ToolCallRecord(
        id: generateId(),
        runId: request.runId,
        assistantMessageId: request.assistantMessageId,
        providerCallId: request.providerCallId,
        toolName: request.toolName,
        arguments: request.arguments,
        target: request.target,
        channel: request.channel,
        defaultPolicy: policy,
        status: ToolCallStatus.rejected,
        result: reason,
        errorCode: errorCode,
        createdAt: DateTime.now(),
        finishedAt: DateTime.now(),
      ),
    );
    return ToolExecutionResult(
      record: record,
      outcome: ToolOutcome.failure(reason, errorCode: errorCode),
    );
  }
}
