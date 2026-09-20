import 'dart:async';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/error/failure.dart';
import 'package:phase/data/models/workspace.dart';
import 'package:phase/data/repositories/workspace_repository.dart';
import 'package:phase/features/tools/tool.dart';
import 'package:phase/features/workspace/linux_installer.dart';

import '../../support/test_database.dart';
import 'local_process_driver.dart';

void main() {
  test('real HTTP, checksum, staging, shell check and uninstall preserve workspace', () async {
    final fixture = createTestDatabase();
    final driver = LocalProcessDriver();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final dio = Dio();
    addTearDown(() async {
      dio.close(force: true);
      await server.close(force: true);
      await driver.dispose();
      await fixture.database.close();
      await fixture.directory.delete(recursive: true);
    });
    final archive = Archive()
      ..add(ArchiveFile.string('etc/os-release', 'fixture'));
    final bytes = gzip.encode(TarEncoder().encode(archive));
    server.listen((request) async {
      if (request.uri.path == '/trace') {
        request.response.write('fl=fixture\nloc=CN\n');
      } else {
        request.response.add(bytes);
      }
      await request.response.close();
    });
    final image = LinuxImage(
      revision: 'fixture',
      url: 'http://127.0.0.1:${server.port}/rootfs',
      digest: sha256.convert(bytes).toString(),
      downloadBytes: bytes.length,
    );
    final repository = WorkspaceRepository(fixture.database, fixture.directory);
    // A previous ready environment with recorded dependencies is replaced.
    final oldRoot = await Directory('${fixture.directory.path}/old-root')
        .create(recursive: true);
    await repository.saveEnvironment(
      RuntimeEnvironment(
        phase: EnvironmentPhase.ready,
        rootPath: oldRoot.path,
        revision: 'old',
        installedDependencies: {
          'python': InstalledDependency(
            installedAt: DateTime.fromMillisecondsSinceEpoch(0),
            version: 'Python 3.12.3',
          ),
        },
      ),
    );
    final workspace = await repository.create('keep');
    await File('${workspace.rootPath}/keep.txt').writeAsString('keep');
    final installer = LinuxInstaller(
      repository,
      driver,
      dio,
      image: image,
      traceUrl: 'http://127.0.0.1:${server.port}/trace',
    );
    final phases = <EnvironmentPhase>[];
    final downloads = <(int, int?)>[];
    final extracted = <int>[];
    await installer.install(RunCancellation(), (phase, received, total) {
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
    expect((await repository.environment()).ready, isTrue);
    // A successful replacement clears recorded dependencies with the rootfs.
    expect((await repository.environment()).installedDependencies, isEmpty);
    final installed = await repository.environment();
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
    expect(driver.active, isEmpty);
    await installer.uninstall();
    expect(
      (await repository.environment()).phase,
      EnvironmentPhase.notInstalled,
    );
    expect(await File('${workspace.rootPath}/keep.txt').readAsString(), 'keep');
  });
  for (final waitingFor in ['download', 'mirror']) {
    test('cancels an idle $waitingFor request and removes staging', () async {
      final fixture = createTestDatabase();
      final repository = WorkspaceRepository(
        fixture.database,
        fixture.directory,
      );
      final driver = LocalProcessDriver();
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final dio = Dio();
      addTearDown(() async {
        dio.close(force: true);
        await server.close(force: true);
        await driver.dispose();
        await fixture.database.close();
        await fixture.directory.delete(recursive: true);
      });
      final bytes = gzip.encode(
        TarEncoder().encode(
          Archive()..add(ArchiveFile.string('etc/os-release', 'fixture')),
        ),
      );
      final waiting = Completer<void>();
      server.listen((request) async {
        if (waitingFor == 'mirror' && request.uri.path == '/rootfs') {
          request.response.add(bytes);
          await request.response.close();
        } else {
          request.response.add(bytes.sublist(0, 1));
          await request.response.flush();
          waiting.complete();
        }
      });
      final cancellation = RunCancellation();
      final installer = LinuxInstaller(
        repository,
        driver,
        dio,
        image: LinuxImage(
          revision: 'fixture',
          url: 'http://127.0.0.1:${server.port}/rootfs',
          digest: sha256.convert(bytes).toString(),
          downloadBytes: bytes.length,
        ),
        traceUrl: 'http://127.0.0.1:${server.port}/trace',
      );
      final pending = installer.install(cancellation, (_, _, _) {});
      await waiting.future;
      final result = expectLater(pending, throwsA(isA<ToolCancelled>()));
      cancellation.cancel();
      await result.timeout(const Duration(seconds: 2));
      expect(
        (await repository.environment()).phase,
        EnvironmentPhase.cancelled,
      );
      expect(repository.busy, isFalse);
      expect(driver.owners, isEmpty);
      expect(
        await Directory('${fixture.directory.path}/staging').list().isEmpty,
        isTrue,
      );
    });
  }
  test('apt mirror falls back to upstream when the probe fails', () async {
    final fixture = createTestDatabase();
    final driver = LocalProcessDriver();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final dio = Dio();
    addTearDown(() async {
      dio.close(force: true);
      await server.close(force: true);
      await driver.dispose();
      await fixture.database.close();
      await fixture.directory.delete(recursive: true);
    });
    final archive = Archive()
      ..add(ArchiveFile.string('etc/os-release', 'fixture'));
    final bytes = gzip.encode(TarEncoder().encode(archive));
    server.listen((request) async {
      if (request.uri.path == '/trace') {
        request.response.statusCode = HttpStatus.notFound;
      } else {
        request.response.add(bytes);
      }
      await request.response.close();
    });
    final repository = WorkspaceRepository(fixture.database, fixture.directory);
    final installer = LinuxInstaller(
      repository,
      driver,
      dio,
      image: LinuxImage(
        revision: 'fixture',
        url: 'http://127.0.0.1:${server.port}/rootfs',
        digest: sha256.convert(bytes).toString(),
        downloadBytes: bytes.length,
      ),
      traceUrl: 'http://127.0.0.1:${server.port}/trace',
    );
    await installer.install(RunCancellation(), (_, _, _) {});
    final installed = await repository.environment();
    expect(
      await File('${installed.rootPath}/etc/apt/sources.list.d/ubuntu.sources')
          .readAsString(),
      contains(UbuntuImage.upstreamAptMirror),
    );
  });
  for (final stop in [false, true]) {
    test(
      '${stop ? 'cancelled' : 'corrupt'} replacement retains ready environment and files',
      () async {
        final fixture = createTestDatabase();
        final driver = LocalProcessDriver();
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final dio = Dio();
        addTearDown(() async {
          dio.close(force: true);
          await server.close(force: true);
          await driver.dispose();
          await fixture.database.close();
          await fixture.directory.delete(recursive: true);
        });
        server.listen((request) async {
          request.response.add([1, 2, 3]);
          await request.response.close();
        });
        final repository = WorkspaceRepository(
          fixture.database,
          fixture.directory,
        );
        final old = await Directory(
          '${fixture.directory.path}/environments/old',
        ).create(recursive: true);
        await File('${old.path}/keep').writeAsString('old');
        await repository.saveEnvironment(
          RuntimeEnvironment(
            phase: EnvironmentPhase.ready,
            rootPath: old.path,
            revision: 'old',
            installedDependencies: {
              'node': InstalledDependency(
                installedAt: DateTime.fromMillisecondsSinceEpoch(0),
                version: 'v18.20.4',
              ),
            },
          ),
        );
        final cancellation = RunCancellation();
        final installer = LinuxInstaller(
          repository,
          driver,
          dio,
          image: LinuxImage(
            revision: 'new',
            url: 'http://127.0.0.1:${server.port}/rootfs',
            digest: 'wrong',
            downloadBytes: 3,
          ),
        );
        await expectLater(
          installer.install(cancellation, (phase, _, _) {
            if (stop && phase == EnvironmentPhase.verifying) {
              cancellation.cancel();
            }
          }),
          throwsA(stop ? isA<ToolCancelled>() : isA<WorkspaceFailure>()),
        );
        final env = await repository.environment();
        expect(env.ready, isTrue);
        expect(env.revision, 'old');
        // A failed replacement keeps the recorded dependencies.
        expect(env.installedDependencies['node']?.version, 'v18.20.4');
        expect(await File('${old.path}/keep').readAsString(), 'old');
        expect(repository.busy, isFalse);
        expect(driver.owners, isEmpty);
        expect(
          await Directory('${fixture.directory.path}/staging').list().isEmpty,
          isTrue,
        );
      },
    );
  }
}
