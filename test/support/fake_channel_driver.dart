import 'dart:async';

import 'package:phase/core/error/failure.dart';
import 'package:phase/data/models/execution_scope.dart';
import 'package:phase/data/models/application_access_policy.dart';
import 'package:phase/features/execution/channel_driver.dart';
import 'package:phase/features/execution/execution_api.g.dart';
import 'package:phase/features/tools/tool.dart';

class FakeChannelDriver implements ChannelDriver {
  @override
  Map<String, Object?>? latestSnapshot;
  final eventsController = StreamController<NativeExecutionEvent>.broadcast(
    sync: true,
  );
  final starts = <String>[];
  final ends = <String>[];
  final confirmations = <ExecutionConfirmation?>[];
  final scopes = <ExecutionScope>[];
  final deviceTasks = <bool>[];
  Future<ExecutionResult> Function(ExecutionRequest, RunCancellation)?
  executeHandler;
  Failure? startFailure;
  Failure? endFailure;
  Failure? confirmationFailure;

  @override
  Stream<NativeExecutionEvent> get events => eventsController.stream;
  @override
  Future<void> startRun(
    String runId, {
    ExecutionScope scope = const ExecutionScope(),
    bool deviceTask = true,
    ApplicationAccessPolicy? currentAppPolicy,
  }) async {
    starts.add(runId);
    scopes.add(scope);
    deviceTasks.add(deviceTask);
    if (startFailure case final failure?) throw failure;
  }

  @override
  Future<void> endRun(String runId) async {
    ends.add(runId);
    if (endFailure case final failure?) throw failure;
  }

  @override
  Future<void> setConfirmation(ExecutionConfirmation? confirmation) async {
    if (confirmationFailure case final failure?) throw failure;
    confirmations.add(confirmation);
  }

  @override
  Future<ExecutionCapabilities> queryCapabilities() async =>
      ExecutionCapabilities(
        actions: [],
        notificationsAllowed: true,
        activityResumed: true,
      );
  @override
  Future<ExecutionResult> execute(
    ExecutionRequest request,
    RunCancellation cancellation, {
    void Function(ExecutionProgress)? onProgress,
  }) async => executeHandler != null
      ? await executeHandler!(request, cancellation)
      : ExecutionResult(
          toolCallId: request.toolCallId,
          status: ExecutionStatus.failed,
          result: {},
          artifacts: [],
          error: ChannelError.unavailable,
        );
  @override
  Future<void> dispose() => eventsController.close();
}
