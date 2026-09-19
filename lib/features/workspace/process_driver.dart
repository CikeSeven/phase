import 'dart:async';

import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/error/failure.dart';
import '../../../core/utils/logger.dart';
import '../tools/tool.dart';
import 'process_api.g.dart';

part 'process_driver.g.dart';

abstract interface class LinuxProcess {
  Future<LinuxProcessEvent> get exited;
  Future<void> write(Uint8List bytes);
  Future<void> closeInput();
  Future<void> cancel();
}

abstract interface class ProcessDriver {
  Future<LinuxPlatformInfo> info();
  Future<void> setModes(List<String> paths, List<int> modes);
  Future<void> beginTask(String owner, String label);
  Future<void> endTask(String owner);
  Stream<String> get stops;
  Future<LinuxProcess> start(
    LinuxProcessSpec spec,
    Future<void> Function(bool stderr, Uint8List bytes) onBytes,
  );
}

class PigeonProcessDriver implements ProcessDriver, LinuxProcessFlutterApi {
  PigeonProcessDriver({LinuxProcessHostApi? host, BinaryMessenger? messenger})
    : _host = host ?? LinuxProcessHostApi(binaryMessenger: messenger),
      _messenger = messenger {
    LinuxProcessFlutterApi.setUp(this, binaryMessenger: messenger);
  }
  final LinuxProcessHostApi _host;
  final BinaryMessenger? _messenger;
  final _active = <String, _PigeonProcess>{};
  final _owners = <String>{};
  final _stops = StreamController<String>.broadcast(sync: true);
  bool _disposed = false;
  @override
  Stream<String> get stops => _stops.stream;
  Future<T> _call<T>(Future<T> Function() action) async {
    if (_disposed) throw const WorkspaceFailure('unavailable', '进程宿主已关闭');
    try {
      return await action().timeout(const Duration(seconds: 15));
    } on PlatformException catch (error) {
      AppLogger.error('Linux 进程通道调用失败: ${error.code}', error);
      throw const WorkspaceFailure(
        'processUnavailable',
        'Linux 进程操作失败，请检查环境和任务通知权限',
      );
    } on MissingPluginException {
      throw const WorkspaceFailure('unsupported', '此设备未提供 Linux 运行能力');
    } on TimeoutException {
      throw const WorkspaceFailure('processTimeout', 'Linux 进程宿主未及时响应');
    }
  }

  @override
  Future<LinuxPlatformInfo> info() => _call(_host.platformInfo);
  @override
  Future<void> setModes(List<String> paths, List<int> modes) =>
      _call(() => _host.setModes(paths, modes));
  @override
  Future<void> beginTask(String owner, String label) async {
    await _call(() => _host.beginTask(owner, label));
    _owners.add(owner);
  }

  @override
  Future<void> endTask(String owner) async {
    try {
      await _call(() => _host.endTask(owner));
    } finally {
      _owners.remove(owner);
      for (final process
          in _active.values.where((p) => p.spec.ownerId == owner).toList()) {
        process.fail('进程宿主已结束，未收到完整退出回执');
        _active.remove(process.spec.processId);
      }
    }
  }

  @override
  Future<LinuxProcess> start(
    LinuxProcessSpec spec,
    Future<void> Function(bool, Uint8List) onBytes,
  ) async {
    if (!_owners.contains(spec.ownerId) ||
        _active.containsKey(spec.processId)) {
      throw const WorkspaceFailure('invalidOwner', '进程归属无效');
    }
    final process = _PigeonProcess(this, spec, onBytes);
    _active[spec.processId] = process;
    try {
      await _call(() => _host.start(spec));
    } catch (_) {
      // Lost start replies do not prove the process did not launch.
      try {
        await _call(() => _host.cancel(spec.ownerId, spec.processId));
      } catch (_) {
        AppLogger.warning('进程启动失败后的清理未收到回执');
      }
      _active.remove(spec.processId);
      rethrow;
    }
    return process;
  }

  @override
  Future<void> event(LinuxProcessEvent event) async {
    final process = _active[event.processId];
    if (process == null || process.spec.ownerId != event.ownerId) return;
    if (event.sequence != process.sequence) {
      process.protocolError = '进程输出序列不完整';
      process.sequence = event.sequence + 1;
      if (event.kind != LinuxEventKind.exited) {
        throw const WorkspaceFailure('processSequence', '进程输出序列不完整');
      }
    } else {
      process.sequence++;
    }
    if (event.kind == LinuxEventKind.stdout ||
        event.kind == LinuxEventKind.stderr) {
      await process.onBytes(
        event.kind == LinuxEventKind.stderr,
        event.bytes ?? Uint8List(0),
      );
    } else if (event.kind == LinuxEventKind.exited) {
      if (process.protocolError != null) event.error = process.protocolError;
      if (!process.done.isCompleted) process.done.complete(event);
      _active.remove(event.processId);
    }
  }

  @override
  void taskStopped(String ownerId) {
    if (!_disposed) _stops.add(ownerId);
  }

  Future<void> dispose() async {
    if (_disposed) return;
    for (final owner in _owners.toList()) {
      try {
        await endTask(owner);
      } catch (_) {
        AppLogger.warning('Linux 任务清理未收到回执');
      }
    }
    _disposed = true;
    LinuxProcessFlutterApi.setUp(null, binaryMessenger: _messenger);
    await _stops.close();
  }
}

class _PigeonProcess implements LinuxProcess {
  _PigeonProcess(this.driver, this.spec, this.onBytes);
  final PigeonProcessDriver driver;
  final LinuxProcessSpec spec;
  final Future<void> Function(bool, Uint8List) onBytes;
  final done = Completer<LinuxProcessEvent>();
  int sequence = 0;
  String? protocolError;
  @override
  Future<LinuxProcessEvent> get exited => done.future;
  void fail(String message) {
    if (!done.isCompleted) {
      done.complete(
        LinuxProcessEvent(
          ownerId: spec.ownerId,
          processId: spec.processId,
          sequence: sequence,
          kind: LinuxEventKind.exited,
          error: message,
        ),
      );
    }
  }

  @override
  Future<void> write(Uint8List bytes) => driver._call(
    () => driver._host.writeStdin(spec.ownerId, spec.processId, bytes),
  );
  @override
  Future<void> closeInput() async {
    if (!done.isCompleted) {
      await driver._call(
        () => driver._host.closeStdin(spec.ownerId, spec.processId),
      );
    }
  }

  @override
  Future<void> cancel() =>
      driver._call(() => driver._host.cancel(spec.ownerId, spec.processId));
}

/// Cancellation is awaited before returning; already dispatched commands are never retried.
Future<LinuxProcessEvent> waitForProcess(
  LinuxProcess process,
  RunCancellation cancellation,
) async {
  final result = await Future.any<Object>([
    process.exited,
    cancellation.whenCancelled.then<Object>((_) => const ToolCancelled()),
  ]);
  if (result is LinuxProcessEvent) return result;
  await process.cancel();
  return process.exited;
}

@Riverpod(keepAlive: true)
ProcessDriver processDriver(Ref ref) {
  final driver = PigeonProcessDriver();
  ref.onDispose(() {
    unawaited(driver.dispose());
  });
  return driver;
}
