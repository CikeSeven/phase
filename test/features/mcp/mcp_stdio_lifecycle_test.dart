import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/error/failure.dart';
import 'package:phase/data/models/mcp_server_profile.dart';
import 'package:phase/features/mcp/mcp_stdio_client.dart';
import 'package:phase/features/tools/tool.dart';
import 'package:phase/features/workspace/process_api.g.dart';
import 'package:phase/features/workspace/process_driver.dart';

void main() {
  late _Driver driver;
  late McpStdioClient client;
  setUp(() {
    driver = _Driver();
    client = McpStdioClient(
      McpServerProfile(
        id: 'stdio',
        name: 'Fixture',
        endpoint: '',
        transport: McpTransport.stdio,
        command: const McpStdioCommand(executable: '/fixture'),
        definitionRevision: '1',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        callTimeoutSeconds: 1,
      ),
      driver: driver,
      rootfs: '/fixture/root',
      workspace: '/fixture/workspace',
    );
    addTearDown(client.close);
  });

  test(
    'closing during start reaps the late process without sending initialize',
    () async {
      driver.allowStart = Completer<void>();
      final connecting = client.connect(RunCancellation());
      final failure = expectLater(connecting, throwsA(isA<ToolCancelled>()));
      await driver.startEntered.future;
      final closing = client.close();
      driver.allowStart!.complete();
      await Future.wait([failure, closing]);
      expect(driver.process.done.isCompleted, isTrue);
      expect(driver.owners, isEmpty);
      expect(driver.process.frames, isEmpty);
    },
  );

  test(
    'cancelled startup never dispatches initialize after the handle arrives',
    () async {
      driver.allowStart = Completer<void>();
      final cancellation = RunCancellation();
      final connecting = client.connect(cancellation);
      final failure = expectLater(connecting, throwsA(isA<ToolCancelled>()));
      await driver.startEntered.future;
      cancellation.cancel();
      driver.allowStart!.complete();
      await failure;
      await client.close();
      expect(driver.process.frames, isEmpty);
      expect(driver.owners, isEmpty);
    },
  );

  test(
    'cancelling a run does not send cancellation for completed requests',
    () async {
      final cancellation = RunCancellation();
      await client.connect(cancellation);
      cancellation.cancel();
      await Future<void>.delayed(Duration.zero);
      expect(
        driver.process.frames.where(
          (frame) => frame['method'] == 'notifications/cancelled',
        ),
        isEmpty,
      );
    },
  );

  test(
    'large requests and concurrent notifications stay separate JSON frames',
    () async {
      await client.connect(RunCancellation());
      driver.process.allowWrite = Completer<void>();
      final text = '月' * 70000;
      final result = client.request('tools/call', {
        'text': text,
      }, RunCancellation());
      await driver.process.writeEntered.future;
      final notification = client.write({
        'jsonrpc': '2.0',
        'method': 'notifications/test',
      }, RunCancellation());
      await Future<void>.delayed(Duration.zero);
      driver.process.allowWrite!.complete();
      expect((await result)['text'], text);
      await notification;
      expect(driver.process.frames.last['method'], 'notifications/test');
    },
  );

  test('timeout completes even while stdin write is blocked', () async {
    await client.connect(RunCancellation());
    driver.process.allowWrite = Completer<void>();
    final result = client.request('tools/call', {
      'text': 'x' * 100000,
    }, RunCancellation());
    await expectLater(
      result.timeout(const Duration(seconds: 2)),
      throwsA(
        isA<McpFailure>().having((error) => error.code, 'code', 'timeout'),
      ),
    );
    driver.process.allowWrite!.complete();
    await Future<void>.delayed(Duration.zero);
  });
}

class _Driver implements ProcessDriver {
  final owners = <String>{};
  final startEntered = Completer<void>();
  Completer<void>? allowStart;
  late _Process process;
  @override
  Stream<String> get stops => const Stream.empty();
  @override
  Future<void> beginTask(String owner, String label) async => owners.add(owner);
  @override
  Future<void> endTask(String owner) async {
    await process.cancel();
    owners.remove(owner);
  }

  @override
  Future<LinuxProcess> start(
    LinuxProcessSpec spec,
    Future<void> Function(bool, Uint8List) onBytes,
  ) async {
    process = _Process(spec, onBytes);
    startEntered.complete();
    await allowStart?.future;
    return process;
  }

  @override
  Future<LinuxPlatformInfo> info() async => throw UnimplementedError();
  @override
  Future<void> setModes(List<String> paths, List<int> modes) async {}
}

class _Process implements LinuxProcess {
  _Process(this.spec, this.onBytes);
  final LinuxProcessSpec spec;
  final Future<void> Function(bool, Uint8List) onBytes;
  final done = Completer<LinuxProcessEvent>();
  final frames = <Map<String, dynamic>>[];
  final buffer = <int>[];
  Completer<void>? allowWrite;
  final writeEntered = Completer<void>();

  @override
  Future<LinuxProcessEvent> get exited => done.future;
  @override
  Future<void> write(Uint8List bytes) async {
    buffer.addAll(bytes);
    if (allowWrite != null && !writeEntered.isCompleted) {
      writeEntered.complete();
      await allowWrite!.future;
    }
    while (buffer.contains(10)) {
      final end = buffer.indexOf(10);
      final frame = jsonDecode(
        utf8.decode(buffer.sublist(0, end)),
      ) as Map<String, dynamic>;
      buffer.removeRange(0, end + 1);
      frames.add(frame);
      if (!frame.containsKey('id')) continue;
      final result = switch (frame['method']) {
        'initialize' => {
          'protocolVersion': '2025-06-18',
          'capabilities': {'tools': <String, dynamic>{}},
        },
        'tools/list' => {'tools': <dynamic>[]},
        _ => frame['params'],
      };
      await onBytes(
        false,
        Uint8List.fromList(
          utf8.encode(
            '${jsonEncode({'jsonrpc': '2.0', 'id': frame['id'], 'result': result})}\n',
          ),
        ),
      );
    }
  }

  @override
  Future<void> cancel() async {
    if (!done.isCompleted) {
      done.complete(
        LinuxProcessEvent(
          ownerId: spec.ownerId,
          processId: spec.processId,
          sequence: 0,
          kind: LinuxEventKind.exited,
          cancelled: true,
        ),
      );
    }
  }

  @override
  Future<void> closeInput() async {}
}
