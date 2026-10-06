import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:phase/features/workspace/process_api.g.dart';
import 'package:phase/features/workspace/process_driver.dart';

class ControlledProcessDriver implements ProcessDriver {
  final owners = <String>{};
  final calls = <LinuxProcessSpec>[];
  final processes = <ControlledProcess>[];
  final _stops = StreamController<String>.broadcast();
  @override
  Stream<String> get stops => _stops.stream;
  @override
  Future<LinuxPlatformInfo> info() async => LinuxPlatformInfo(
    rootDirectory: '/fixture',
    abi: 'arm64-v8a',
    available: true,
    freeBytes: 1 << 30,
  );
  @override
  Future<void> setModes(List<String> paths, List<int> modes) async {}
  @override
  Future<void> beginTask(String owner, String label) async {
    owners.add(owner);
  }

  @override
  Future<void> endTask(String owner) async {
    for (final process in processes.where(
      (process) => process.spec.ownerId == owner,
    )) {
      await process.cancel();
    }
    owners.remove(owner);
  }

  @override
  Future<LinuxProcess> start(
    LinuxProcessSpec spec,
    Future<void> Function(bool, Uint8List) onBytes,
  ) async {
    calls.add(spec);
    final process = ControlledProcess(spec, onBytes);
    processes.add(process);
    return process;
  }

  Future<void> dispose() async {
    for (final process in processes) {
      await process.cancel();
    }
    await _stops.close();
  }
}

class ControlledProcess implements LinuxProcess {
  ControlledProcess(this.spec, this.output);
  final LinuxProcessSpec spec;
  final Future<void> Function(bool, Uint8List) output;
  final _done = Completer<LinuxProcessEvent>();
  @override
  Future<LinuxProcessEvent> get exited => _done.future;
  @override
  Future<void> closeInput() async {}
  @override
  Future<void> write(Uint8List bytes) async {}
  Future<void> emit(String text, {bool stderr = false}) =>
      output(stderr, Uint8List.fromList(utf8.encode(text)));
  void complete({
    int exitCode = 0,
    bool cancelled = false,
    bool timedOut = false,
  }) {
    if (_done.isCompleted) return;
    _done.complete(
      LinuxProcessEvent(
        ownerId: spec.ownerId,
        processId: spec.processId,
        sequence: 0,
        kind: LinuxEventKind.exited,
        exitCode: exitCode,
        cancelled: cancelled,
        timedOut: timedOut,
      ),
    );
  }

  @override
  Future<void> cancel() async {
    complete(cancelled: true);
  }
}
