import 'dart:async';
import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/error/failure.dart';
import '../../../core/utils/id.dart';
import '../../../core/utils/logger.dart';
import '../../../data/models/command_task.dart';
import '../../../data/models/conversation.dart';
import '../../../data/models/workspace.dart';
import '../../../data/repositories/command_task_repository.dart';
import '../../../data/repositories/conversation_repository.dart';
import '../../../data/repositories/workspace_repository.dart';
import '../tools/tool.dart';
import '../workspace/process_api.g.dart';
import '../workspace/process_driver.dart';
import 'task_output_buffer.dart';

part 'command_task_controller.g.dart';

class CommandTaskState {
  const CommandTaskState({
    this.tasks = const [],
    this.initialized = false,
    this.loading = false,
    this.error,
    this.outputRevision = 0,
    this.completionErrors = const {},
    this.completionRetryRevision = 0,
  });
  final List<CommandTask> tasks;
  final bool initialized;
  final bool loading;
  final Failure? error;
  final int outputRevision;
  final Map<String, Failure> completionErrors;
  final int completionRetryRevision;
  List<CommandTask> get pendingCompletions => tasks
      .where(
        (task) => task.completionDelivery == TaskCompletionDelivery.pending,
      )
      .toList();
}

class CommandTaskOutput {
  const CommandTaskOutput(this.task, this.stdout, this.stderr);
  final CommandTask task;
  final TaskOutputPage stdout;
  final TaskOutputPage stderr;
  Map<String, dynamic> toJson() => {
    ...task.summary(),
    'stdout': stdout.toJson(),
    'stderr': stderr.toJson(),
  };
}

class _LiveTask {
  _LiveTask(this.task);
  CommandTask task;
  final stdout = TaskOutputBuffer();
  final stderr = TaskOutputBuffer();
  final done = Completer<void>();
  LinuxProcess? process;
  WorkspaceLease? lease;
  bool stopRequested = false;
  bool finishing = false;
  bool dirty = false;
  bool recorded = false;
  int pendingSaves = 0;
  final waiters = <RunCancellation>{};
  bool handedOff = false;
  bool suppressCompletion = false;
  Future<void> saves = Future.value();
  String get owner => 'task-${task.id}';
  CommandTaskData get data => CommandTaskData(
    task.copyWith(
      stdoutBytes: stdout.totalBytes,
      stderrBytes: stderr.totalBytes,
    ),
    stdout.bytes,
    stderr.bytes,
  );
}

@Riverpod(keepAlive: true)
class CommandTaskController extends _$CommandTaskController {
  static const maxActivePerConversation = 10;
  static const maxActiveTasks = 32;
  final _active = <String, _LiveTask>{};
  final _completionOwners = <String, ({String owner, String conversationId})>{};
  final _unsaved = <String, CommandTaskData>{};
  final _removing = <String>{};
  Future<void>? _initialization;
  CommandTaskRepository? _repository;
  ProcessDriver? _driver;
  StreamSubscription<String>? _stops;
  Timer? _flushTimer;
  List<CommandTask> get tasks => state.tasks;

  @override
  CommandTaskState build() {
    ref.onDispose(() {
      _flushTimer?.cancel();
      unawaited(_stops?.cancel());
      for (final live in _active.values.toList()) {
        live.stopRequested = true;
        live.suppressCompletion = true;
        unawaited(
          _driver?.endTask(live.owner).catchError((Object _) {
            AppLogger.warning('后台任务释放未收到进程回执');
          }),
        );
      }
      for (final entry in _completionOwners.values.toList()) {
        unawaited(
          _driver?.endTask(entry.owner).catchError((Object _) {
            AppLogger.warning('任务续答宿主释放未收到回执');
          }),
        );
      }
    });
    return const CommandTaskState();
  }

  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    _publish(loading: true, clearError: true);
    try {
      final repository = await ref.read(commandTaskRepositoryProvider.future);
      await repository.recover();
      final tasks = await repository.list();
      if (!ref.mounted) throw const OperationFailure('任务管理已关闭');
      _repository = repository;
      state = CommandTaskState(
        tasks: List.unmodifiable(tasks),
        initialized: true,
      );
    } catch (error) {
      _initialization = null;
      _publish(loading: false, error: _failure(error, '任务列表读取失败'));
      rethrow;
    }
  }

  void _publish({
    CommandTask? task,
    bool? loading,
    Failure? error,
    bool clearError = false,
    bool outputChanged = false,
    String? removed,
    Map<String, Failure>? completionErrors,
    int? completionRetryRevision,
  }) {
    if (!ref.mounted) return;
    final tasks = [
      for (final value in state.tasks)
        if (value.id != removed && value.id != task?.id) value,
      ?task,
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    state = CommandTaskState(
      tasks: List.unmodifiable(tasks),
      initialized: state.initialized,
      loading: loading ?? state.loading,
      error: clearError && _unsaved.isEmpty ? null : error ?? state.error,
      outputRevision: state.outputRevision + (outputChanged ? 1 : 0),
      completionErrors: Map.unmodifiable(
        completionErrors ?? state.completionErrors,
      ),
      completionRetryRevision:
          completionRetryRevision ?? state.completionRetryRevision,
    );
  }

  static Failure _failure(Object error, String message) =>
      error is Failure ? error : OperationFailure(message);

  void _connectDriver() {
    if (_driver != null) return;
    final driver = ref.read(processDriverProvider);
    _driver = driver;
    _stops = driver.stops.listen((owner) {
      for (final live in _active.values.toList()) {
        if (live.owner != owner) continue;
        unawaited(
          stop(live.task.id).then<void>((_) {}).catchError((Object error) {
            _publish(error: _failure(error, '后台任务停止失败'));
          }),
        );
      }
    });
  }

  static void validateCommand(String command, String cwd, int? timeoutMs) {
    if (command.trim().isEmpty ||
        command.contains('\u0000') ||
        utf8.encode(command).length > 120 * 1024 ||
        !cwd.startsWith('/') ||
        cwd.contains('\u0000') ||
        utf8.encode(cwd).length > 4096 ||
        (timeoutMs != null && (timeoutMs <= 0 || timeoutMs > 2147483647))) {
      throw const OperationFailure('命令、工作目录或超时无效');
    }
  }

  Future<CommandTask> startForConversation({
    required String conversationId,
    required String command,
    required RunCancellation cancellation,
    String? cwd,
    String? title,
    int? timeoutMs,
    bool notifyOnCompletion = true,
  }) async {
    final conversations = await ref.read(conversationRepositoryProvider.future);
    final thread = await conversations.getThread(conversationId);
    final workspaceId = thread?.conversation.workspaceId;
    if (workspaceId == null) throw const OperationFailure('会话工作区不可用');
    final workspaces = await ref.read(workspaceRepositoryProvider.future);
    return start(
      conversationId: conversationId,
      workspace: await workspaces.snapshot(workspaceId),
      command: command,
      cancellation: cancellation,
      cwd: cwd,
      title: title,
      timeoutMs: timeoutMs,
      notifyOnCompletion: notifyOnCompletion,
    );
  }

  Future<CommandTask> restart(String id, RunCancellation cancellation) async {
    await initialize();
    final previous = task(id);
    if (previous.status.active) throw const OperationFailure('请先停止任务再重新运行');
    return start(
      conversationId: previous.conversationId,
      workspace: previous.workspace,
      command: previous.command,
      cwd: previous.cwd,
      title: previous.title,
      timeoutMs: previous.timeoutMs,
      cancellation: cancellation,
      notifyOnCompletion: previous.notifyOnCompletion,
    );
  }

  Future<CommandTask> start({
    required String conversationId,
    required WorkspaceSnapshot workspace,
    required String command,
    required RunCancellation cancellation,
    String? cwd,
    String? title,
    int? timeoutMs,
    String? runId,
    String? toolCallId,
    bool notifyOnCompletion = true,
    Duration? waitFor,
  }) async {
    final directory = cwd ?? workspace.executionRoot;
    validateCommand(command, directory, timeoutMs);
    if (title != null && (title.trim().isEmpty || title.length > 120)) {
      throw const OperationFailure('任务名称需要 1 至 120 个字符');
    }
    await initialize();
    cancellation.throwIfCancelled();
    if (!ref.mounted) throw const OperationFailure('任务管理已关闭');
    if (_active.length >= maxActiveTasks ||
        _active.values
                .where((t) => t.task.conversationId == conversationId)
                .length >=
            maxActivePerConversation) {
      throw const OperationFailure('后台任务数量达到上限，请先停止不再需要的任务');
    }
    if (toolCallId != null) {
      if (_active.values.any(
        (live) => live.task.toolCallId == toolCallId && !live.recorded,
      )) {
        throw const OperationFailure('此工具调用正在启动任务，请勿重复派发');
      }
      final existing = state.tasks.where((t) => t.toolCallId == toolCallId);
      if (existing.isNotEmpty) return existing.first;
    }
    _connectDriver();
    final task = CommandTask(
      id: generateId(),
      conversationId: conversationId,
      workspace: workspace,
      title:
          title?.trim() ??
          String.fromCharCodes(
            command.trim().split('\n').first.runes.take(120),
          ),
      command: command,
      cwd: directory,
      createdAt: DateTime.now(),
      timeoutMs: timeoutMs,
      runId: runId,
      toolCallId: toolCallId,
      notifyOnCompletion: notifyOnCompletion,
    );
    final live = _LiveTask(task);
    _active[task.id] = live;
    var recorded = false;
    var committed = false;
    cancellation.whenCancelled.then((_) {
      if (!committed) live.stopRequested = true;
    });
    try {
      final workspaces = await ref.read(workspaceRepositoryProvider.future);
      live.lease = await workspaces.retainTask(workspace);
      cancellation.throwIfCancelled();
      if (!ref.mounted || live.stopRequested) throw const ToolCancelled();
      await _repository!.add(task);
      recorded = true;
      live.recorded = true;
      _publish(task: task, clearError: true);
      await _driver!.beginTask(live.owner, '后台任务 ${task.title}');
      cancellation.throwIfCancelled();
      if (!ref.mounted || live.stopRequested) throw const ToolCancelled();
      final process = await _driver!.start(
        LinuxProcessSpec(
          ownerId: live.owner,
          processId: task.id,
          rootfs: workspace.environmentRoot!,
          executable: '/bin/sh',
          argv: ['-c', command],
          cwd: directory,
          environment: {},
          timeoutMs: timeoutMs,
          outputLimitBytes: null,
        ),
        (stderr, bytes) async {
          (stderr ? live.stderr : live.stdout).add(bytes);
          live.dirty = true;
          _scheduleFlush();
        },
      );
      live.process = process;
      unawaited(process.exited.then((event) => _finish(live, event)));
      try {
        await process.closeInput();
      } on Failure {
        if (!live.finishing) rethrow;
      }
      if (live.stopRequested || cancellation.isCancelled || !ref.mounted) {
        await stop(task.id);
        throw const ToolCancelled();
      }
      if (!live.finishing) {
        live.task = live.task.copyWith(
          status: CommandTaskStatus.running,
          startedAt: DateTime.now(),
        );
        await _save(live);
        _publish(task: live.data.task);
      }
      if (live.stopRequested || cancellation.isCancelled || !ref.mounted) {
        await stop(task.id);
        throw const ToolCancelled();
      }
      if (waitFor != null && waitFor > Duration.zero) {
        await wait(
          task.id,
          waitFor,
          conversationId: conversationId,
          cancellation: cancellation,
        );
        if (cancellation.isCancelled) throw const ToolCancelled();
      }
      committed = true;
      live.handedOff = true;
      return live.data.task;
    } catch (error) {
      live.stopRequested = true;
      live.suppressCompletion = true;
      if (live.process != null) {
        await live.process!.cancel();
        await live.done.future;
      } else {
        live.task = live.task.copyWith(
          status: error is ToolCancelled
              ? CommandTaskStatus.cancelled
              : CommandTaskStatus.failed,
          finishedAt: DateTime.now(),
          error: error is ToolCancelled
              ? null
              : _failure(error, '任务启动失败').userMessage,
        );
        try {
          if (recorded) await _save(live);
        } finally {
          await _release(live);
          _publish(task: recorded ? live.task : null);
        }
      }
      rethrow;
    }
  }

  Future<void> _save(_LiveTask live) {
    live.pendingSaves++;
    final data = live.data;
    final save = live.saves.then((_) async {
      try {
        await _repository!.save(data);
        _unsaved.remove(data.task.id);
      } catch (_) {
        _unsaved[data.task.id] = data;
        rethrow;
      }
    });
    live.saves = save
        .catchError((Object error) {
          _publish(error: _failure(error, '任务记录保存失败'));
        })
        .whenComplete(() {
          live.pendingSaves--;
          if (live.dirty && !live.finishing && ref.mounted) _scheduleFlush();
        });
    return save;
  }

  void _scheduleFlush() {
    if (!ref.mounted) return;
    _flushTimer ??= Timer(const Duration(milliseconds: 500), () {
      _flushTimer = null;
      for (final live in _active.values.toList()) {
        // Slow storage must not queue an unbounded number of output snapshots.
        if (!live.dirty || live.finishing || live.pendingSaves > 0) continue;
        live.dirty = false;
        _publish(task: live.data.task, outputChanged: true);
        unawaited(
          _save(live).catchError((Object error) async {
            live.task = live.task.copyWith(error: '任务日志保存失败，已请求停止');
            _publish(task: live.task, error: _failure(error, '任务日志保存失败'));
            try {
              await stop(live.task.id);
            } on Failure catch (failure) {
              _publish(error: failure);
            }
          }),
        );
      }
    });
  }

  Future<void> _finish(_LiveTask live, LinuxProcessEvent event) async {
    if (live.finishing) return;
    live.finishing = true;
    final status = event.error != null
        ? CommandTaskStatus.failed
        : event.timedOut
        ? CommandTaskStatus.timedOut
        : event.cancelled || live.stopRequested
        ? CommandTaskStatus.cancelled
        : event.exitCode == 0 && event.signal == null
        ? CommandTaskStatus.succeeded
        : CommandTaskStatus.failed;
    live.task = live.data.task.copyWith(
      status: status,
      exitCode: event.exitCode,
      signal: event.signal,
      finishedAt: DateTime.now(),
      error: event.error == null ? null : '任务进程未返回完整结果',
      completionDelivery:
          live.task.notifyOnCompletion &&
              live.handedOff &&
              !live.waiters.any((waiter) => !waiter.isCancelled) &&
              !live.suppressCompletion
          ? TaskCompletionDelivery.pending
          : TaskCompletionDelivery.suppressed,
    );
    try {
      await _save(live);
    } catch (error) {
      live.task = live.task.copyWith(error: '任务终态未能保存，请重试刷新');
      _publish(error: _failure(error, '任务终态保存失败'));
    } finally {
      await _release(live);
      _publish(task: live.task, outputChanged: true);
    }
  }

  Future<void> _release(_LiveTask live) async {
    try {
      if (ref.mounted &&
          !_unsaved.containsKey(live.task.id) &&
          live.task.completionDelivery == TaskCompletionDelivery.pending) {
        _completionOwners[live.task.id] = (
          owner: live.owner,
          conversationId: live.task.conversationId,
        );
      } else {
        await _driver?.endTask(live.owner);
      }
    } catch (error) {
      _publish(error: _failure(error, '任务服务未确认结束'));
    } finally {
      live.lease?.close();
      _active.remove(live.task.id);
      if (!live.done.isCompleted) live.done.complete();
    }
  }

  CommandTask task(String id, {String? conversationId}) {
    final value =
        _active[id]?.data.task ??
        state.tasks.where((t) => t.id == id).firstOrNull;
    if (value == null ||
        (conversationId != null && value.conversationId != conversationId)) {
      throw const OperationFailure('任务不存在或不属于当前会话');
    }
    return value;
  }

  Future<CommandTask> stop(
    String id, {
    String? conversationId,
    bool modelInitiated = false,
  }) async {
    await initialize();
    task(id, conversationId: conversationId);
    final live = _active[id];
    if (live == null) {
      if (modelInitiated) {
        await collectCompletion(id, conversationId: conversationId);
      }
      return task(id, conversationId: conversationId);
    }
    if (modelInitiated) live.suppressCompletion = true;
    live.stopRequested = true;
    if (!live.finishing) {
      live.task = live.task.copyWith(status: CommandTaskStatus.stopping);
      _publish(task: live.data.task);
      final saving = live.recorded ? _save(live) : Future<void>.value();
      try {
        await live.process?.cancel();
      } finally {
        await saving;
      }
    }
    await live.done.future;
    if (modelInitiated) {
      await collectCompletion(id, conversationId: conversationId);
    }
    return task(id, conversationId: conversationId);
  }

  Future<void> stopAll({String? conversationId}) async {
    await initialize();
    final ids = [
      for (final live in _active.values)
        if (conversationId == null ||
            live.task.conversationId == conversationId)
          live.task.id,
    ];
    Failure? failure;
    await Future.wait(
      ids.map((id) async {
        try {
          await stop(id);
        } catch (error) {
          failure ??= _failure(error, '部分任务未能停止');
        }
      }),
    );
    if (failure != null) throw failure!;
  }

  Future<CommandTask> wait(
    String id,
    Duration duration, {
    required String conversationId,
    RunCancellation? cancellation,
  }) async {
    task(id, conversationId: conversationId);
    final live = _active[id];
    if (live != null && duration > Duration.zero) {
      final waiter = RunCancellation();
      cancellation?.whenCancelled.then((_) => waiter.cancel());
      live.waiters.add(waiter);
      final delay = Completer<void>();
      final timer = Timer(duration, () {
        waiter.cancel();
        delay.complete();
      });
      try {
        await Future.any([
          live.done.future,
          delay.future,
          if (cancellation != null) cancellation.whenCancelled,
        ]);
        cancellation?.throwIfCancelled();
      } finally {
        timer.cancel();
        live.waiters.remove(waiter);
      }
    }
    return task(id, conversationId: conversationId);
  }

  List<CommandTask> pendingCompletions(String conversationId) => tasks
      .where(
        (task) =>
            task.conversationId == conversationId &&
            task.completionDelivery == TaskCompletionDelivery.pending &&
            !_active.containsKey(task.id) &&
            !_unsaved.containsKey(task.id),
      )
      .toList();

  Future<void> collectCompletion(String id, {String? conversationId}) async {
    await initialize();
    final value = task(id, conversationId: conversationId);
    if (value.status.active ||
        value.completionDelivery != TaskCompletionDelivery.pending) {
      return;
    }
    final live = _active[id];
    if (live != null) {
      live.suppressCompletion = true;
      live.task = live.task.copyWith(
        completionDelivery: TaskCompletionDelivery.suppressed,
      );
      await _save(live);
      _publish(task: live.data.task);
    } else {
      final data = _unsaved[id] ?? await _repository!.get(id);
      if (data == null) throw const OperationFailure('任务记录已删除');
      final updated = data.task.copyWith(
        completionDelivery: TaskCompletionDelivery.suppressed,
      );
      await _repository!.save(
        CommandTaskData(updated, data.stdout, data.stderr),
      );
      _unsaved.remove(id);
      _publish(task: updated);
    }
    await releaseCompletionHosts(conversationId: value.conversationId);
  }

  Future<bool> deliverCompletions(
    String conversationId,
    String runId,
    ConversationRepository conversations, {
    String? messageId,
  }) async {
    await initialize();
    final delivered = await _repository!.deliverCompletions(
      conversationId: conversationId,
      runId: runId,
      messageId: messageId ?? generateId(),
      conversations: conversations,
      taskIds: {for (final task in pendingCompletions(conversationId)) task.id},
    );
    for (final task in delivered) {
      _publish(task: task);
    }
    return delivered.isNotEmpty;
  }

  void reportCompletionError(String conversationId, Failure? failure) {
    final errors = {...state.completionErrors};
    if (failure == null) {
      errors.remove(conversationId);
    } else {
      errors[conversationId] = failure;
    }
    _publish(completionErrors: errors);
  }

  void retryCompletionDelivery() => _publish(
    completionErrors: {},
    completionRetryRevision: state.completionRetryRevision + 1,
  );

  Future<void> releaseCompletionHosts({
    String? conversationId,
    bool pending = false,
  }) async {
    for (final entry in _completionOwners.entries.toList()) {
      final task = state.tasks
          .where((task) => task.id == entry.key)
          .firstOrNull;
      if (conversationId != null &&
          entry.value.conversationId != conversationId) {
        continue;
      }
      if (!pending &&
          task?.completionDelivery == TaskCompletionDelivery.pending) {
        continue;
      }
      await _driver?.endTask(entry.value.owner);
      _completionOwners.remove(entry.key);
    }
  }

  Future<CommandTaskOutput> output(
    String id, {
    String? conversationId,
    int? stdoutOffset,
    int? stderrOffset,
    int maxBytes = 12 * 1024,
  }) async {
    await initialize();
    if (maxBytes <= 0 || maxBytes > TaskOutputBuffer.retainBytes) {
      throw const OperationFailure('日志读取大小超出允许范围');
    }
    var value = task(id, conversationId: conversationId);
    final live = _active[id];
    TaskOutputBuffer out;
    TaskOutputBuffer err;
    if (live != null) {
      out = live.stdout;
      err = live.stderr;
    } else {
      final data = _unsaved[id] ?? await _repository!.get(id);
      if (data == null) throw const OperationFailure('任务记录已删除');
      value = data.task;
      out = TaskOutputBuffer(
        retained: data.stdout,
        totalBytes: value.stdoutBytes,
      );
      err = TaskOutputBuffer(
        retained: data.stderr,
        totalBytes: value.stderrBytes,
      );
    }
    if ((stdoutOffset != null &&
            (stdoutOffset < 0 || stdoutOffset > out.totalBytes)) ||
        (stderrOffset != null &&
            (stderrOffset < 0 || stderrOffset > err.totalBytes))) {
      throw const OperationFailure('日志读取位置超出任务输出范围');
    }
    return CommandTaskOutput(
      value,
      out.read(
        offset: stdoutOffset,
        maxBytes: maxBytes,
        finalOutput: !value.status.active,
      ),
      err.read(
        offset: stderrOffset,
        maxBytes: maxBytes,
        finalOutput: !value.status.active,
      ),
    );
  }

  Future<void> remove(String id) async {
    await initialize();
    if (task(id).status.active || _active.containsKey(id)) {
      throw const OperationFailure('请先停止任务，再删除记录');
    }
    if (!_removing.add(id)) return;
    try {
      await _repository!.remove(id);
      _unsaved.remove(id);
      _publish(removed: id);
      await releaseCompletionHosts();
    } finally {
      _removing.remove(id);
    }
  }

  Future<void> refresh() async {
    await initialize();
    for (final live in _active.values.toList()) {
      await _save(live);
    }
    for (final data in _unsaved.values.toList()) {
      await _repository!.save(data);
      if (identical(_unsaved[data.task.id], data)) {
        _unsaved.remove(data.task.id);
      }
    }
    final tasks = await _repository!.list();
    if (ref.mounted) {
      state = CommandTaskState(
        tasks: List.unmodifiable([
          for (final value in tasks) _active[value.id]?.data.task ?? value,
        ]),
        initialized: true,
        outputRevision: state.outputRevision + 1,
        completionErrors: state.completionErrors,
        completionRetryRevision: state.completionRetryRevision,
      );
    }
  }
}

@riverpod
Stream<List<Conversation>> taskConversations(Ref ref) async* {
  yield* (await ref.watch(conversationRepositoryProvider.future))
      .watchConversations();
}

@riverpod
Future<CommandTaskOutput> commandTaskOutput(
  Ref ref,
  String id, {
  int? stdoutOffset,
  int? stderrOffset,
}) {
  ref.watch(commandTaskControllerProvider);
  return ref
      .read(commandTaskControllerProvider.notifier)
      .output(
        id,
        maxBytes: 32 * 1024,
        stdoutOffset: stdoutOffset,
        stderrOffset: stderrOffset,
      );
}
