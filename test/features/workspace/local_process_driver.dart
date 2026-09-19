import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:phase/features/workspace/process_api.g.dart';
import 'package:phase/features/workspace/process_driver.dart';

/// Real host processes for protocol/IO tests. Guest paths are mapped explicitly;
/// this driver does not stand in for Android/PRoot device acceptance.
class LocalProcessDriver implements ProcessDriver {
  final _stops = StreamController<String>.broadcast();
  final active = <String, LocalProcess>{};
  final owners = <String>{};
  final calls = <LinuxProcessSpec>[];
  @override
  Stream<String> get stops => _stops.stream;
  @override
  Future<LinuxPlatformInfo> info() async => LinuxPlatformInfo(
    rootDirectory: '/fixture',
    abi: 'arm64-v8a',
    available: true,
    freeBytes: 1024 * 1024 * 1024,
  );
  @override
  Future<void> setModes(List<String> paths, List<int> modes) async {}
  @override
  Future<void> beginTask(String owner, String label) async {
    owners.add(owner);
  }

  @override
  Future<void> endTask(String owner) async {
    for (final process
        in active.values.where((p) => p.spec.ownerId == owner).toList()) {
      await process.cancel();
    }
    owners.remove(owner);
  }

  @override
  Future<LinuxProcess> start(
    LinuxProcessSpec spec,
    Future<void> Function(bool, Uint8List) onBytes,
  ) async {
    if (!owners.contains(spec.ownerId)) {
      throw StateError('owner not registered');
    }
    calls.add(spec);
    final process = await Process.start(
      '/usr/bin/setsid',
      [
        '/bin/sh',
        ...spec.argv.map((s) => s.replaceAll('/workspace', spec.workspace)),
      ],
      workingDirectory: spec.cwd.replaceAll('/workspace', spec.workspace),
      environment: {'PATH': '/usr/bin:/bin', ...spec.environment},
      includeParentEnvironment: false,
    );
    final handle = LocalProcess(spec, process, onBytes);
    active[spec.processId] = handle;
    unawaited(handle.run().whenComplete(() => active.remove(spec.processId)));
    return handle;
  }

  Future<void> dispose() async {
    for (final owner in owners.toList()) {
      await endTask(owner);
    }
    await _stops.close();
  }
}

class LocalProcess implements LinuxProcess {
  LocalProcess(this.spec, this.process, this.onBytes);
  final LinuxProcessSpec spec;
  final Process process;
  final Future<void> Function(bool, Uint8List) onBytes;
  final done = Completer<LinuxProcessEvent>();
  int received = 0;
  bool cancelled = false, timedOut = false, limited = false;
  void kill() {
    Process.killPid(-process.pid, ProcessSignal.sigterm);
  }

  Future<void> pump(Stream<List<int>> stream, bool stderr) async {
    await for (final bytes in stream) {
      final count = bytes.length.clamp(
        0,
        (spec.outputLimitBytes ?? 1 << 60) - received,
      );
      received += count;
      if (count > 0) {
        await onBytes(stderr, Uint8List.fromList(bytes.sublist(0, count)));
      }
      if (received >= (spec.outputLimitBytes ?? 1 << 60)) {
        limited = true;
        kill();
      }
    }
  }

  Future<void> run() async {
    final timeout = spec.timeoutMs == null
        ? null
        : Timer(Duration(milliseconds: spec.timeoutMs!), () {
            timedOut = true;
            kill();
          });
    final pumps = Future.wait([
      pump(process.stdout, false),
      pump(process.stderr, true),
    ]);
    final code = await process.exitCode;
    await pumps;
    timeout?.cancel();
    done.complete(
      LinuxProcessEvent(
        ownerId: spec.ownerId,
        processId: spec.processId,
        sequence: 0,
        kind: LinuxEventKind.exited,
        exitCode: code >= 0 ? code : null,
        signal: code < 0 ? -code : null,
        cancelled: cancelled,
        timedOut: timedOut,
        outputLimitExceeded: limited,
      ),
    );
  }

  @override
  Future<LinuxProcessEvent> get exited => done.future;
  @override
  Future<void> write(Uint8List bytes) async {
    process.stdin.add(bytes);
    await process.stdin.flush();
  }

  @override
  Future<void> closeInput() async {
    await process.stdin.close();
  }

  @override
  Future<void> cancel() async {
    if (done.isCompleted) return;
    cancelled = true;
    kill();
    final escalation = Timer(
      const Duration(milliseconds: 100),
      () => Process.killPid(-process.pid, ProcessSignal.sigkill),
    );
    try {
      await exited;
    } finally {
      escalation.cancel();
    }
  }
}
