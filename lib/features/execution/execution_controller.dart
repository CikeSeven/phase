import 'dart:async';
import 'dart:io' show Platform;

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
    this.activities = const {},
    this.activeRunIds = const {},
    this.userAction,
  });
  final String? runId;
  final ToolConfirmationRequest? confirmation;
  final bool foreground;
  final Failure? failure;
  final TaskActivity activity;
  final Map<String, TaskActivity> activities;
  final Set<String> activeRunIds;
  final UserActionRequest? userAction;

  ExecutionState copyWith({
    ToolConfirmationRequest? confirmation,
    bool clearConfirmation = false,
    bool? foreground,
    Failure? failure,
    TaskActivity? activity,
    Map<String, TaskActivity>? activities,
    Set<String>? activeRunIds,
    String? runId,
    bool clearRunId = false,
    UserActionRequest? userAction,
    bool clearUserAction = false,
  }) => ExecutionState(
    runId: clearRunId ? null : runId ?? this.runId,
    confirmation: clearConfirmation ? null : confirmation ?? this.confirmation,
    foreground: foreground ?? this.foreground,
    failure: failure ?? this.failure,
    activity: activity ?? this.activity,
    activities: activities ?? this.activities,
    activeRunIds: activeRunIds ?? this.activeRunIds,
    userAction: clearUserAction ? null : userAction ?? this.userAction,
  );
}

/// 根任务的用户控制，与页面/Activity 的挂接无关。决定由 ToolExecutor 落库。
@Riverpod(keepAlive: true)
class ExecutionController extends _$ExecutionController {
  TaskActivity get activity =>
      ref.mounted ? state.activity : const TaskActivity();

  final _stops = <String, void Function()>{};
  Timer? _expiry;
  final _nativeRuns = <String>{};
  final _deviceRuns = <String>{};
  final _scopes = <String, ExecutionScope>{};
  final _stoppedRuns = <String>{};
  bool get _deviceTask => state.runId != null;
  Future<void> _nativeUpdates = Future.value();
  StreamSubscription<NativeExecutionEvent>? _nativeSubscription;
  Completer<bool>? _continue;
  Timer? _panelTimer;
  bool _panelQueued = false;
  bool? _darkTheme;
  final _runMessageHandlers =
      <String, Future<void> Function(String, RunCancellation)>{};
  Future<void> Function(String, RunCancellation)? _panelMessageHandler;
  String? _panelRunId;
  NativePanelMessage? _pendingPanelMessage;
  final _confirmationQueue = <_QueuedConfirmation>[];
  _QueuedConfirmation? _activeConfirmation;

  TaskActivity activityFor(String runId) => ref.mounted
      ? state.activities[runId] ?? const TaskActivity()
      : const TaskActivity();

  @override
  ExecutionState build() {
    ref.onDispose(() {
      _expiry?.cancel();
      _panelTimer?.cancel();
      _completeContinue(false);
      for (final stop in _stops.values) {
        stop();
      }
      _resolveActiveConfirmation(ToolDecision.expired);
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
    if (state.activeRunIds.contains(runId)) {
      throw const OperationFailure('此运行已注册');
    }
    _stops[runId] = stop;
    _scopes[runId] = scope;
    if (onPanelMessage != null) _runMessageHandlers[runId] = onPanelMessage;
    _stoppedRuns.remove(runId);
    _darkTheme = darkTheme;
    state = state.copyWith(
      activeRunIds: {...state.activeRunIds, runId},
      activities: {...state.activities, runId: const TaskActivity()},
    );
  }

  /// Android 上为所有模型运行启用共享任务服务，保证切到后台时进程保持活跃。
  Future<void> ensureBackgroundHost(String runId) async {
    if (Platform.isAndroid) {
      await ensureDeviceHost(runId, deviceTask: false);
    }
  }

  Future<void> ensureDeviceHost(String runId, {bool deviceTask = true}) async {
    if (!state.activeRunIds.contains(runId) || _stoppedRuns.contains(runId)) {
      throw const ExecutionFailure(ExecutionFailureCode.cancelled);
    }
    if (deviceTask && state.runId != null && state.runId != runId) {
      throw const OperationFailure('其他会话正在操作设备，请等待其完成后重试');
    }
    if (_nativeRuns.contains(runId) &&
        (!deviceTask || _deviceRuns.contains(runId))) {
      return;
    }
    try {
      final driver = ref.read(channelDriverProvider);
      _nativeSubscription ??= driver.events.listen(_onNativeEvent);
      await driver.startRun(
        runId,
        scope: _scopes[runId] ?? const ExecutionScope(),
        deviceTask: deviceTask,
      );
      if (!ref.mounted ||
          !state.activeRunIds.contains(runId) ||
          _stoppedRuns.contains(runId)) {
        await driver.endRun(runId);
        throw const ExecutionFailure(ExecutionFailureCode.cancelled);
      }
      _nativeRuns.add(runId);
      if (deviceTask) {
        _deviceRuns.add(runId);
        state = state.copyWith(runId: runId, activity: activityFor(runId));
        _panelRunId = runId;
        _panelMessageHandler = _runMessageHandlers[runId];
        _syncNative();
      }
      _syncPanel();
    } on Failure catch (failure) {
      // 准备失败尚未派发动作，交给工具结果回填；明确的 NativeStop 仍停止根任务。
      _nativeRuns.remove(runId);
      _deviceRuns.remove(runId);
      if (ref.mounted) {
        state = state.copyWith(failure: failure);
      }
      rethrow;
    }
  }

  /// 命令本身不要求无障碍；已有权限且仍在前台时附带任务面板。
  Future<void> showAvailablePanel(String runId) async {
    if (_deviceTask ||
        _stoppedRuns.contains(runId) ||
        !state.activeRunIds.contains(runId)) {
      return;
    }
    try {
      final capabilities = await ref
          .read(channelDriverProvider)
          .queryCapabilities();
      if (!capabilities.accessibilityConnected ||
          !capabilities.notificationsAllowed ||
          !capabilities.activityResumed ||
          !ref.mounted ||
          _stoppedRuns.contains(runId)) {
        return;
      }
      await ensureDeviceHost(runId);
    } on Failure {
      // 这是附加展示，不让它成为 Linux 命令的新权限前置。
      if (ref.mounted && state.activeRunIds.contains(runId)) {
        state = state.copyWith(
          failure: const OperationFailure('悬浮面板暂不可用，仍可通过任务通知停止命令'),
        );
      }
    }
  }

  Future<void> endRun(String runId) async {
    if (!state.activeRunIds.contains(runId)) return;
    _stoppedRuns.add(runId);
    final isDeviceRun = state.runId == runId;
    if (isDeviceRun) {
      _panelTimer?.cancel();
      _panelTimer = null;
      _syncPanel();
    }
    if (state.confirmation?.record.runId == runId) {
      _resolveActiveConfirmation(ToolDecision.expired);
    }
    for (final queued in _confirmationQueue.where(
      (entry) => entry.request.record.runId == runId,
    )) {
      if (!queued.result.isCompleted) {
        queued.result.complete(ToolDecision.expired);
      }
    }
    _confirmationQueue.removeWhere(
      (entry) => entry.request.record.runId == runId,
    );
    if (_continue?.isCompleted == false && state.userAction?.runId == runId) {
      _continue!.complete(false);
    }
    _stops.remove(runId);
    _runMessageHandlers.remove(runId);
    _scopes.remove(runId);
    try {
      if (_nativeRuns.contains(runId)) {
        await _nativeUpdates;
        await ref.read(channelDriverProvider).endRun(runId);
      }
    } finally {
      _nativeRuns.remove(runId);
      _deviceRuns.remove(runId);
      if (_panelRunId == runId) {
        _panelRunId = null;
        _panelMessageHandler = null;
      }
      if (_pendingPanelMessage?.runId == runId) {
        _pendingPanelMessage?.cancellation.cancel();
      }
      if (ref.mounted) {
        final confirmations = state.confirmation?.record.runId == runId;
        final userAction = state.userAction?.runId == runId;
        state = state.copyWith(
          activeRunIds: {...state.activeRunIds}..remove(runId),
          activities: {...state.activities}..remove(runId),
          clearRunId: isDeviceRun,
          activity: isDeviceRun ? const TaskActivity() : null,
          clearConfirmation: confirmations,
          clearUserAction: userAction,
        );
      }
      _stoppedRuns.remove(runId);
    }
  }

  Future<ToolDecision> confirm(
    ToolConfirmationRequest request,
    RunCancellation cancellation,
  ) async {
    if (!state.activeRunIds.contains(request.record.runId) ||
        _stoppedRuns.contains(request.record.runId) ||
        cancellation.isCancelled ||
        !request.expiresAt.isAfter(DateTime.now())) {
      return ToolDecision.expired;
    }
    final queued = _QueuedConfirmation(request, cancellation);
    _confirmationQueue.add(queued);
    _activateNextConfirmation();
    try {
      return await Future.any([
        queued.result.future,
        cancellation.whenCancelled.then((_) => ToolDecision.expired),
      ]);
    } finally {
      if (identical(_activeConfirmation, queued)) {
        _resolveActiveConfirmation(ToolDecision.expired);
      } else {
        _confirmationQueue.remove(queued);
        if (!queued.result.isCompleted) {
          queued.result.complete(ToolDecision.expired);
        }
      }
    }
  }

  /// 两端都只提交固定调用的决定；旧面板、重复提交与过期批准不会影响新调用。
  bool decide(String runId, String toolCallId, ToolDecision decision) {
    final request = state.confirmation;
    if (_stoppedRuns.contains(runId) ||
        !state.activeRunIds.contains(runId) ||
        request == null ||
        request.record.runId != runId ||
        request.record.id != toolCallId ||
        _activeConfirmation == null ||
        _activeConfirmation!.result.isCompleted) {
      return false;
    }
    if (!request.expiresAt.isAfter(DateTime.now())) {
      _resolveActiveConfirmation(ToolDecision.expired);
      return false;
    }
    _resolveActiveConfirmation(decision);
    return true;
  }

  void stopRun(String runId) {
    if (!state.activeRunIds.contains(runId) || !_stoppedRuns.add(runId)) {
      return;
    }
    if (state.userAction?.runId == runId) _completeContinue(false);
    if (state.confirmation?.record.runId == runId) {
      _resolveActiveConfirmation(ToolDecision.expired);
    }
    for (final queued in _confirmationQueue.where(
      (entry) => entry.request.record.runId == runId,
    )) {
      if (!queued.result.isCompleted) {
        queued.result.complete(ToolDecision.expired);
      }
    }
    _confirmationQueue.removeWhere(
      (entry) => entry.request.record.runId == runId,
    );
    _stops[runId]?.call();
  }

  void setForeground(bool foreground) {
    if (state.foreground == foreground) return;
    state = state.copyWith(foreground: foreground);
    _syncNative();
  }

  void _activateNextConfirmation() {
    if (_activeConfirmation != null) return;
    while (_confirmationQueue.isNotEmpty) {
      final next = _confirmationQueue.removeAt(0);
      final runId = next.request.record.runId;
      if (next.cancellation.isCancelled ||
          _stoppedRuns.contains(runId) ||
          !state.activeRunIds.contains(runId) ||
          !next.request.expiresAt.isAfter(DateTime.now())) {
        if (!next.result.isCompleted) {
          next.result.complete(ToolDecision.expired);
        }
        continue;
      }
      _activeConfirmation = next;
      _expiry = Timer(
        next.request.expiresAt.difference(DateTime.now()),
        () => _resolveActiveConfirmation(ToolDecision.expired),
      );
      state = state.copyWith(confirmation: next.request);
      _syncNative();
      return;
    }
  }

  void _resolveActiveConfirmation(ToolDecision decision) {
    final active = _activeConfirmation;
    if (active == null) return;
    _expiry?.cancel();
    _expiry = null;
    _activeConfirmation = null;
    if (!active.result.isCompleted) active.result.complete(decision);
    if (ref.mounted &&
        state.confirmation?.record.id == active.request.record.id) {
      state = state.copyWith(clearConfirmation: true);
      _syncNative();
    }
    _activateNextConfirmation();
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
        if (message != null && state.activeRunIds.contains(runId)) {
          state = state.copyWith(failure: OperationFailure(message));
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
                ? state.confirmation?.applicationOperationsForRun == true
                      ? ToolDecision.approvedForRun
                      : ToolDecision.approved
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
    if (!ref.mounted ||
        !state.activeRunIds.contains(runId) ||
        _stoppedRuns.contains(runId)) {
      return;
    }
    state = state.copyWith(
      activities: {...state.activities, runId: activity},
      activity: state.runId == runId ? activity : null,
    );
    // 合并高频流式更新，不为每个 token 排队跨平台调用。
    if (state.runId == runId) {
      _panelTimer ??= Timer(const Duration(milliseconds: 160), () {
        _panelTimer = null;
        _syncPanel();
      });
    }
  }

  Future<void> waitForUser(
    UserActionRequest request,
    RunCancellation cancellation,
  ) async {
    cancellation.throwIfCancelled();
    if (_stoppedRuns.contains(request.runId) || state.runId != request.runId) {
      throw const ToolCancelled();
    }
    if (!_deviceRuns.contains(request.runId)) {
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
    if (_stoppedRuns.contains(runId) ||
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
    final active = state.confirmation;
    final request = !state.foreground && active?.record.runId == state.runId
        ? active
        : null;
    final confirmation = request == null
        ? null
        : ExecutionConfirmation(
            runId: request.record.runId,
            toolCallId: request.record.id,
            toolName: request.record.toolName,
            summary: request.permission == null
                ? request.summary
                : '${request.summary}\n${request.permission!.reason}',
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
          state = state.copyWith(failure: failure);
        }
      }
    });
  }
}

class _QueuedConfirmation {
  _QueuedConfirmation(this.request, this.cancellation);

  final ToolConfirmationRequest request;
  final RunCancellation cancellation;
  final result = Completer<ToolDecision>();
}
