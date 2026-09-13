import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/error/failure.dart';
import '../../../core/utils/logger.dart';
import '../../../data/models/execution_scope.dart';
import '../../../data/models/application_access_policy.dart';
import '../tools/tool.dart';
import 'execution_api.g.dart';
import 'application_policy_bridge.dart';

part 'channel_driver.g.dart';

sealed class NativeExecutionEvent {}

final class NativeStop extends NativeExecutionEvent {
  NativeStop(this.runId, {this.reason});
  final String runId;
  final String? reason;
}

final class NativeDecision extends NativeExecutionEvent {
  NativeDecision(this.runId, this.toolCallId, this.decision);
  final String runId;
  final String toolCallId;
  final ConfirmationDecision decision;
}

final class NativeCapabilities extends NativeExecutionEvent {
  NativeCapabilities(this.value);
  final ExecutionCapabilities value;
}

abstract interface class ChannelDriver {
  Stream<NativeExecutionEvent> get events;
  Map<String, Object?>? get latestSnapshot;
  Future<void> startRun(
    String runId, {
    ExecutionScope scope = const ExecutionScope(),
    bool deviceTask = true,
    ApplicationAccessPolicy? currentAppPolicy,
  });
  Future<void> endRun(String runId);
  Future<void> setConfirmation(ExecutionConfirmation? confirmation);
  Future<ExecutionCapabilities> queryCapabilities();
  Future<ExecutionResult> execute(
    ExecutionRequest request,
    RunCancellation cancellation, {
    void Function(ExecutionProgress)? onProgress,
  });
  Future<void> dispose();
}

/// 平台 Future 只交付一次终态；进度不能完成任务。桥接失联返回失败，停止返回取消，不声称动作已撤销。
class PigeonChannelDriver implements ChannelDriver, ExecutionFlutterApi {
  PigeonChannelDriver({
    ExecutionHostApi? host,
    BinaryMessenger? messenger,
    this.cancelGrace = const Duration(seconds: 2),
  }) : _host = host ?? ExecutionHostApi(binaryMessenger: messenger),
       _messenger = messenger {
    ExecutionFlutterApi.setUp(this, binaryMessenger: messenger);
  }

  final ExecutionHostApi _host;
  final BinaryMessenger? _messenger;
  final Duration cancelGrace;
  final _events = StreamController<NativeExecutionEvent>.broadcast(sync: true);
  final _pending = <String, _PendingExecution>{};
  final _seen = <String>{};
  String? _runId;
  Map<String, Object?>? _latestSnapshot;
  bool _disposed = false;

  @override
  Stream<NativeExecutionEvent> get events => _events.stream;
  @override
  Map<String, Object?>? get latestSnapshot => _latestSnapshot;

  Future<T> _boundary<T>(Future<T> Function() call) async {
    if (_disposed) {
      throw const ExecutionFailure(ExecutionFailureCode.unavailable);
    }
    try {
      return await call().timeout(const Duration(seconds: 10));
    } on TimeoutException {
      throw const ExecutionFailure(ExecutionFailureCode.timeout);
    } on PlatformException {
      throw const ExecutionFailure(ExecutionFailureCode.unavailable);
    } on MissingPluginException {
      throw const ExecutionFailure(ExecutionFailureCode.unavailable);
    }
  }

  @override
  Future<void> startRun(
    String runId, {
    ExecutionScope scope = const ExecutionScope(),
    bool deviceTask = true,
    ApplicationAccessPolicy? currentAppPolicy,
  }) async {
    if ((_runId != null && _runId != runId) || runId.isEmpty) {
      throw const ExecutionFailure(ExecutionFailureCode.invalidArguments);
    }
    if (_runId == null) _seen.clear();
    _runId = runId;
    try {
      final reply = await _boundary(
        () => _host.startRun(
          ExecutionSession(
            runId: runId,
            deviceTask: deviceTask,
            fileUris: scope.fileUris,
            appPolicy: scope.appPolicy.toBridge(),
            currentAppPolicy: (currentAppPolicy ?? scope.appPolicy).toBridge(),
          ),
        ),
      );
      if (reply.error case final error?) {
        throw ExecutionFailure(ExecutionFailureCode.values.byName(error.name));
      }
    } catch (_) {
      // 启动回执丢失时服务可能已启动；发送带原 runId 的清理，不能影响下一任务。
      await _bestEffort(() => _host.endRun(runId));
      _runId = null;
      rethrow;
    }
  }

  @override
  Future<void> endRun(String runId) async {
    if (_runId != runId) return;
    try {
      await _boundary(() => _host.endRun(runId));
    } finally {
      for (final pending in _pending.values.toList()) {
        pending.complete(
          _result(
            pending.id,
            ExecutionStatus.cancelled,
            ChannelError.cancelled,
          ),
        );
      }
      _runId = null;
      _seen.clear();
      _latestSnapshot = null;
    }
  }

  @override
  Future<ExecutionCapabilities> queryCapabilities() =>
      _boundary(_host.queryCapabilities);

  @override
  Future<void> setConfirmation(ExecutionConfirmation? confirmation) =>
      _boundary(() => _host.setConfirmation(confirmation));

  @override
  Future<ExecutionResult> execute(
    ExecutionRequest request,
    RunCancellation cancellation, {
    void Function(ExecutionProgress)? onProgress,
  }) async {
    if (cancellation.isCancelled) {
      return _result(
        request.toolCallId,
        ExecutionStatus.cancelled,
        ChannelError.cancelled,
      );
    }
    if (_disposed || request.runId != _runId) {
      return _result(
        request.toolCallId,
        ExecutionStatus.failed,
        ChannelError.unavailable,
      );
    }
    if (request.toolCallId.isEmpty ||
        request.timeoutMs < 1 ||
        request.timeoutMs > 300000 ||
        !_seen.add(request.toolCallId)) {
      return _result(
        request.toolCallId,
        ExecutionStatus.failed,
        ChannelError.invalidArguments,
      );
    }
    // JSON-compatible parameters only; snapshot before crossing an async boundary.
    final ExecutionRequest frozen;
    try {
      final encoded = jsonEncode(request.arguments);
      if (utf8.encode(encoded).length > 256 * 1024) {
        return _result(
          request.toolCallId,
          ExecutionStatus.failed,
          ChannelError.invalidArguments,
        );
      }
      frozen = ExecutionRequest(
        runId: request.runId,
        toolCallId: request.toolCallId,
        action: request.action,
        arguments: (jsonDecode(encoded) as Map).cast<String, Object?>(),
        target: ExecutionTarget(
          packageName: request.target.packageName,
          windowId: request.target.windowId,
          snapshotId: request.target.snapshotId,
          nodeId: request.target.nodeId,
          uri: request.target.uri,
        ),
        timeoutMs: request.timeoutMs,
      );
    } on Object {
      return _result(
        request.toolCallId,
        ExecutionStatus.failed,
        ChannelError.invalidArguments,
      );
    }
    final pending = _PendingExecution(frozen.toolCallId, onProgress);
    _pending[pending.id] = pending;
    final deadline = Timer(
      Duration(milliseconds: frozen.timeoutMs) + cancelGrace,
      () {
        unawaited(_bestEffort(() => _host.cancel(pending.id)));
        pending.complete(
          _result(pending.id, ExecutionStatus.failed, ChannelError.timeout),
        );
      },
    );
    unawaited(
      cancellation.whenCancelled.then((_) async {
        if (!_pending.containsKey(pending.id) || pending.done.isCompleted) {
          return;
        }
        pending.cancelling = true;
        pending.cancelTimer = Timer(
          cancelGrace,
          () => pending.complete(
            _result(
              pending.id,
              ExecutionStatus.cancelled,
              ChannelError.cancelled,
            ),
          ),
        );
        await _bestEffort(() => _host.cancel(pending.id));
      }),
    );
    unawaited(_execute(frozen, pending));
    try {
      return await pending.done.future;
    } finally {
      deadline.cancel();
      pending.cancelTimer?.cancel();
      _pending.remove(pending.id);
    }
  }

  Future<void> _execute(
    ExecutionRequest request,
    _PendingExecution pending,
  ) async {
    try {
      final result = await _host.execute(request);
      if (result.toolCallId == pending.id &&
          !pending.done.isCompleted &&
          !pending.cancelling &&
          result.result['snapshot'] is Map) {
        _latestSnapshot = Map<String, Object?>.from(
          result.result['snapshot'] as Map,
        );
      }
      pending.complete(
        result.toolCallId == pending.id ? result : _failed(pending.id),
      );
    } on Object {
      pending.complete(_failed(pending.id));
    }
  }

  @override
  void progress(ExecutionProgress progress) {
    final pending = _pending[progress.toolCallId];
    if (pending == null ||
        pending.done.isCompleted ||
        pending.cancelling ||
        progress.sequence <= pending.sequence ||
        utf8.encode(progress.payload).length > 4096) {
      return;
    }
    pending.sequence = progress.sequence;
    pending.onProgress?.call(progress);
  }

  @override
  void capabilityChanged(ExecutionCapabilities capabilities) {
    if (!_disposed) _events.add(NativeCapabilities(capabilities));
  }

  @override
  void confirmationDecision(
    String runId,
    String toolCallId,
    ConfirmationDecision decision,
  ) {
    if (!_disposed) _events.add(NativeDecision(runId, toolCallId, decision));
  }

  @override
  void stopRequested(String runId, [String? reason]) {
    if (!_disposed) _events.add(NativeStop(runId, reason: reason));
  }

  Future<void> _bestEffort(Future<void> Function() action) async {
    try {
      await action().timeout(cancelGrace);
    } on Object {
      AppLogger.warning('Android 执行通道未确认清理，将结束当前请求');
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    ExecutionFlutterApi.setUp(null, binaryMessenger: _messenger);
    for (final pending in _pending.values.toList()) {
      pending.complete(
        _result(pending.id, ExecutionStatus.cancelled, ChannelError.cancelled),
      );
    }
    final runId = _runId;
    if (runId != null) await _bestEffort(() => _host.endRun(runId));
    await _events.close();
  }

  static ExecutionResult _failed(String id) =>
      _result(id, ExecutionStatus.failed, ChannelError.executionFailed);
  static ExecutionResult _result(
    String id,
    ExecutionStatus status,
    ChannelError error,
  ) => ExecutionResult(
    toolCallId: id,
    status: status,
    result: {},
    artifacts: [],
    error: error,
  );
}

class _PendingExecution {
  _PendingExecution(this.id, this.onProgress);
  final String id;
  final void Function(ExecutionProgress)? onProgress;
  final done = Completer<ExecutionResult>();
  int sequence = -1;
  bool cancelling = false;
  Timer? cancelTimer;
  void complete(ExecutionResult result) {
    if (!done.isCompleted) done.complete(result);
  }
}

@Riverpod(keepAlive: true)
ChannelDriver channelDriver(Ref ref) {
  final driver = PigeonChannelDriver();
  ref.onDispose(() => unawaited(driver.dispose()));
  return driver;
}
