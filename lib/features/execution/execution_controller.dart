import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/error/failure.dart';
import '../../../core/utils/logger.dart';
import '../../../data/models/tool_call_record.dart';
import '../../../data/models/execution_scope.dart';
import '../tools/tool.dart';
import '../tools/tool_executor.dart';
import 'channel_driver.dart';
import 'execution_api.g.dart';
import 'task_activity.dart';

part 'execution_controller.g.dart';

class ExecutionState {
  const ExecutionState({
    this.runId,
    this.confirmation,
    this.foreground = true,
    this.failure,
    this.activity = const TaskActivity(),
    this.userAction,
  });
  final String? runId;
  final ToolConfirmationRequest? confirmation;
  final bool foreground;
  final Failure? failure;
  final TaskActivity activity;
  final UserActionRequest? userAction;

  ExecutionState copyWith({
    ToolConfirmationRequest? confirmation,
    bool clearConfirmation = false,
    bool? foreground,
    Failure? failure,
    TaskActivity? activity,
    UserActionRequest? userAction,
    bool clearUserAction = false,
  }) => ExecutionState(
    runId: runId,
    confirmation: clearConfirmation ? null : confirmation ?? this.confirmation,
    foreground: foreground ?? this.foreground,
    failure: failure ?? this.failure,
    activity: activity ?? this.activity,
    userAction: clearUserAction ? null : userAction ?? this.userAction,
  );
}

/// 根任务的用户控制，与页面/Activity 的挂接无关。决定由 ToolExecutor 落库。
@Riverpod(keepAlive: true)
class ExecutionController extends _$ExecutionController {
  Completer<ToolDecision>? _decision;
  void Function()? _stop;
  Timer? _expiry;
  bool _deviceTask = false;
  bool _nativeTask = false;
  ExecutionScope _scope = const ExecutionScope();
  bool _stopped = false;
  Future<void> _nativeUpdates = Future.value();
  StreamSubscription<NativeExecutionEvent>? _nativeSubscription;
  Completer<bool>? _continue;
  Timer? _panelTimer;
  bool _panelQueued = false;
  bool? _darkTheme;
  Future<void> Function(String, RunCancellation)? _runMessageHandler;
  Future<void> Function(String, RunCancellation)? _panelMessageHandler;
  String? _panelRunId;
  NativePanelMessage? _pendingPanelMessage;

  @override
  ExecutionState build() {
    ref.onDispose(() {
      _expiry?.cancel();
      _panelTimer?.cancel();
      _completeContinue(false);
      _stop?.call();
      _complete(ToolDecision.expired);
      _pendingPanelMessage?.cancellation.cancel();
      _pendingPanelMessage?.complete('任务已结束，请返回相月重试');
      unawaited(_nativeSubscription?.cancel());
    });
    return const ExecutionState();
  }

  void beginRun(
    String runId, {
    required void Function() stop,
    ExecutionScope scope = const ExecutionScope(),
    bool? darkTheme,
    Future<void> Function(String, RunCancellation)? onPanelMessage,
  }) {
    if (state.runId != null) throw const OperationFailure('已有运行中的任务');
    _stop = stop;
    _stopped = false;
    _deviceTask = false;
    _nativeTask = false;
    _scope = scope;
    _darkTheme = darkTheme;
    _runMessageHandler = onPanelMessage;
    state = ExecutionState(runId: runId, foreground: state.foreground);
  }

  /// 实际使用设备工具或命令面板时才启动；仅开放工具的普通聊天不启动服务。
  Future<void> ensureDeviceHost(String runId, {bool deviceTask = true}) async {
    if (state.runId != runId || _stopped) {
      throw const ExecutionFailure(ExecutionFailureCode.cancelled);
    }
    if (_nativeTask && (!deviceTask || _deviceTask)) return;
    try {
      final driver = ref.read(channelDriverProvider);
      _nativeSubscription ??= driver.events.listen(_onNativeEvent);
      await driver.startRun(runId, scope: _scope, deviceTask: deviceTask);
      if (!ref.mounted || state.runId != runId || _stopped) {
        await driver.endRun(runId);
        throw const ExecutionFailure(ExecutionFailureCode.cancelled);
      }
      _nativeTask = true;
      _deviceTask = _deviceTask || deviceTask;
      if (deviceTask) {
        _panelRunId = runId;
        _panelMessageHandler = _runMessageHandler;
      }
      _syncPanel();
    } on Failure catch (failure) {
      // 准备失败尚未派发动作，交给工具结果回填；明确的 NativeStop 仍停止根任务。
      if (ref.mounted && state.runId == runId) {
        _deviceTask = false;
        _nativeTask = false;
        state = ExecutionState(
          runId: runId,
          foreground: state.foreground,
          failure: failure,
        );
      }
      rethrow;
    }
  }

  /// 命令本身不要求无障碍；已有权限且仍在前台时附带任务面板。
  Future<void> showAvailablePanel(String runId) async {
    if (_deviceTask || _stopped || state.runId != runId) return;
    try {
      final capabilities = await ref
          .read(channelDriverProvider)
          .queryCapabilities();
      if (!capabilities.accessibilityConnected ||
          !capabilities.notificationsAllowed ||
          !capabilities.activityResumed ||
          !ref.mounted ||
          _stopped) {
        return;
      }
      await ensureDeviceHost(runId);
    } on Failure {
      // 这是附加展示，不让它成为 Linux 命令的新权限前置。
      if (ref.mounted && state.runId == runId) {
        state = state.copyWith(
          failure: const OperationFailure('悬浮面板暂不可用，仍可通过任务通知停止命令'),
        );
      }
    }
  }

  Future<void> endRun(String runId) async {
    if (state.runId != runId) return;
    _panelTimer?.cancel();
    _panelTimer = null;
    // 终态面板保留最后的公开文本，收口前提交尚未跨平台刷新的快照。
    _syncPanel();
    _completeContinue(false);
    _complete(ToolDecision.expired);
    _stop = null;
    if (_nativeTask) {
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
        _nativeTask = false;
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
    state = state.copyWith(confirmation: request);
    _syncNative();
    try {
      return await Future.any([
        decision.future,
        cancellation.whenCancelled.then((_) => ToolDecision.expired),
      ]);
    } finally {
      _expiry?.cancel();
      if (identical(_decision, decision)) _decision = null;
      if (ref.mounted && state.runId == request.record.runId) {
        state = state.copyWith(clearConfirmation: true);
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
    _completeContinue(false);
    _stop?.call();
    _complete(ToolDecision.expired);
  }

  void setForeground(bool foreground) {
    if (state.foreground == foreground) return;
    state = state.copyWith(foreground: foreground);
    _syncNative();
  }

  void _complete(ToolDecision value) {
    if (_decision != null && !_decision!.isCompleted) {
      _decision!.complete(value);
    }
  }

  void _onNativeEvent(NativeExecutionEvent event) {
    switch (event) {
      case NativeStop(:final runId, :final reason):
        final pendingMessage = _pendingPanelMessage;
        if (reason != 'panelMessage' &&
            (pendingMessage?.runId == runId || state.runId == runId)) {
          pendingMessage?.cancellation.cancel();
        }
        final message = switch (reason) {
          'locked' => '设备已锁定，自动操作已停止',
          'permissionRequired' => '无障碍授权已关闭，自动操作已停止',
          'shizukuPermissionRequired' => 'Shizuku 授权或执行身份已改变，虚拟屏操作已停止',
          'channelDisabled' => 'Shizuku 已关闭，虚拟屏操作已停止',
          'channelDisconnected' => 'Shizuku 服务已断开，虚拟屏操作已停止',
          'serviceStopped' => '任务服务已停止',
          'applicationUnavailable' => '目标应用已不可用，自动操作已停止',
          _ => null,
        };
        if (message != null && state.runId == runId) {
          state = ExecutionState(
            runId: runId,
            foreground: state.foreground,
            failure: OperationFailure(message),
          );
        }
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
      case NativeContinue(:final runId, :final toolCallId):
        // 原生已在点击时检查前后台；Activity 紧接着切回不能丢掉这个决定。
        continueRun(runId, toolCallId);
      case NativePanelMessage():
        unawaited(_receivePanelMessage(event));
      case NativeCapabilities():
        // 能力变更不授予工具权限，也不自动继续已停止的任务。
        break;
    }
  }

  Future<void> _receivePanelMessage(NativePanelMessage request) async {
    final handler = _panelMessageHandler;
    if (request.runId != _panelRunId || handler == null) {
      request.complete('任务面板已失效，请返回相月重试');
      return;
    }
    if (_pendingPanelMessage != null) {
      request.complete('消息正在发送，请稍后重试');
      return;
    }
    _pendingPanelMessage = request;
    try {
      await handler(request.text, request.cancellation);
      request.complete(null);
    } on Failure catch (failure) {
      request.complete(failure.userMessage);
    } catch (_) {
      AppLogger.warning('悬浮面板消息发送失败');
      request.complete('发送失败，请稍后重试');
    } finally {
      if (identical(_pendingPanelMessage, request)) _pendingPanelMessage = null;
    }
  }

  void reportPanelFailure(Failure failure) {
    if (ref.mounted) state = state.copyWith(failure: failure);
  }

  void updateActivity(String runId, TaskActivity activity) {
    if (!ref.mounted || state.runId != runId || _stopped) return;
    state = state.copyWith(activity: activity);
    // 合并高频流式更新，不为每个 token 排队跨平台调用。
    _panelTimer ??= Timer(const Duration(milliseconds: 160), () {
      _panelTimer = null;
      _syncPanel();
    });
  }

  Future<void> waitForUser(
    UserActionRequest request,
    RunCancellation cancellation,
  ) async {
    cancellation.throwIfCancelled();
    if (_stopped || state.runId != request.runId) throw const ToolCancelled();
    if (!_deviceTask) {
      throw const ExecutionFailure(ExecutionFailureCode.unavailable);
    }
    if (_continue != null) throw const OperationFailure('已有待完成的用户操作');
    final pending = Completer<bool>();
    _continue = pending;
    ref.read(channelDriverProvider).clearSnapshot();
    state = state.copyWith(userAction: request);
    _syncPanel();
    try {
      final resumed = await Future.any([
        pending.future,
        cancellation.whenCancelled.then((_) => false),
      ]);
      cancellation.throwIfCancelled();
      if (!resumed) throw const ToolCancelled();
    } finally {
      if (identical(_continue, pending)) _continue = null;
      if (ref.mounted && state.runId == request.runId) {
        state = state.copyWith(clearUserAction: true);
        _syncPanel();
      }
    }
  }

  bool continueRun(String runId, String toolCallId) {
    final pending = state.userAction;
    if (_stopped ||
        pending?.runId != runId ||
        pending?.toolCallId != toolCallId ||
        _continue == null ||
        _continue!.isCompleted) {
      return false;
    }
    _completeContinue(true);
    return true;
  }

  void _completeContinue(bool value) {
    if (_continue != null && !_continue!.isCompleted) {
      _continue!.complete(value);
    }
  }

  void _syncPanel() {
    if (!_deviceTask || _panelQueued) return;
    final runId = state.runId;
    if (runId == null) return;
    _panelQueued = true;
    _nativeUpdates = _nativeUpdates.then((_) async {
      _panelQueued = false;
      if (!ref.mounted || state.runId != runId) return;
      final activity = state.activity;
      final userAction = state.userAction;
      try {
        await ref
            .read(channelDriverProvider)
            .setTaskPanel(
              TaskPanelSnapshot(
                runId: runId,
                phase: userAction == null
                    ? activity.phase
                    : TaskPanelPhase.waitingUser,
                status: userAction == null ? activity.status : '等待你操作',
                messages: activity.messages
                    .map((entry) => entry.toBridge())
                    .toList(),
                waitingToolCallId: userAction?.toolCallId,
                userPrompt: userAction?.prompt,
                darkTheme: _darkTheme,
              ),
            );
      } on Failure catch (failure) {
        if (ref.mounted && state.runId == runId) {
          stopRun(runId);
          state = state.copyWith(failure: failure);
        }
      }
    });
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
            applicationOperationsForRun: request.applicationOperationsForRun,
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
