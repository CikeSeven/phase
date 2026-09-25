import 'dart:typed_data';
import 'dart:convert';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/error/failure.dart';
import '../../../core/utils/logger.dart';
import '../tools/tool.dart';
import 'command_api.g.dart';

part 'command_channel_driver.g.dart';

class CommandOperation {
  CommandOperation(
    this.driver,
    this.owner,
    this.call,
    this.onBytes,
    this.onProgress,
  );
  final CommandChannelDriver driver;
  final String owner;
  final String call;
  final Future<void> Function(bool, Uint8List) onBytes;
  final void Function(int)? onProgress;
  final done = Completer<ExternalCommandEvent>();
  int sequence = 0;
  String? failureCode;
  int transferredBytes = 0;
  Future<ExternalCommandEvent> wait(RunCancellation cancellation) async {
    final result = await Future.any<Object>([
      done.future,
      cancellation.whenCancelled.then<Object>((_) => const ToolCancelled()),
    ]);
    if (result is ExternalCommandEvent) return result;
    await driver.cancel(owner, call);
    return done.future;
  }
}

class CommandChannelDriver implements CommandChannelFlutterApi {
  CommandChannelDriver() {
    CommandChannelFlutterApi.setUp(this);
  }
  final _host = CommandChannelHostApi();
  final _active = <String, CommandOperation>{};
  final _changes = StreamController<void>.broadcast();
  final _stops = StreamController<String>.broadcast();
  bool _disposed = false;
  Stream<void> get changes => _changes.stream;
  Stream<String> get stops => _stops.stream;

  Future<T> _boundary<T>(
    Future<T> Function() call, {
    Duration timeout = const Duration(seconds: 25),
  }) async {
    if (_disposed) throw const CommandChannelFailure('unavailable', '命令通道已关闭');
    try {
      return await call().timeout(timeout);
    } on PlatformException catch (error) {
      throw CommandChannelFailure(error.code, commandErrorText(error.code));
    } on MissingPluginException {
      throw const CommandChannelFailure('unsupported', '此设备不提供系统命令通道');
    } on TimeoutException {
      throw const CommandChannelFailure('channelTimeout', '命令通道未及时响应');
    }
  }

  Future<List<CommandChannelStatus>> status() => _boundary(_host.status);
  Future<void> setEnabled(List<String> channels) =>
      _boundary(() => _host.setEnabled(channels));
  Future<void> authorize(String channel) =>
      _boundary(() => _host.authorize(channel));
  Future<void> initialize(String channel) => _boundary(
    () => _host.initialize(channel),
    timeout: const Duration(minutes: 3),
  );
  Future<void> openSettings(String channel) =>
      _boundary(() => _host.openSettings(channel));

  Future<Map<String, dynamic>> workspaceFile(
    WorkspaceFileRequest request,
    RunCancellation cancellation,
  ) async {
    final bytes = BytesBuilder(copy: false);
    cancellation.throwIfCancelled();
    final operation = await _start(
      request.ownerId,
      request.callId,
      () => _host.workspaceFile(request),
      (stderr, chunk) async {
        if (!stderr) {
          if (bytes.length + chunk.length > 128 * 1024) {
            throw const CommandChannelFailure('outputLimit', '文件操作响应超过上限');
          }
          bytes.add(chunk);
        }
      },
      null,
    );
    final result = await operation.wait(cancellation);
    if (result.cancelled || cancellation.isCancelled) {
      if (request.operation == WorkspaceFileOperation.importPath &&
          result.completedPaths.isNotEmpty) {
        throw WorkspaceFailure(
          'cancelled',
          '复制已停止，已提交的文件保留',
          completedPaths: result.completedPaths,
          cancelled: true,
        );
      }
      throw const ToolCancelled();
    }
    Map<String, dynamic>? body;
    try {
      final decoded = jsonDecode(utf8.decode(bytes.takeBytes()));
      if (decoded is Map<String, dynamic>) body = decoded;
    } on FormatException {
      /* A lost reply is not proof that a write did not occur. */
    }
    if (result.error != null ||
        result.exitCode != 0 ||
        body == null ||
        body['error'] != null) {
      final code =
          result.error ??
          (body?['error'] is String
              ? body!['error'] as String
              : 'fileOperationFailed');
      throw WorkspaceFailure(
        code,
        commandErrorText(code),
        completedPaths: result.completedPaths,
      );
    }
    return body;
  }

  Future<CommandOperation> start(
    ExternalCommandSpec spec,
    Future<void> Function(bool, Uint8List) onBytes,
  ) =>
      _start(spec.ownerId, spec.callId, () => _host.start(spec), onBytes, null);
  Future<CommandOperation> transfer(
    ChannelTransferSpec spec,
    void Function(int) onProgress,
  ) => _start(
    spec.ownerId,
    spec.callId,
    () => _host.transfer(spec),
    (_, _) async {},
    onProgress,
  );
  Future<CommandOperation> _start(
    String owner,
    String call,
    Future<void> Function() dispatch,
    Future<void> Function(bool, Uint8List) onBytes,
    void Function(int)? onProgress,
  ) async {
    if (_active.containsKey(call)) {
      throw const CommandChannelFailure('invalidOwner', '工具调用已经派发');
    }
    final operation = CommandOperation(this, owner, call, onBytes, onProgress);
    _active[call] = operation;
    try {
      await _boundary(dispatch);
    } catch (_) {
      await cancel(owner, call);
      rethrow;
    }
    return operation;
  }

  Future<void> cancel(String owner, String call) async {
    try {
      await _boundary(
        () => _host.cancel(owner, call),
        timeout: const Duration(seconds: 45),
      );
    } on Failure {
      AppLogger.warning('命令通道停止未收到完整回执');
    } finally {
      final operation = _active[call];
      if (operation != null && operation.owner == owner) {
        _finishLocally(operation, 'terminationMissing', cancelled: true);
      }
    }
  }

  Future<void> endOwner(String owner) async {
    try {
      await _boundary(
        () => _host.endOwner(owner),
        timeout: const Duration(seconds: 45),
      );
    } finally {
      for (final operation
          in _active.values.where((value) => value.owner == owner).toList()) {
        _finishLocally(operation, 'terminationMissing', cancelled: true);
      }
    }
  }

  void _finishLocally(
    CommandOperation operation,
    String error, {
    bool cancelled = false,
  }) {
    if (!operation.done.isCompleted) {
      operation.done.complete(
        ExternalCommandEvent(
          ownerId: operation.owner,
          callId: operation.call,
          sequence: operation.sequence,
          kind: CommandEventKind.exited,
          error: operation.failureCode ?? error,
          transferredBytes: operation.transferredBytes,
          cancelled: cancelled,
        ),
      );
    }
    _active.remove(operation.call);
  }

  @override
  Future<void> event(ExternalCommandEvent event) async {
    final operation = _active[event.callId];
    if (operation == null || operation.owner != event.ownerId) return;
    if (event.sequence != operation.sequence++) {
      _finishLocally(operation, 'outputSequence');
      unawaited(cancel(operation.owner, operation.call));
      return;
    }
    switch (event.kind) {
      case CommandEventKind.stdout:
      case CommandEventKind.stderr:
        try {
          await operation.onBytes(
            event.kind == CommandEventKind.stderr,
            event.bytes ?? Uint8List(0),
          );
        } on CommandChannelFailure catch (error) {
          operation.failureCode = error.code;
          unawaited(cancel(operation.owner, operation.call));
          rethrow;
        }
      case CommandEventKind.progress:
        operation.transferredBytes = event.transferredBytes;
        operation.onProgress?.call(event.transferredBytes);
      case CommandEventKind.exited:
        event.error = operation.failureCode ?? event.error;
        if (!operation.done.isCompleted) operation.done.complete(event);
        _active.remove(event.callId);
    }
  }

  @override
  void statusChanged() {
    if (!_disposed) _changes.add(null);
  }

  @override
  void ownerStopped(String ownerId) {
    if (!_disposed) _stops.add(ownerId);
  }

  Future<void> dispose() async {
    for (final owner in _active.values.map((op) => op.owner).toSet()) {
      try {
        await endOwner(owner);
      } on Failure {
        AppLogger.warning('命令通道关闭未收到回执');
      }
    }
    _disposed = true;
    CommandChannelFlutterApi.setUp(null);
    await _changes.close();
    await _stops.close();
  }
}

String commandErrorText(String code) => switch (code) {
  'fileChanged' => '文件在编辑期间已改变，请重新读取后编辑',
  'lineTooLong' => '文件单行超过 16 KiB，请用 shell 提取片段',
  'offsetOutOfRange' => '起始行超过文件结尾',
  'invalidPath' => '路径越出工作区或包含不支持的链接',
  'notText' => '文件不是可读取的 UTF-8 文本',
  'directoryLimit' => '目录条目超过读取上限',
  'fileOperationFailed' => '文件操作连接中断，未收到完整结果',
  'filePermissionDenied' => '当前执行身份没有该文件或目录的访问权限',
  'spaceUnavailable' => '目标存储空间不足',
  'readOnlyFileSystem' => '目标文件系统只读',
  'fileMissing' => '源文件或目标父目录已不存在',
  'notDirectory' => '路径中的父级不是目录',
  'transferDisconnected' => '文件传输连接已断开，已提交的文件保留',
  'cleanupIncomplete' => '进程清理未完成，未收到完整退出回执',
  'outputStopped' => '停止后仅保留已接收的输出',
  'terminationMissing' => '停止请求已发送，未收到完整退出回执',
  'outputSequence' => '命令输出序列不完整',
  'outputSaveFailed' => '命令日志保存失败，请检查可用空间',
  'permissionRequired' || 'channelDisabled' => '命令通道未启用或授权已撤销',
  'notInstalled' => '未安装对应的命令应用',
  'notRunning' => 'Shizuku 未运行',
  'identityChanged' => '执行身份或运行组件已改变，请开始新运行',
  'invalidOwner' => '命令任务归属无效',
  'initializationFailed' => '运行组件初始化失败，请检查授权、外部调用设置与所需程序',
  'symbolicLink' || 'unsupportedFile' => '无法传输符号链接或特殊文件',
  'invalidPath' || 'invalidManifest' => '传输路径或目录清单无效',
  'typeConflict' => '目标存在同名但类型不同的文件或目录',
  'transferLimit' => '传输超过文件大小、总大小或条目数量上限',
  'sourceChanged' => '传输期间源文件已改变',
  'integrityFailed' => '文件传输校验失败，未提交对应文件',
  'commitFailed' => '文件提交未完成，已完成的文件保留',
  'leaseExpired' => '相月与命令通道失联，运行租约已结束',
  'cancelled' || 'transferCancelled' => '传输已停止，已提交的文件保留',
  'transferTimeout' => '文件传输连接超时',
  'transferFailed' ||
  'fileUnavailable' ||
  'directoryFailed' => '文件传输失败，请检查两端路径、访问权限及可用空间',
  _ => '命令通道连接中断或未返回完整结果',
};

@Riverpod(keepAlive: true)
CommandChannelDriver commandChannelDriver(Ref ref) {
  final driver = CommandChannelDriver();
  ref.onDispose(() {
    unawaited(driver.dispose());
  });
  return driver;
}
