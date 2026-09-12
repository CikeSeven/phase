import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/error/failure.dart';
import '../../../core/utils/logger.dart';
import '../../../data/models/tool_call_record.dart';
import '../tools/tool.dart';
import '../tools/tool_executor.dart';
import 'channel_driver.dart';
import 'execution_api.g.dart';

part 'execution_controller.g.dart';

class ExecutionState {
  const ExecutionState({
    this.runId,
    this.confirmation,
    this.foreground = true,
    this.failure,
  });
  final String? runId;
  final ToolConfirmationRequest? confirmation;
  final bool foreground;
  final Failure? failure;
}

/// 根任务的用户控制，与页面/Activity 的挂接无关。决定由 ToolExecutor 落库。
@Riverpod(keepAlive: true)
class ExecutionController extends _$ExecutionController {
  Completer<ToolDecision>? _decision;
  void Function()? _stop;
  Timer? _expiry;
  bool _deviceTask = false;
  bool _stopped = false;
  Future<void> _nativeUpdates = Future.value();
  StreamSubscription<NativeExecutionEvent>? _nativeSubscription;

  @override
  ExecutionState build() {
    ref.onDispose(() {
      _expiry?.cancel();
      _stop?.call();
      _complete(ToolDecision.expired);
      unawaited(_nativeSubscription?.cancel());
    });
    return const ExecutionState();
  }

  void beginRun(String runId, {required void Function() stop}) {
    if (state.runId != null) throw const OperationFailure('已有运行中的任务');
    _stop = stop;
    _stopped = false;
    _deviceTask = false;
    state = ExecutionState(runId: runId, foreground: state.foreground);
  }

  /// 直到实际进入设备工具才启动服务；仅开放了工具的普通聊天不启动服务。
  Future<void> ensureDeviceHost(String runId) async {
    if (state.runId != runId || _stopped) {
      throw const ExecutionFailure(ExecutionFailureCode.cancelled);
    }
    if (_deviceTask) return;
    _deviceTask = true;
    try {
      final driver = ref.read(channelDriverProvider);
      _nativeSubscription ??= driver.events.listen(_onNativeEvent);
      await driver.startRun(runId);
    } on Failure catch (failure) {
      _deviceTask = false;
      stopRun(runId);
      if (ref.mounted) {
        state = ExecutionState(
          runId: runId,
          foreground: state.foreground,
          failure: failure,
        );
      }
      rethrow;
    }
  }

  Future<void> endRun(String runId) async {
    if (state.runId != runId) return;
    _complete(ToolDecision.expired);
    _stop = null;
    if (_deviceTask) {
      try {
        await _nativeUpdates;
        await ref.read(channelDriverProvider).endRun(runId);
      } on Failure catch (failure) {
        if (ref.mounted) {
          state = ExecutionState(
            foreground: state.foreground,
            failure: failure,
          );
        }
        rethrow;
      } finally {
        _deviceTask = false;
      }
    }
    if (ref.mounted) {
      state = ExecutionState(
        foreground: state.foreground,
        failure: state.failure,
      );
    }
  }

  Future<ToolDecision> confirm(
    ToolConfirmationRequest request,
    RunCancellation cancellation,
  ) async {
    if (_stopped ||
        cancellation.isCancelled ||
        request.record.runId != state.runId) {
      return ToolDecision.expired;
    }
    if (_decision != null) throw const OperationFailure('已有待确认动作');
    final remaining = request.expiresAt.difference(DateTime.now());
    if (remaining <= Duration.zero) return ToolDecision.expired;
    final decision = Completer<ToolDecision>();
    _decision = decision;
    _expiry = Timer(remaining, () => _complete(ToolDecision.expired));
    state = ExecutionState(
      runId: state.runId,
      confirmation: request,
      foreground: state.foreground,
    );
    _syncNative();
    try {
      return await Future.any([
        decision.future,
        cancellation.whenCancelled.then((_) => ToolDecision.expired),
      ]);
    } finally {
      _expiry?.cancel();
      if (identical(_decision, decision)) _decision = null;
      if (ref.mounted) {
        state = ExecutionState(
          runId: state.runId,
          foreground: state.foreground,
          failure: state.failure,
        );
        _syncNative();
      }
    }
  }

  /// 两端都只提交固定调用的决定；旧面板、重复提交与过期批准不会影响新调用。
  bool decide(String runId, String toolCallId, ToolDecision decision) {
    final request = state.confirmation;
    if (_stopped ||
        request == null ||
        request.record.runId != runId ||
        request.record.id != toolCallId ||
        _decision == null ||
        _decision!.isCompleted) {
      return false;
    }
    if (!request.expiresAt.isAfter(DateTime.now())) {
      _complete(ToolDecision.expired);
      return false;
    }
    _complete(decision);
    return true;
  }

  void stopRun(String runId) {
    if (state.runId != runId || _stopped) return;
    _stopped = true;
    _stop?.call();
    _complete(ToolDecision.expired);
  }

  void setForeground(bool foreground) {
    if (state.foreground == foreground) return;
    state = ExecutionState(
      runId: state.runId,
      confirmation: state.confirmation,
      foreground: foreground,
      failure: state.failure,
    );
    _syncNative();
  }

  void _complete(ToolDecision value) {
    if (_decision != null && !_decision!.isCompleted) {
      _decision!.complete(value);
    }
  }

  void _onNativeEvent(NativeExecutionEvent event) {
    switch (event) {
      case NativeStop(:final runId):
        stopRun(runId);
      case NativeDecision(:final runId, :final toolCallId, :final decision):
        // 原生面板只在相月不在前台时拥有输入权；交接后的迟到决定丢弃。
        if (state.foreground) return;
        if (decision == ConfirmationDecision.stop) {
          final pending = state.confirmation;
          if (pending?.record.id == toolCallId &&
              pending?.record.runId == runId) {
            stopRun(runId);
          }
        } else {
          decide(
            runId,
            toolCallId,
            decision == ConfirmationDecision.approve
                ? ToolDecision.approved
                : ToolDecision.rejected,
          );
        }
      case NativeCapabilities():
        // 能力变更不授予工具权限，也不自动继续已停止的任务。
        break;
    }
  }

  void _syncNative() {
    if (!_deviceTask) return;
    final request = state.foreground ? null : state.confirmation;
    final confirmation = request == null
        ? null
        : ExecutionConfirmation(
            runId: request.record.runId,
            toolCallId: request.record.id,
            toolName: request.record.toolName,
            summary: request.summary,
            arguments: request.record.arguments,
            targetLabel: request.record.target,
            expiresAtMs: request.expiresAt.millisecondsSinceEpoch,
          );
    final runId = state.runId;
    final driver = ref.read(channelDriverProvider);
    _nativeUpdates = _nativeUpdates.then((_) async {
      if (!ref.mounted || state.runId != runId) return;
      try {
        await driver.setConfirmation(confirmation);
      } on Failure catch (failure) {
        AppLogger.warning('原生任务控制界面不可用，停止任务');
        if (ref.mounted && state.runId == runId && runId != null) {
          stopRun(runId);
          state = ExecutionState(
            runId: runId,
            foreground: state.foreground,
            failure: failure,
          );
        }
      }
    });
  }
}
