import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/error/failure.dart';
import 'package:phase/data/datasources/local/app_database.dart';
import 'package:phase/data/models/workspace.dart';
import 'package:phase/data/repositories/workspace_repository.dart';
import 'package:phase/features/tools/tool.dart';
import 'package:phase/features/workspace/linux_installer.dart';
import 'package:phase/features/workspace/process_api.g.dart';
import 'package:phase/features/workspace/process_driver.dart';

import '../../support/test_database.dart';
import 'local_process_driver.dart';

// LocalProcessDriver proves the filesystem/IO lifecycle, not Android/PRoot execution.
void main() {
  late ({AppDatabase database, Directory directory}) fixture;
  late WorkspaceRepository repository;
  late _CheckingDriver driver;
  late HttpServer server;
  late Dio dio;
  late List<int> bytes;
  late Workspace session;
  late Directory service;
  late List<String> requests;
  String? idleRequest;
  Completer<void>? waiting;

  setUp(() async {
    fixture = createTestDatabase();
    repository = WorkspaceRepository(fixture.database, fixture.directory);
    driver = _CheckingDriver(repository.filesystem.layout.rootfs);
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    dio = Dio();
    requests = [];
    idleRequest = null;
    waiting = null;
    bytes = gzip.encode(
      TarEncoder().encode(
        Archive()..add(ArchiveFile.string('etc/os-release', 'fixture')),
      ),
    );
    server.listen((request) async {
      requests.add(request.uri.path);
      if (idleRequest == request.uri.path) {
        request.response.write('x');
        await request.response.flush();
        waiting?.complete();
        return;
      }
      if (request.uri.path == '/trace') {
        request.response.write('fl=fixture\nloc=CN\n');
      } else if (request.uri.path == '/trace-missing') {
        request.response.statusCode = HttpStatus.notFound;
      } else {
        request.response.add(bytes);
      }
      await request.response.close();
    });
    addTearDown(() async {
      dio.close(force: true);
      await server.close(force: true);
      await driver.dispose();
      await fixture.database.close();
      await fixture.directory.delete(recursive: true);
    });
    session = await repository.create('keep', id: 'keep-session');
    service = await repository.filesystem.ensureMcpService('keep-server');
    await File('${session.rootPath}/keep.txt').writeAsString('session');
    await File('${service.path}/keep.txt').writeAsString('service');
  });

  LinuxInstaller installer({
    String? digest,
    bool missingMirror = false,
  }) => LinuxInstaller(
    repository,
    driver,
    dio,
    image: LinuxImage(
      revision: 'fixture',
      url: 'http://127.0.0.1:${server.port}/rootfs',
      digest: digest ?? sha256.convert(bytes).toString(),
      downloadBytes: bytes.length,
    ),
    traceUrl:
        'http://127.0.0.1:${server.port}/${missingMirror ? 'trace-missing' : 'trace'}',
  );

  Future<void> expectPersistentFiles() async {
    expect(
      await File('${session.rootPath}/keep.txt').readAsString(),
      'session',
    );
    expect(await File('${service.path}/keep.txt').readAsString(), 'service');
    expect((await repository.get(session.id))!.rootPath, session.rootPath);
  }

  test('first install commits to the fixed root, both probes run without binds and uninstall keeps subtrees', () async {
    final phases = <EnvironmentPhase>[];
    final downloads = <(int, int?)>[];
    final extracted = <int>[];
    expect((await repository.environment()).ready, isFalse);
    expect((await repository.snapshot(session.id)).linuxAvailable, isFalse);
    await installer().install(RunCancellation(), (phase, received, total) {
      phases.add(phase);
      if (phase == EnvironmentPhase.downloading) {
        downloads.add((received, total));
      }
      if (phase == EnvironmentPhase.extracting) extracted.add(received);
    });
    expect(downloads.first, (0, bytes.length));
    expect(downloads.last, (bytes.length, bytes.length));
    expect(extracted, orderedEquals([...extracted]..sort()));
    expect(extracted.last, 'fixture'.length);
    final installed = await repository.environment();
    expect(installed.ready, isTrue);
    expect(installed.rootPath, repository.filesystem.layout.rootfs);
    expect(
      (await repository.snapshot(session.id)).executionRoot,
      '/sessions/${session.id}',
    );
    expect(installed.installedDependencies, isEmpty);
    expect(
      await File('${installed.rootPath}/etc/apt/sources.list.d/ubuntu.sources')
          .readAsString(),
      contains(UbuntuImage.chinaAptMirror),
    );
    expect(
      phases,
      containsAllInOrder([
        EnvironmentPhase.downloading,
        EnvironmentPhase.verifying,
        EnvironmentPhase.extracting,
        EnvironmentPhase.configuring,
        EnvironmentPhase.checking,
        EnvironmentPhase.ready,
      ]),
    );
    expect(driver.calls, hasLength(2));
    expect(
      driver.calls.first.rootfs,
      startsWith(repository.filesystem.layout.staging),
    );
    expect(driver.calls.last.rootfs, repository.filesystem.layout.rootfs);
    expect(driver.calls.every((call) => call.cwd == '/tmp'), isTrue);
    expect(
      driver.calls.every((call) => !call.argv.join(' ').contains('/workspace')),
      isTrue,
    );
    expect(driver.active, isEmpty);
    await expectPersistentFiles();
    await File('${installed.rootPath}/root/global').writeAsString('global');
    await installer().uninstall();
    expect(
      (await repository.environment()).phase,
      EnvironmentPhase.notInstalled,
    );
    await expectPersistentFiles();
    expect(await File('${installed.rootPath}/root/global').exists(), isFalse);
    expect(await Directory(installed.rootPath!).exists(), isTrue);
    await installer().install(RunCancellation(), (_, _, _) {});
    expect((await repository.environment()).rootPath, installed.rootPath);
    await expectPersistentFiles();
  });

  test('a ready environment is never implicitly replaced or loses its dependencies', () async {
    await installer().install(RunCancellation(), (_, _, _) {});
    final before = (await repository.environment()).withDependencies(
      'python',
      InstalledDependency(
        installedAt: DateTime(2026),
        version: 'fixture-python',
      ),
    );
    await repository.saveEnvironment(before);
    await File('${before.rootPath}/root/global').writeAsString('global');
    final requestCount = requests.length;
    final processCount = driver.calls.length;
    await expectLater(
      installer().install(RunCancellation(), (_, _, _) {}),
      throwsA(isA<OperationFailure>()),
    );
    expect((await repository.environment()).toJson(), before.toJson());
    expect(requests.length, requestCount);
    expect(driver.calls.length, processCount);
    expect(
      await File('${before.rootPath}/root/global').readAsString(),
      'global',
    );
    expect(repository.busy, isFalse);
    await expectPersistentFiles();
  });

  for (final path in ['/rootfs', '/trace']) {
    test(
      'cancelling idle $path does not delete sessions or mark the skeleton ready',
      () async {
        idleRequest = path;
        waiting = Completer<void>();
        final cancellation = RunCancellation();
        final pending = installer().install(cancellation, (_, _, _) {});
        await waiting!.future.timeout(const Duration(seconds: 2));
        final result = expectLater(pending, throwsA(isA<ToolCancelled>()));
        cancellation.cancel();
        await result.timeout(const Duration(seconds: 2));
        final env = await repository.environment();
        expect(env.phase, EnvironmentPhase.cancelled);
        expect(env.ready, isFalse);
        expect((await repository.snapshot(session.id)).linuxAvailable, isFalse);
        expect(repository.busy, isFalse);
        expect(driver.owners, isEmpty);
        expect(
          await Directory(repository.filesystem.layout.staging).list().isEmpty,
          isTrue,
        );
        await expectPersistentFiles();
      },
    );
  }

  test('checksum failure leaves no executable environment and keeps persistent files', () async {
    await expectLater(
      installer(digest: 'wrong').install(RunCancellation(), (_, _, _) {}),
      throwsA(
        isA<WorkspaceFailure>().having((e) => e.code, 'code', 'digestMismatch'),
      ),
    );
    expect((await repository.environment()).phase, EnvironmentPhase.failed);
    expect((await repository.snapshot(session.id)).linuxAvailable, isFalse);
    expect(driver.calls, isEmpty);
    expect(repository.busy, isFalse);
    await expectPersistentFiles();
  });

  test('mirror probe failure keeps the upstream default', () async {
    await installer(missingMirror: true)
        .install(RunCancellation(), (_, _, _) {});
    expect(
      await File(
        '${repository.filesystem.layout.rootfs}/etc/apt/sources.list.d/ubuntu.sources',
      ).readAsString(),
      contains(UbuntuImage.upstreamAptMirror),
    );
    await expectPersistentFiles();
  });

  for (final reserved in ['sessions', 'services']) {
    test('archive cannot override reserved $reserved content', () async {
      bytes = gzip.encode(
        TarEncoder().encode(
          Archive()
            ..add(ArchiveFile.string('etc/os-release', 'fixture'))
            ..add(ArchiveFile.string('./$reserved/override', 'forbidden')),
        ),
      );
      await expectLater(
        installer().install(RunCancellation(), (_, _, _) {}),
        throwsA(
          isA<WorkspaceFailure>().having((e) => e.code, 'code', 'archivePath'),
        ),
      );
      expect((await repository.environment()).ready, isFalse);
      expect(driver.calls, isEmpty);
      await expectPersistentFiles();
    });
  }

  for (final cancelled in [false, true]) {
    test(
      '${cancelled ? 'cancelled' : 'failed'} final check leaves partial system unavailable and retries in place',
      () async {
        final cancellation = RunCancellation();
        driver.onInstalledStart = (_) {
          if (cancelled) {
            cancellation.cancel();
          } else {
            throw const WorkspaceFailure(
              'checkFailed',
              'Fixture final check failure',
            );
          }
        };
        await expectLater(
          installer().install(cancellation, (_, _, _) {}),
          throwsA(cancelled ? isA<ToolCancelled>() : isA<WorkspaceFailure>()),
        );
        final env = await repository.environment();
        expect(env.ready, isFalse);
        expect(
          env.phase,
          cancelled ? EnvironmentPhase.cancelled : EnvironmentPhase.failed,
        );
        expect(env.rootPath, repository.filesystem.layout.rootfs);
        expect((await repository.snapshot(session.id)).linuxAvailable, isFalse);
        expect(await File('${env.rootPath}/etc/os-release').exists(), isTrue);
        await expectPersistentFiles();
        driver.onInstalledStart = null;
        await installer().install(RunCancellation(), (_, _, _) {});
        expect((await repository.environment()).ready, isTrue);
        expect((await repository.environment()).rootPath, env.rootPath);
        expect(repository.busy, isFalse);
        await expectPersistentFiles();
      },
    );
  }

  test(
    'uninstall is excluded by sessions, services and dependency installation',
    () async {
      await installer().install(RunCancellation(), (_, _, _) {});
      final lease = await repository.acquire(session.id);
      await expectLater(
        installer().uninstall(),
        throwsA(isA<OperationFailure>()),
      );
      lease.close();
      final release = repository.retainEnvironment();
      await expectLater(
        installer().uninstall(),
        throwsA(isA<OperationFailure>()),
      );
      release();
      repository.beginDependencyChange();
      await expectLater(
        installer().uninstall(),
        throwsA(isA<OperationFailure>()),
      );
      repository.endDependencyChange();
      expect((await repository.environment()).ready, isTrue);
      await expectPersistentFiles();
    },
  );
}

class _CheckingDriver extends LocalProcessDriver {
  _CheckingDriver(this.installedRoot);
  final String installedRoot;
  void Function(LinuxProcessSpec)? onInstalledStart;
  @override
  Future<LinuxProcess> start(
    LinuxProcessSpec spec,
    Future<void> Function(bool, Uint8List) onBytes,
  ) {
    if (spec.rootfs == installedRoot) onInstalledStart?.call(spec);
    return super.start(spec, onBytes);
  }
}
